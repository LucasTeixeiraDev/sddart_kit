import 'dart:io';

import 'package:flutter_sdd/flutter_sdd.dart';

Future<void> main(List<String> args) async {
  exitCode = await SddCommandRunner(SddContext.io()).run(args);
}
