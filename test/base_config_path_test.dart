import 'dart:io';

import 'package:dtalk/base_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('defaultDTalkConfigPath', () {
    test('returns null when home missing', () {
      expect(defaultDTalkConfigPath(homeOverride: ''), isNull);
    });

    test('appends filename when no trailing separator', () {
      const home = 'homeDir';
      final expected = p.join(home, '.dtalk.json');
      expect(defaultDTalkConfigPath(homeOverride: home), expected);
    });

    test('no duplicate separator when trailing slash', () {
      final home = 'homeDir${Platform.pathSeparator}';
      final expected = p.join(home, '.dtalk.json');
      expect(defaultDTalkConfigPath(homeOverride: home), expected);
    });

    test('handles absolute unix path', () {
      const home = '/Users/test/';
      expect(
        defaultDTalkConfigPath(homeOverride: home),
        equals(p.join(home, '.dtalk.json')),
      );
    });
  });
}
