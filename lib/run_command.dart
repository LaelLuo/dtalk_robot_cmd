import 'dart:io';

import 'package:dtalk/base_command.dart';
import 'package:dtalk_robot/dtalk_robot.dart';

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
    final stdout = processResult.stdout?.toString() ?? '';
    final stderr = processResult.stderr?.toString() ?? '';

    String formatSection(String title, String content) {
      final trimmed = content.trimRight();
      if (trimmed.isEmpty) return '';
      return '#### $title\n```bash\n$trimmed\n```\n';
    }

    final markdown = StringBuffer()
      ..writeln('### 命令执行')
      ..writeln('`$commandString`\n')
      ..write(formatSection('stdout', stdout))
      ..write(formatSection('stderr', stderr));

    await dTalk.sendMessage(
      DTalkMarkdownMessage(
        title: '命令执行结果',
        text: markdown.toString().trim(),
      ),
    );
  }
}
