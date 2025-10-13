import 'dart:convert';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dtalk_robot/dtalk_robot.dart';

extension ArgResultsExt on ArgResults? {
  String? getStringOrNull(String tag) {
    final value = this?[tag];
    if (value is String?) return value;
    return value?.toString();
  }

  String getString(String tag) {
    final value = getStringOrNull(tag);
    if (value == null) throw FormatException('$tag not found');
    return value;
  }

  int? getIntOrNull(String tag) {
    final value = this?[tag];
    if (value is int?) return value;
    return int.tryParse(value.toString());
  }

  int getInt(String tag) {
    final value = getIntOrNull(tag);
    if (value == null) throw FormatException('$tag not found');
    return value;
  }

  bool? getBoolOrNull(String tag) {
    final value = this?[tag];
    if (value is bool?) return value;
    return "true" == value;
  }

  bool getBool(String tag) {
    final value = getBoolOrNull(tag);
    if (value == null) throw FormatException('$tag not found');
    return value;
  }
}

extension CommandExt on Command {
  String? getStringOrNull(String tag) => argResults.getStringOrNull(tag);

  String getString(String tag) => argResults.getString(tag);

  int? getIntOrNull(String tag) => argResults.getIntOrNull(tag);

  int getInt(String tag) => argResults.getInt(tag);

  bool getBool(String tag) => argResults.getBool(tag);
}

DTalkMessage parseDTalkMessage(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('消息内容不能为空');
  }
  Map<String, dynamic>? messageJson;
  try {
    final decoded = json.decode(trimmed);
    if (decoded is Map) {
      messageJson = Map<String, dynamic>.from(decoded);
    } else {
      return DTalkTextMessage(content: raw);
    }
  } on FormatException {
    return DTalkTextMessage(content: raw);
  }
  return _buildMessageFromJson(messageJson);
}

DTalkMessage _buildMessageFromJson(Map<String, dynamic> messageJson) {
  final msgTypeValue = messageJson['msgtype'];
  if (msgTypeValue is! String) {
    throw const FormatException('msgtype 字段缺失');
  }
  final msgType = msgTypeValue.trim();
  if (msgType.isEmpty) {
    throw const FormatException('msgtype 字段不能为空');
  }
  final at = _parseAt(messageJson['at']);
  switch (msgType) {
    case 'text':
      final textMap = _expectMap(messageJson, 'text');
      return DTalkTextMessage(
        content: _requireString(textMap, 'content', 'text.content'),
        at: at,
      );
    case 'markdown':
      final markdown = _expectMap(messageJson, 'markdown');
      return DTalkMarkdownMessage(
        title: _requireString(markdown, 'title', 'markdown.title'),
        text: _requireString(markdown, 'text', 'markdown.text'),
        at: at,
      );
    case 'link':
      if (at != null) {
        throw const FormatException('link 消息类型不支持@功能');
      }
      final linkMap = _expectMap(messageJson, 'link');
      return DTalkLinkMessage(
        title: _requireString(linkMap, 'title', 'link.title'),
        text: _requireString(linkMap, 'text', 'link.text'),
        messageUrl: _requireString(linkMap, 'messageUrl', 'link.messageUrl'),
        picUrl: _optionalString(linkMap, 'picUrl'),
      );
    case 'actionCard':
      final actionCard = _expectMap(messageJson, 'actionCard');
      final btnOrientation = _optionalString(actionCard, 'btnOrientation');
      final title = _requireString(actionCard, 'title', 'actionCard.title');
      final text = _requireString(actionCard, 'text', 'actionCard.text');
      final singleTitle = _optionalString(actionCard, 'singleTitle') ??
          _optionalString(actionCard, 'single_title');
      final singleUrl =
          _optionalStringByKeys(actionCard, ['singleURL', 'singleUrl']);
      if (singleTitle != null || singleUrl != null) {
        return DTalkActionCardMessage.single(
          title: title,
          text: text,
          singleTitle: _requireStringByValue(
            singleTitle,
            'actionCard.singleTitle',
          ),
          singleUrl: _requireStringByValue(
            singleUrl,
            'actionCard.singleURL',
          ),
          btnOrientation: btnOrientation,
          at: at,
        );
      }
      final btns = actionCard['btns'];
      if (btns is! List) {
        throw const FormatException('actionCard.btns 必须是数组');
      }
      return DTalkActionCardMessage.multi(
        title: title,
        text: text,
        buttons: btns.map(_buildActionCardButton).toList(growable: false),
        btnOrientation: btnOrientation,
        at: at,
      );
    case 'feedCard':
      if (at != null) {
        throw const FormatException('feedCard 消息类型不支持@功能');
      }
      final feedCard = _expectMap(messageJson, 'feedCard');
      final linksRaw = feedCard['links'];
      if (linksRaw is! List) {
        throw const FormatException('feedCard.links 必须是数组');
      }
      final links = linksRaw.map(_buildFeedCardLink).toList(growable: false);
      return DTalkFeedCardMessage(links: links);
    default:
      throw FormatException('暂不支持消息类型 $msgType');
  }
}

Map<String, dynamic> _expectMap(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    throw FormatException('$key 字段缺失');
  }
  if (value is! Map) {
    throw FormatException('$key 必须是对象');
  }
  return Map<String, dynamic>.from(value);
}

String _requireString(
  Map<String, dynamic> json,
  String key,
  String fieldName,
) {
  final value = json[key];
  if (value == null) {
    throw FormatException('$fieldName 缺失');
  }
  final content = value.toString();
  if (content.trim().isEmpty) {
    throw FormatException('$fieldName 不能为空');
  }
  return content;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final content = value.toString();
  if (content.trim().isEmpty) return null;
  return content;
}

String? _optionalStringByKeys(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final content = value.toString();
    if (content.trim().isEmpty) continue;
    return content;
  }
  return null;
}

String _requireStringByValue(String? value, String fieldName) {
  if (value == null || value.trim().isEmpty) {
    throw FormatException('$fieldName 不能为空');
  }
  return value;
}

DTalkActionCardButton _buildActionCardButton(dynamic raw) {
  if (raw is! Map) {
    throw const FormatException('actionCard.btns 元素必须是对象');
  }
  final btn = Map<String, dynamic>.from(raw);
  final title = _requireString(btn, 'title', 'actionCard.btns.title');
  final actionUrl = _requireStringByValue(
    _optionalStringByKeys(btn, const ['actionURL', 'actionUrl']),
    'actionCard.btns.actionURL',
  );
  return DTalkActionCardButton(
    title: title,
    actionUrl: actionUrl,
  );
}

DTalkFeedCardLink _buildFeedCardLink(dynamic raw) {
  if (raw is! Map) {
    throw const FormatException('feedCard.links 元素必须是对象');
  }
  final link = Map<String, dynamic>.from(raw);
  return DTalkFeedCardLink(
    title: _requireString(link, 'title', 'feedCard.links.title'),
    messageUrl: _requireStringByValue(
      _optionalStringByKeys(link, const ['messageURL', 'messageUrl']),
      'feedCard.links.messageURL',
    ),
    picUrl: _requireStringByValue(
      _optionalStringByKeys(link, const ['picURL', 'picUrl']),
      'feedCard.links.picURL',
    ),
  );
}

DTalkAt? _parseAt(dynamic raw) {
  if (raw == null) return null;
  if (raw is! Map) {
    throw const FormatException('at 必须是对象');
  }
  final atMap = Map<String, dynamic>.from(raw);
  final mobiles =
      _readStringList(atMap['atMobiles']).where((e) => e.isNotEmpty).toList();
  final userIds =
      _readStringList(atMap['atUserIds']).where((e) => e.isNotEmpty).toList();
  final isAtAll = _parseBool(atMap['isAtAll']);
  if (mobiles.isEmpty && userIds.isEmpty && !isAtAll) {
    return null;
  }
  return DTalkAt(
    mobiles: mobiles,
    userIds: userIds,
    isAtAll: isAtAll,
  );
}

Iterable<String> _readStringList(dynamic raw) {
  if (raw == null) return const <String>[];
  if (raw is List) {
    return raw
        .where((element) => element != null)
        .map((element) => element.toString().trim());
  }
  return [raw.toString().trim()];
}

bool _parseBool(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
}

class Ext {}
