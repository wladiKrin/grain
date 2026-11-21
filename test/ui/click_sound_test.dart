import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/ui/click_sound.dart';

import '../support/fake_click.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the haptic ticks before the click', () {
    final log = <String>[];
    final h = ClickingHaptics(
      LogHaptics(log),
      FakeClickSound(log),
      enabled: true,
    );
    h.tick(strong: true);
    h.tick(strong: false);
    expect(log, [
      'setEnabled true',
      'tick strong',
      'click strong',
      'tick light',
      'click light',
    ]);
  });

  test('disabled: haptics only, no native calls', () {
    final log = <String>[];
    final h = ClickingHaptics(LogHaptics(log), FakeClickSound(log));
    h.tick(strong: true);
    expect(log, ['tick strong']);
  });

  test('toggling tells the native side once per change', () {
    final log = <String>[];
    final h = ClickingHaptics(LogHaptics(log), FakeClickSound(log));
    h.enabled = true;
    h.enabled = true;
    h.enabled = false;
    expect(log, ['setEnabled true', 'setEnabled false']);
  });

  testWidgets('ClickChannel survives a missing plugin', (t) async {
    ClickChannel().click(strong: true);
    ClickChannel().setEnabled(true);
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('ClickChannel survives a native error', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('grain/click'),
      (_) async => throw PlatformException(code: 'boom'),
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('grain/click'),
        null,
      ),
    );
    ClickChannel().click(strong: false);
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('ClickChannel sends setEnabled and play with arguments', (
    t,
  ) async {
    final calls = <(String, Object?)>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('grain/click'),
      (c) async {
        calls.add((c.method, c.arguments));
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('grain/click'),
        null,
      ),
    );
    final c = ClickChannel();
    c.setEnabled(true);
    c.click(strong: true);
    c.click(strong: false);
    await t.pump();
    expect(calls.map((c) => c.$1), ['setEnabled', 'play', 'play']);
    expect(calls.map((c) => (c.$2 as Map).entries.single.toString()), [
      'MapEntry(on: true)',
      'MapEntry(strong: true)',
      'MapEntry(strong: false)',
    ]);
  });
}
