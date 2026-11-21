import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/main.dart';
import 'package:grain/settings/settings_screen.dart';
import 'package:grain/ui/haptics.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_source.dart';

class _Haptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

void main() {
  test('lockPortrait asks the platform for portrait up only', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await lockPortrait();
    final call = calls.singleWhere(
      (c) => c.method == 'SystemChrome.setPreferredOrientations',
    );
    expect(call.arguments, ['DeviceOrientation.portraitUp']);
  });

  test('overlay style: dark icons on the paper ground', () {
    expect(grainOverlayStyle.statusBarIconBrightness, Brightness.dark);
    expect(grainOverlayStyle.statusBarBrightness, Brightness.light);
    expect(grainOverlayStyle.systemNavigationBarColor, GrainColors.ground);
    expect(
      grainOverlayStyle.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
  });

  testWidgets('meter and settings screens apply the light overlay style, '
      'also in system dark mode', (tester) async {
    tester.view.physicalSize = const Size(1700, 2400);
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      GrainApp(source: FakeMeterSource(), haptics: _Haptics()),
    );
    await tester.pump();
    expect(SystemChrome.latestStyle, grainOverlayStyle);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(SystemChrome.latestStyle, grainOverlayStyle);
  });
}
