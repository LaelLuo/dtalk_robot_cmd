import 'dart:io';

import 'package:dtalk/base_command.dart';

class RunCommand extends BaseCommand {
  RunCommand() : super('run', '执行命令');

  @override
  Future<void> run() async {
    await super.run();
    final rest = argResults?.rest;
    if (rest == null || rest.isEmpty) {
      throw Exception('command not found');
    }
    final commandString = rest.first;
    final command = commandString.split(RegExp(r' +'));
    final processResult =
        await Process.run(command.removeAt(0), command, runInShell: true);
    final builder = StringBuffer('执行命令: $commandString\n');
    builder.write('stdout: ${processResult.stdout}\n');
    builder.write('stderr: ${processResult.stderr}\n');
    await dTalk.sendText(builder.toString());
  }
}
