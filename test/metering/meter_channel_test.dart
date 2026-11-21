import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/metering/meter_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const method = MethodChannel('grain/meter');
  const events = EventChannel('grain/meter/stats');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'start':
          return {
            'textureId': 7,
            'previewWidth': 1440,
            'previewHeight': 1080,
            'sensorOrientation': 90,
            'phoneEqFocal': 24.5,
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(events, null);
  });

  test('start parses PreviewInfo', () async {
    final info = await MeterChannel().start();
    expect(calls.single.method, 'start');
    expect(info.textureId, 7);
    expect(info.size, const Size(1440, 1080));
    expect(info.sensorOrientation, 90);
    expect(info.phoneEqFocal, 24.5);
  });

  test('setRegions sends crop and spot lists', () async {
    await MeterChannel().setRegions(
      const Rect.fromLTRB(0.1, 0.2, 0.9, 0.8),
      const Offset(0.5, 0.4),
      0.04,
    );
    expect(calls.single.method, 'setRegions');
    expect(calls.single.arguments, {
      'crop': [0.1, 0.2, 0.9, 0.8],
      'spot': [0.5, 0.4, 0.04],
    });
  });

  test('stop calls stop', () async {
    await MeterChannel().stop();
    expect(calls.single.method, 'stop');
  });

  test('start surfaces a denied PlatformException', () async {
    messenger.setMockMethodCallHandler(method, (call) async {
      throw PlatformException(code: 'denied');
    });
    expect(
      MeterChannel().start(),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'denied')),
    );
  });

  test('stats decodes event maps into MeterStats', () async {
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          sink.success({
            'exposureNs': 10000000,
            'sensitivity': 100,
            'boost': 100,
            'aperture': 1.7,
            'minExposureNs': 10000,
            'maxExposureNs': 1000000000,
            'minIso': 50,
            'maxIso': 6400,
            'frameLuma': 0.18,
            'cropLuma': 0.2,
            'spotLuma': 0.3,
            'histogram': List<int>.filled(64, 1),
          });
        },
      ),
    );
    final s = await MeterChannel().stats.first;
    expect(s.exposureNs, 10000000);
    expect(s.aperture, 1.7);
    expect(s.spotLuma, 0.3);
    expect(s.histogram.length, 64);
  });
}
