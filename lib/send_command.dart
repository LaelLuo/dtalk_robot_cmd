import 'dart:convert';

import 'package:dtalk/base_command.dart';
import 'package:dtalk/ext.dart';

class SendCommand extends BaseCommand {
  SendCommand() : super('send', '发消息给钉钉') {
    argParser.addFlag('base64',
        abbr: 'b', help: 'base64 message', defaultsTo: false);
  }

  @override
  Future<void> run() async {
    await super.run();
    final message = (() {
      final isBase64 = getBool('base64');
      if (isBase64) {
        return argResults?.rest
            .map((e) => utf8.decode(base64Decode(e)))
            .join(' ');
      } else {
        return argResults?.rest.join(' ');
      }
    })();
    if (message == null || message.trim().isEmpty) {
      throw Exception('message is empty');
    }
    try {
      await dTalk.sendMessage(parseDTalkMessage(message));
    } on FormatException catch (error) {
      throw Exception('消息解析失败: ${error.message}');
    }
  }
}
