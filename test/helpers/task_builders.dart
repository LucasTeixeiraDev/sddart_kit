import 'package:flutter_sdd/src/core/config/config_parser.dart';
import 'package:flutter_sdd/src/core/config/sdd_config.dart';
import 'package:flutter_sdd/src/core/kit/kit_loader.dart';
import 'package:flutter_sdd/src/core/kit/kit_model.dart';
import 'package:flutter_sdd/src/core/specs/spec_repository.dart';
import 'package:flutter_sdd/src/core/status/spec_status.dart';
import 'package:flutter_sdd/src/core/tasks/task.dart';

import 'test_env.dart';

/// Kit core real (implementer com variantes fast/standard/deep).
final KitBundle realBundle = KitLoader(
  memoryFs(),
).load(const [KitLayerDir(KitLayer.core, '$memKitPath/core')]);

TaskSpec task(
  String id, {
  int wave = 0,
  List<String> deps = const [],
  Tier tier = Tier.standard,
  String agent = 'implementer',
  List<String>? owns,
  List<String> reads = const [],
  String? exemplar,
  List<String> acceptance = const [],
  String? brick,
  Map<String, String> brickVars = const {},
}) => TaskSpec(
  id: id,
  title: 'Tarefa $id',
  wave: wave,
  dependsOn: deps,
  tier: tier,
  agent: agent,
  owns: owns ?? ['lib/$id.dart'],
  reads: reads,
  exemplar: exemplar,
  brick: brick,
  brickVars: brickVars,
  acceptance: acceptance,
  file: 'specs/0001-x/tasks/$id-x.md',
);

SpecDir specWith(
  List<TaskSpec> tasks, {
  SpecStatus? status,
  String? specMd = 'AC-01 AC-02',
}) => SpecDir(
  id: '0001-x',
  path: 'specs/0001-x',
  tasks: tasks,
  taskIssues: const [],
  status: status ?? const SpecStatus(spec: '0001-x', phase: Phase.exec),
  specMd: specMd,
);

SddConfig testConfig([String extra = '']) =>
    parseConfig('kit: {stack: s}\n$extra').config;

SpecStatus statusWith(
  Map<String, TaskStatus> tasks, {
  Phase phase = Phase.exec,
}) => SpecStatus(
  spec: '0001-x',
  phase: phase,
  gates: const {'analysis_approved': true, 'plan_approved': true},
  tasks: tasks,
);

/// Markdown de tarefa válido, com campos sobrescrevíveis.
String taskMd({
  String id = 'T01',
  String extra = '',
  String body =
      '## Objetivo\nx\n\n## Detalhes\ny\n\n## Pronto da tarefa\n'
      '- sdd check --task T01\n',
}) =>
    '---\nid: $id\ntitle: Título\nwave: 0\ntier: standard\nagent: implementer\n'
    'owns: [lib/a.dart]\n$extra---\n$body';
