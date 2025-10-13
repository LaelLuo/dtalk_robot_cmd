import 'dart:io';

import 'package:dtalk/proxy_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('defaultProxyConfigPath', () {
    test('appends file when home has no trailing separator', () {
      const home = 'homeDir';
      final expected = p.join(home, '.dtalk.proxy.json');
      expect(defaultProxyConfigPath(homeOverride: home), expected);
    });

    test('avoids duplicate separator when home ends with separator', () {
      final home = 'homeDir${Platform.pathSeparator}';
      final expected = p.join(home, '.dtalk.proxy.json');
      expect(defaultProxyConfigPath(homeOverride: home), expected);
    });

    test('handles explicit unix-style slash', () {
      const home = '/Users/tester/';
      expect(
        defaultProxyConfigPath(homeOverride: home),
        equals(p.join(home, '.dtalk.proxy.json')),
      );
    });
  });
}
