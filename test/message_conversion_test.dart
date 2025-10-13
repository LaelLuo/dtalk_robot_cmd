import 'package:dtalk/ext.dart';
import 'package:dtalk_robot/dtalk_robot.dart';
import 'package:test/test.dart';

void main() {
  group('parseDTalkMessage', () {
    test('parses plain text into DTalkTextMessage', () {
      final message = parseDTalkMessage('hello world');
      expect(message, isA<DTalkTextMessage>());
      final body = message.toRequestBody();
      expect(body['msgtype'], equals('text'));
      expect((body['text'] as Map<String, dynamic>)['content'],
          equals('hello world'));
    });

    test('parses json text with at Mobiles', () {
      final payload = '''
{
  "msgtype": "text",
  "text": {"content": "告警"},
  "at": {"atMobiles": ["13800000000"]}
}
''';
      final message = parseDTalkMessage(payload);
      final body = message.toRequestBody();
      expect(body['msgtype'], equals('text'));
      expect(body['text'], equals({'content': '告警'}));
      expect(
          body['at'],
          equals({
            'atMobiles': ['13800000000']
          }));
    });

    test('throws when link message carries at', () {
      final payload = '''
{
  "msgtype": "link",
  "link": {
    "title": "超链",
    "text": "描述",
    "messageUrl": "https://example.com"
  },
  "at": {"isAtAll": true}
}
''';
      expect(() => parseDTalkMessage(payload), throwsFormatException);
    });

    test('parses actionCard single with at all', () {
      final payload = '''
{
  "msgtype": "actionCard",
  "actionCard": {
    "title": "操作卡片",
    "text": "请处理",
    "singleTitle": "查看详情",
    "singleURL": "https://example.com/detail"
  },
  "at": {"isAtAll": true}
}
''';
      final message = parseDTalkMessage(payload);
      expect(message, isA<DTalkActionCardMessage>());
      final body = message.toRequestBody();
      expect(body['msgtype'], equals('actionCard'));
      final actionCard = body['actionCard'] as Map<String, dynamic>;
      expect(actionCard['singleTitle'], equals('查看详情'));
      expect(actionCard['singleURL'], equals('https://example.com/detail'));
      expect(body['at'], equals({'isAtAll': true}));
    });

    test('parses feedCard links', () {
      final payload = '''
{
  "msgtype": "feedCard",
  "feedCard": {
    "links": [
      {
        "title": "文档",
        "messageURL": "https://example.com/doc",
        "picURL": "https://example.com/doc.png"
      },
      {
        "title": "报表",
        "messageURL": "https://example.com/report",
        "picURL": "https://example.com/report.png"
      }
    ]
  }
}
''';
      final message = parseDTalkMessage(payload);
      expect(message, isA<DTalkFeedCardMessage>());
      final body = message.toRequestBody();
      expect(body['msgtype'], equals('feedCard'));
      final feedCard = body['feedCard'] as Map<String, dynamic>;
      final links = feedCard['links'] as List<dynamic>;
      expect(links, hasLength(2));
      expect(
          links.first,
          equals({
            'title': '文档',
            'messageURL': 'https://example.com/doc',
            'picURL': 'https://example.com/doc.png',
          }));
    });
  });
}
