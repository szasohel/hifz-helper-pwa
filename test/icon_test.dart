import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA launcher icons exist and are populated', () {
    expect(File('assets/icon/app_icon.png').existsSync(), isTrue);
    expect(File('assets/icon/app_icon_background.png').existsSync(), isTrue);
    expect(File('assets/icon/app_icon_foreground.png').existsSync(), isTrue);
    for (final name in [
      'Icon-192.png',
      'Icon-512.png',
      'Icon-maskable-192.png',
      'Icon-maskable-512.png',
    ]) {
      final icon = File('web/icons/$name');
      expect(icon.existsSync(), isTrue, reason: name);
      expect(icon.lengthSync(), greaterThan(0), reason: name);
    }
  });
}

