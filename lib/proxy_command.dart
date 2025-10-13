import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dtalk/ext.dart';
import 'package:dtalk_robot/dtalk_robot.dart';

class ProxyCommand extends Command {
  ProxyCommand() : super() {
    argParser.addOption('path', abbr: 'p', help: 'proxy path');
    argParser.addOption('port',
        abbr: 'o', help: 'proxy port', defaultsTo: '8080');
    argParser.addOption('config', abbr: 'c', help: 'config file');
  }

  @override
  String description = '消息转发到钉钉机器人';

  @override
  String name = 'proxy';

  @override
  String get usage {
    final buffer = StringBuffer()
      ..writeln(invocation)
      ..writeln()
      ..writeln(argParser.usage)
      ..writeln()
      ..write(_proxyHelpMessage.trimRight());
    return buffer.toString();
  }

  @override
  Future<void> run() async {
    final token = globalResults.getStringOrNull('token');
    final secret = globalResults.getStringOrNull('secret');
    final path = getStringOrNull('path');
    final port = getInt('port');
    final config = argResults?['config'];
    final dTalkMap = <String, DTalk>{};

    void addDTalk(String path, String? token, String? secret) {
      if (token == null || secret == null) return print('$path 参数不完整');
      dTalkMap[path] = DTalk(token: token, secret: secret);
    }

    if (config != null) {
      final configFile = File(config);
      if (configFile.existsSync()) {
        final List configList = json.decode(configFile.readAsStringSync());
        for (final configMap in configList) {
          final path = configMap['path'];
          if (path == null) continue;
          final token = configMap['token'];
          final secret = configMap['secret'];
          addDTalk(path, token, secret);
        }
      }
    } else if (path != null) {
      addDTalk(path, token, secret);
    } else {
      throw UsageException('缺少 path 参数', _proxyHelpMessage);
    }

    await startServer(port, dTalkMap);
  }

  Future<void> startServer(int port, Map<String, DTalk> dTalkMap) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('proxy server start at ${server.address.address}:${server.port}');

    await for (final request in server) {
      final path = request.uri.path;
      print('request path: $path');

      final dTalk = dTalkMap[path];
      if (dTalk == null) {
        request.response.statusCode = 404;
        request.response.close();
        continue;
      }

      final String? message;
      switch (request.method) {
        case 'POST':
          message = await utf8.decoder.bind(request).join();
          break;
        case 'GET':
          message = request.uri.queryParameters['message'];
          break;
        default:
          message = null;
          break;
      }
      if (message == null || message.trim().isEmpty) {
        request.response.statusCode = 400;
        request.response.write('message is empty');
        await request.response.close();
        continue;
      }
      try {
        await dTalk.sendMessage(parseDTalkMessage(message));
        request.response.statusCode = 200;
        request.response.write('ok');
      } on FormatException catch (error) {
        request.response.statusCode = 400;
        final errorMessage = 'message parse error: ${error.message}';
        request.response.write(errorMessage);
        print(errorMessage);
      } catch (error) {
        request.response.statusCode = 500;
        final errorMessage = 'send message failed: $error';
        request.response.write(errorMessage);
        print(errorMessage);
      }
      await request.response.close();
    }
  }
}

const String _proxyHelpMessage = '''
使用说明:
  dtalk proxy --path /hook --token <token> --secret <secret> [--port 8080]
  dtalk proxy --config hooks.json [--port 8080]

配置示例:
  hooks.json:
  [
    {"path": "/dev", "token": "xxx", "secret": "yyy"},
    {"path": "/prod", "token": "aaa", "secret": "bbb"}
  ]

请求格式:
  POST /<path>    请求体为 JSON，结构同钉钉 webhook 消息。
  GET  /<path>?message=<文本>  将文本直接发送为 text 消息。

消息类型:
  支持 text、markdown、link、actionCard、feedCard，并在运行时校验 @ 参数。
''';
