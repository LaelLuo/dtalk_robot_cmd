import 'dart:convert';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dtalk/base_command.dart';
import 'package:dtalk/ext.dart';
import 'package:dtalk_robot/dtalk_robot.dart';

class SendCommand extends BaseCommand {
  SendCommand() : super('send', '发消息给钉钉') {
    argParser
      ..addFlag('base64', abbr: 'b', help: 'base64 message', defaultsTo: false)
      ..addOption('type',
          abbr: 'T',
          help: '消息类型(text|markdown|link|actionCard|feedCard)',
          allowed: const ['text', 'markdown', 'link', 'actionCard', 'feedCard'],
          defaultsTo: 'text')
      ..addOption('content', help: 'text/markdown 正文，默认读取剩余参数')
      ..addOption('title', help: '消息标题')
      ..addOption('text', help: '消息文本，用于 markdown/link/actionCard')
      ..addOption('message-url', help: '链接跳转地址，用于 link/feedCard/actionCard')
      ..addOption('pic-url', help: '图片地址，用于 link')
      ..addFlag('single', help: 'actionCard 单个按钮模式', defaultsTo: false)
      ..addOption('single-title', help: 'actionCard 单按钮标题')
      ..addOption('single-url', help: 'actionCard 单按钮跳转链接')
      ..addOption('btn-orientation', help: 'actionCard 按钮排列方向，0 竖直 / 1 水平')
      ..addMultiOption('btn',
          help: 'actionCard 多按钮，格式：标题|链接，可重复', valueHelp: 'title|url')
      ..addMultiOption('feed-link',
          help: 'feedCard 链接，格式：标题|链接|图片，可重复', valueHelp: 'title|url|pic')
      ..addMultiOption('at-mobile',
          help: '@ 指定手机号，可逗号分隔或多次传入', valueHelp: 'mobile')
      ..addMultiOption('at-user',
          help: '@ 指定 userId，可逗号分隔或多次传入', valueHelp: 'userId')
      ..addFlag('at-all', help: '@ 所有人', defaultsTo: false);
  }

  @override
  Future<void> run() async {
    await super.run();
    final results = argResults!;
    final restParts = List<String>.from(results.rest);
    final restJoined = restParts.join(' ');
    if (_hasStructuredOptions(results)) {
      if (getBool('base64')) {
        throw UsageException('结构化参数模式下不支持 --base64', argParser.usage);
      }
      final message = _buildMessageFromOptions(
          results, restJoined.isEmpty ? null : restJoined);
      await dTalk.sendMessage(message);
      return;
    }

    final message = (() {
      final isBase64 = getBool('base64');
      if (isBase64) {
        return restParts.map((e) => utf8.decode(base64Decode(e))).join(' ');
      } else {
        return restJoined;
      }
    })();
    if (message.trim().isEmpty) {
      throw UsageException('message is empty', argParser.usage);
    }
    try {
      await dTalk.sendMessage(parseDTalkMessage(message));
    } on FormatException catch (error) {
      throw UsageException('消息解析失败: ${error.message}', argParser.usage);
    }
  }

  bool _hasStructuredOptions(ArgResults results) {
    const keys = [
      'type',
      'content',
      'title',
      'text',
      'message-url',
      'pic-url',
      'single',
      'single-title',
      'single-url',
      'btn-orientation',
      'btn',
      'feed-link',
      'at-mobile',
      'at-user',
      'at-all',
    ];
    for (final key in keys) {
      if (results.wasParsed(key)) return true;
    }
    return false;
  }

  DTalkMessage _buildMessageFromOptions(
      ArgResults results, String? fallbackText) {
    final usage = argParser.usage;
    final type = (_stringOption(results, 'type') ?? 'text').trim();
    final at = _buildAt(results);
    final textFallback = fallbackText;

    switch (type) {
      case 'text':
        final content = _stringOption(results, 'content') ?? textFallback;
        if (content == null || content.trim().isEmpty) {
          throw UsageException('text 类型需要提供 --content 或剩余文本参数', usage);
        }
        return DTalkTextMessage(content: content, at: at);
      case 'markdown':
        final title = _requireOption(
            results, 'title', 'markdown 类型需要 --title 指定标题', usage);
        final body = _stringOption(results, 'text') ?? textFallback;
        if (body == null || body.trim().isEmpty) {
          throw UsageException('markdown 类型需要 --text 指定正文或提供剩余文本参数', usage);
        }
        return DTalkMarkdownMessage(title: title, text: body, at: at);
      case 'link':
        if (at != null) {
          throw UsageException('link 类型不支持 @ 功能', usage);
        }
        final title =
            _requireOption(results, 'title', 'link 类型需要 --title 指定标题', usage);
        final text =
            _requireOption(results, 'text', 'link 类型需要 --text 指定内容', usage);
        final messageUrl = _requireOption(
            results, 'message-url', 'link 类型需要 --message-url 指定跳转链接', usage);
        final picUrl = _stringOption(results, 'pic-url');
        return DTalkLinkMessage(
          title: title,
          text: text,
          messageUrl: messageUrl,
          picUrl: picUrl?.isEmpty ?? true ? null : picUrl,
        );
      case 'actionCard':
        final title = _requireOption(
            results, 'title', 'actionCard 类型需要 --title 指定标题', usage);
        final text = _stringOption(results, 'text') ?? textFallback;
        if (text == null || text.trim().isEmpty) {
          throw UsageException('actionCard 类型需要 --text 指定正文或提供剩余文本参数', usage);
        }
        final btnOrientationRaw = _stringOption(results, 'btn-orientation');
        final btnOrientationTrimmed = btnOrientationRaw?.trim();
        final btnOrientation = (btnOrientationTrimmed?.isEmpty ?? true)
            ? null
            : btnOrientationTrimmed;
        final singleFlag =
            results.wasParsed('single') ? results['single'] as bool : false;
        final hasSingleField = results.wasParsed('single-title') ||
            results.wasParsed('single-url');
        final useSingle = singleFlag || hasSingleField;
        if (useSingle) {
          final singleTitle = _requireOption(results, 'single-title',
              'actionCard 单按钮需提供 --single-title', usage);
          final singleUrl = _requireOption(
              results, 'single-url', 'actionCard 单按钮需提供 --single-url', usage);
          if (results.wasParsed('btn')) {
            throw UsageException('actionCard 单按钮模式不需要 --btn 参数', usage);
          }
          return DTalkActionCardMessage.single(
            title: title,
            text: text,
            singleTitle: singleTitle,
            singleUrl: singleUrl,
            btnOrientation: btnOrientation,
            at: at,
          );
        }
        final btnValues = _multiOption(results, 'btn');
        if (btnValues.isEmpty) {
          throw UsageException(
              'actionCard 多按钮需至少指定一个 --btn 标识（格式：标题|链接）', usage);
        }
        final buttons =
            btnValues.map((value) => _parseButton(value, usage)).toList();
        return DTalkActionCardMessage.multi(
          title: title,
          text: text,
          buttons: buttons,
          btnOrientation: btnOrientation,
          at: at,
        );
      case 'feedCard':
        if (at != null) {
          throw UsageException('feedCard 类型不支持 @ 功能', usage);
        }
        final linkValues = _multiOption(results, 'feed-link');
        if (linkValues.isEmpty) {
          throw UsageException(
              'feedCard 类型需至少指定一个 --feed-link（格式：标题|链接|图片）', usage);
        }
        final links =
            linkValues.map((value) => _parseFeedLink(value, usage)).toList();
        return DTalkFeedCardMessage(links: links);
      default:
        throw UsageException('暂不支持消息类型 $type', usage);
    }
  }

  String? _stringOption(ArgResults results, String name) {
    if (!results.wasParsed(name)) return null;
    final value = results[name];
    return value?.toString();
  }

  List<String> _multiOption(ArgResults results, String name) {
    if (!results.wasParsed(name)) return const [];
    final value = results[name];
    if (value is List) {
      return value.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  String _requireOption(
    ArgResults results,
    String name,
    String message,
    String usage,
  ) {
    final value = _stringOption(results, name);
    if (value == null || value.trim().isEmpty) {
      throw UsageException(message, usage);
    }
    return value;
  }

  DTalkAt? _buildAt(ArgResults results) {
    final mobiles = _multiOption(results, 'at-mobile')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final userIds = _multiOption(results, 'at-user')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final atAll =
        results.wasParsed('at-all') ? results['at-all'] as bool : false;
    if (mobiles.isEmpty && userIds.isEmpty && !atAll) {
      return null;
    }
    return DTalkAt(
      mobiles: mobiles,
      userIds: userIds,
      isAtAll: atAll,
    );
  }

  DTalkActionCardButton _parseButton(String raw, String usage) {
    final separator = raw.indexOf('|');
    if (separator <= 0 || separator == raw.length - 1) {
      throw UsageException('actionCard 按钮格式错误：$raw，期望为 标题|链接', usage);
    }
    final title = raw.substring(0, separator).trim();
    final actionUrl = raw.substring(separator + 1).trim();
    if (title.isEmpty || actionUrl.isEmpty) {
      throw UsageException('actionCard 按钮格式错误：$raw，标题或链接不能为空', usage);
    }
    return DTalkActionCardButton(title: title, actionUrl: actionUrl);
  }

  DTalkFeedCardLink _parseFeedLink(String raw, String usage) {
    final first = raw.indexOf('|');
    final second = raw.indexOf('|', first + 1);
    if (first <= 0 || second <= first + 1 || second == raw.length - 1) {
      throw UsageException('feedCard 链接格式错误：$raw，期望为 标题|链接|图片', usage);
    }
    final title = raw.substring(0, first).trim();
    final messageUrl = raw.substring(first + 1, second).trim();
    final picUrl = raw.substring(second + 1).trim();
    if (title.isEmpty || messageUrl.isEmpty || picUrl.isEmpty) {
      throw UsageException('feedCard 链接格式错误：$raw，字段不能为空', usage);
    }
    return DTalkFeedCardLink(
      title: title,
      messageUrl: messageUrl,
      picUrl: picUrl,
    );
  }
}
