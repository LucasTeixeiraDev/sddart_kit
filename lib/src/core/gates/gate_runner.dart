import 'package:file/file.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/gates/command_line.dart';
import 'package:flutter_sdd/src/core/gates/coverage.dart';
import 'package:flutter_sdd/src/core/gates/gate_result.dart';
import 'package:flutter_sdd/src/core/gates/parsers/analyze_parser.dart';
import 'package:flutter_sdd/src/core/gates/parsers/format_parser.dart';
import 'package:flutter_sdd/src/core/gates/parsers/generic_parser.dart';
import 'package:flutter_sdd/src/core/gates/parsers/test_json_parser.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';
import 'package:flutter_sdd/src/core/tasks/task_validator.dart';
import 'package:flutter_sdd/src/infra/process_runner.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

const lcovPath = 'coverage/lcov.info';

/// Executa os gates do DoD (CLI nunca chama LLM; só processos e arquivos).
class GateRunner {
  const GateRunner({
    required this.fs,
    required this.processRunner,
    required this.root,
    required this.config,
  });

  final FileSystem fs;
  final ProcessRunner processRunner;
  final String root;
  final SddConfig config;

  // ---- modos ----

  /// Gates escopados à tarefa: format/analyze/test nos arquivos de `owns` e
  /// verificação de `owns` via git.
  Future<CheckReport> runTask(SpecDir spec, TaskSpec task) async {
    final others = _otherStartedTasks(spec, task);
    final running = [
      for (final t in others)
        if (spec.status.task(t.id).state == TaskState.inProgress) t,
    ];
    final dartFiles = [
      for (final f in task.owns)
        if (f.endsWith('.dart') && fs.file(p.join(root, f)).existsSync()) f,
    ];
    final testFiles = [
      for (final f in dartFiles)
        if (f.endsWith('_test.dart')) f,
    ];

    final results = <GateResult>[
      if (dartFiles.isEmpty)
        const GateResult.skip('format', 'nenhum .dart existente em owns')
      else
        await _commandGate('format', files: dartFiles),
      if (dartFiles.isEmpty)
        const GateResult.skip('analyze', 'nenhum .dart existente em owns')
      else
        _markInterference(
          await _commandGate('analyze', files: dartFiles),
          running,
        ),
      if (testFiles.isEmpty)
        const GateResult.skip('test', 'nenhum *_test.dart em owns')
      else
        _markInterference(
          await _commandGate('test', files: testFiles),
          running,
        ),
      await _ownsGate(spec, task, others),
    ];
    return CheckReport(
      mode: 'task',
      spec: spec.id,
      task: task.id,
      results: results,
    );
  }

  /// Gates completos do DoD, na ordem de `dod.gates`.
  Future<CheckReport> runSpec(SpecDir? spec) async {
    final results = <GateResult>[];
    for (final gate in config.dod.gates) {
      results.add(switch (gate) {
        'coverage' => _coverageGate(),
        'traceability' =>
          spec == null
              ? const GateResult.skip('traceability', 'sem spec (use --spec)')
              : _traceabilityGate(spec),
        'test' => await _commandGate(
          'test',
          commandKey:
              config.dod.gates.contains('coverage') &&
                  config.commands.containsKey('test_all')
              ? 'test_all'
              : 'test',
        ),
        // Sem caminhos, `dart format` lê do stdin: no modo completo usa `.`.
        'format' => await _commandGate('format', files: const ['.']),
        _ => await _commandGate(gate),
      });
    }
    return CheckReport(mode: 'spec', spec: spec?.id, results: results);
  }

  // ---- gates de comando ----

  Future<GateResult> _commandGate(
    String gate, {
    String? commandKey,
    List<String>? files,
  }) async {
    final command = config.commands[commandKey ?? gate];
    if (command == null) {
      return GateResult.fail(gate, [
        GateFailure('sem comando em commands.${commandKey ?? gate}'),
      ]);
    }
    List<String> args;
    try {
      args = buildCommand(command, files: files);
    } on FormatException catch (e) {
      return GateResult.fail(gate, [GateFailure(e.message)]);
    }
    if (gate == 'test') args = withJsonReporter(args);

    final out = await processRunner.run(
      args.first,
      args.sublist(1),
      workingDirectory: root,
    );
    if (out.exitCode == ProcessOutput.notFound) {
      return GateResult.fail(gate, [
        GateFailure('${args.first} não encontrado no PATH'),
      ]);
    }
    final text = '${out.stdout}\n${out.stderr}';
    if (gate == 'test') return _testResult(text, out.ok, out.exitCode);
    if (out.ok) return GateResult.pass(gate);

    final parsed = switch (gate) {
      'format' => parseFormat(text, root),
      'analyze' => _orElse(
        parseAnalyzeMachine(text, root),
        () => parseAnalyzeHuman(text, root),
      ),
      _ => const <GateFailure>[],
    };
    return GateResult.fail(
      gate,
      parsed.isNotEmpty ? parsed : _generic(text, out.exitCode),
    );
  }

  List<GateFailure> _generic(String text, int exitCode) {
    final failures = parseGeneric(text, root);
    return failures.isNotEmpty
        ? failures
        : [GateFailure('saiu com código $exitCode sem saída')];
  }

  GateResult _testResult(String text, bool exitOk, int exitCode) {
    final run = parseTestJson(text, root);
    if (run.failures.isNotEmpty) return GateResult.fail('test', run.failures);
    if (!exitOk) {
      return GateResult.fail(
        'test',
        run.sawEvents ? const [] : _generic(text, exitCode),
      );
    }
    return GateResult.pass('test', note: '${run.passed} testes');
  }

  // ---- gates calculados ----

  GateResult _coverageGate() {
    final file = fs.file(p.join(root, lcovPath));
    if (!file.existsSync()) {
      return GateResult.fail('coverage', [
        const GateFailure(
          '$lcovPath ausente (rode o gate test com --coverage)',
        ),
      ]);
    }
    final all = parseLcov(file.readAsStringSync(), root);
    final scoped = filterCoverage(all, config.dod.coverage.paths);
    if (scoped.isEmpty) {
      return const GateResult.skip(
        'coverage',
        'nenhum arquivo do lcov casa com dod.coverage.paths',
      );
    }
    final total = totalPercent(scoped);
    final min = config.dod.coverage.min;
    final summary = '${total.toStringAsFixed(1)}% (mínimo $min%)';
    if (total >= min) return GateResult.pass('coverage', note: summary);
    final worst = [...scoped]..sort((a, b) => a.percent.compareTo(b.percent));
    return GateResult.fail('coverage', [
      GateFailure('total $summary'),
      for (final f in worst.where((f) => f.percent < min))
        GateFailure(
          '${f.percent.toStringAsFixed(1)}% (${f.hit}/${f.found} linhas)',
          location: f.path,
        ),
    ]);
  }

  GateResult _traceabilityGate(SpecDir spec) {
    final specMd = spec.specMd;
    if (specMd == null) {
      return GateResult.fail('traceability', [
        GateFailure('spec.md ausente', location: '${spec.path}/spec.md'),
      ]);
    }
    final trace = config.dod.traceability;
    final acs = specAcceptanceIds(specMd, trace.acPattern);
    if (acs.isEmpty) {
      return const GateResult.skip('traceability', 'spec sem ACs');
    }
    final tagged = <String>{};
    final testDir = fs.directory(p.join(root, config.project.testPath));
    if (testDir.existsSync()) {
      for (final f in testDir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('_test.dart')) continue;
        for (final m in trace.testTagPattern.allMatches(f.readAsStringSync())) {
          final id = m.groupCount >= 1 ? m.group(1) : m.group(0);
          if (id != null) tagged.add(id);
        }
      }
    }
    final missing = acs.where((ac) => !tagged.contains(ac)).toList();
    if (missing.isEmpty) {
      return GateResult.pass('traceability', note: '${acs.length} ACs');
    }
    return GateResult.fail('traceability', [
      for (final ac in missing)
        GateFailure(
          '$ac sem teste com a tag',
          location: '${spec.path}/spec.md',
        ),
    ]);
  }

  // ---- owns e interferência ----

  /// Tarefas da mesma onda já iniciadas (exceto [task]): seus arquivos podem
  /// estar no diff enquanto a onda não é commitada (D-007).
  List<TaskSpec> _otherStartedTasks(SpecDir spec, TaskSpec task) => [
    for (final t in spec.tasks)
      if (t.id != task.id &&
          t.wave == task.wave &&
          spec.status.task(t.id).state != TaskState.pending)
        t,
  ];

  Future<GateResult> _ownsGate(
    SpecDir spec,
    TaskSpec task,
    List<TaskSpec> others,
  ) async {
    final repo = await processRunner.run('git', [
      'rev-parse',
      '--is-inside-work-tree',
    ], workingDirectory: root);
    if (!repo.ok) {
      return GateResult.fail('owns', [
        const GateFailure('não é um repositório git'),
      ]);
    }
    final diff = await processRunner.run('git', [
      'diff',
      '--name-only',
      '--relative',
      'HEAD',
    ], workingDirectory: root);
    if (!diff.ok) {
      return GateResult.fail('owns', [
        const GateFailure('git diff HEAD falhou (repositório sem commits?)'),
      ]);
    }
    final untracked = await processRunner.run('git', [
      'ls-files',
      '--others',
      '--exclude-standard',
    ], workingDirectory: root);

    final changed = {
      for (final line in '${diff.stdout}\n${untracked.stdout}'.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    };
    final generated = [
      for (final g in config.project.generatedGlobs) Glob(g, context: p.posix),
    ];
    final tolerated = {for (final t in others) ...t.owns};
    final outside = [
      for (final file in changed.toList()..sort())
        if (!task.owns.contains(file) &&
            !tolerated.contains(file) &&
            !p.posix.isWithin(spec.path, file) &&
            !generated.any((g) => g.matches(file)))
          file,
    ];
    if (outside.isEmpty) {
      return GateResult.pass('owns', note: '${changed.length} alterados');
    }
    return GateResult.fail('owns', [
      for (final f in outside)
        GateFailure('alterado fora de owns', location: f),
    ]);
  }

  /// Marca falhas que citam arquivos de tarefas em andamento (heurística:
  /// local da falha ou caminho, com ou sem `lib/`, na mensagem).
  GateResult _markInterference(GateResult result, List<TaskSpec> running) {
    if (result.status != GateStatus.fail || running.isEmpty) return result;
    String? culprit(GateFailure f) {
      final location = f.location?.split(':').first;
      for (final t in running) {
        for (final owned in t.owns) {
          final short = owned.startsWith('lib/') ? owned.substring(4) : owned;
          if (location == owned ||
              f.message.contains(owned) ||
              f.message.contains(short)) {
            return t.id;
          }
        }
      }
      return null;
    }

    return GateResult.fail(result.gate, [
      for (final f in result.failures)
        switch (culprit(f)) {
          final String id => f.withInterference(id),
          null => f,
        },
    ], note: result.note);
  }
}

List<GateFailure> _orElse(
  List<GateFailure> first,
  List<GateFailure> Function() fallback,
) => first.isNotEmpty ? first : fallback();
