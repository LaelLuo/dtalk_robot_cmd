import 'dart:convert';
import 'dart:io';

import 'package:dtalk/base_command.dart';
import 'package:dtalk_robot/dtalk_robot.dart';

class RunCommand extends BaseCommand {
  RunCommand() : super('run', '执行命令');

  static const int _sectionByteLimit = 8000;

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
      final limited = _limitToLastBytes(trimmed, _sectionByteLimit);
      final truncatedSuffix = limited.truncated
          ? ' (已截断，仅展示末尾$_sectionByteLimit字节)'
          : '';
      return '#### $title$truncatedSuffix\n```bash\n${limited.text.trimRight()}\n```\n';
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

class _LimitedText {
  _LimitedText(this.text, this.truncated);
  final String text;
  final bool truncated;
}

_LimitedText _limitToLastBytes(String input, int maxBytes) {
  final bytes = utf8.encode(input);
  if (bytes.length <= maxBytes) {
    return _LimitedText(input, false);
  }
  final startIndex = bytes.length - maxBytes;
  final tailBytes = bytes.sublist(startIndex);
  final decodedTail = utf8.decode(tailBytes, allowMalformed: true);
  return _LimitedText(decodedTail, true);
}
