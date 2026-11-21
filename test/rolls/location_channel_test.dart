import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/rolls/location_channel.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/ui/permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('grain/location');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('location channel maps a fix and treats denied as none', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return {
        'latitude': 52.52,
        'longitude': 13.405,
        'accuracy': 1500.0,
        'timeMs': 1,
      };
    });
    final source = LocationChannel();
    expect(
      await source.current(),
      const GeoFix(latitude: 52.52, longitude: 13.405, accuracy: 1500),
    );
    expect(seen!.method, 'current');
    expect(seen!.arguments, {'timeoutMs': 10000});

    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await source.current(), isNull);

    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'denied');
    });
    expect(await source.current(), isNull);
  });

  test('a fix without accuracy maps to null accuracy', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'latitude': 1, 'longitude': 2, 'timeMs': 5},
    );
    expect(
      await LocationChannel().current(),
      const GeoFix(latitude: 1, longitude: 2),
    );
  });

  test('requestPermission delegates to the injected request', () async {
    expect(
      await LocationChannel(request: () async => PermissionOutcome.granted)
          .requestPermission(),
      PermissionOutcome.granted,
    );
    expect(
      await LocationChannel(request: () async => PermissionOutcome.denied)
          .requestPermission(),
      PermissionOutcome.denied,
    );
  });
}
