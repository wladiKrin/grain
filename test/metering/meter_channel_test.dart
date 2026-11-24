import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/metering/meter_channel.dart';
import 'package:grain/metering/reading.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const method = MethodChannel('grain/meter');
  const events = EventChannel('grain/meter/stats');
  const qr = EventChannel('grain/meter/qr');
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
        case 'setZoom':
        case 'startScan':
          final zoom = call.method == 'setZoom'
              ? call.arguments['zoom'] as double
              : 1.0;
          final wide = zoom < 1;
          return {
            'textureId': 7,
            'previewWidth': 1440,
            'previewHeight': 1080,
            'sensorOrientation': 90,
            'phoneEqFocal': wide ? 13.0 : 24.5 * zoom,
            'mainEqFocal': 24.5,
            'wideEqFocal': 13.0,
            'wide': wide,
            'zoom': wide ? 13 / 24.5 : zoom,
            'maxZoom': 10.0,
          };
        case 'snapshot':
          return '/data/user/0/io.github.wladikrin.grain/files/snapshots/'
              '${call.arguments['id']}.jpg';
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(events, null);
    messenger.setMockStreamHandler(qr, null);
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
      'spotMetering': false,
    });
  });

  test('setRegions says when the spot is metered', () async {
    await MeterChannel().setRegions(
      const Rect.fromLTRB(0, 0, 1, 1),
      const Offset(0.5, 0.5),
      0.02,
      spotMetering: true,
    );
    expect(calls.single.arguments['spotMetering'], isTrue);
  });

  test('setEngine sends the wish and parses the engine in use', () async {
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return call.arguments['manual'] == true ? 'manual' : 'ae';
    });
    expect(await MeterChannel().setEngine(manual: true), MeterEngine.manual);
    expect(await MeterChannel().setEngine(manual: false), MeterEngine.ae);
    expect(calls.map((c) => (c.method, c.arguments['manual'])), [
      ('setEngine', true),
      ('setEngine', false),
    ]);
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

  test('setZoom below 1 asks for the ultra-wide and parses the keys', () async {
    final info = await MeterChannel().setZoom(.53);
    expect(calls.single.method, 'setZoom');
    expect(calls.single.arguments, {'zoom': .53});
    expect(info.wide, isTrue);
    expect(info.wideEqFocal, 13.0);
    expect(info.mainEqFocal, 24.5);
    expect(info.phoneEqFocal, 13.0);
    expect(info.maxZoom, 10.0);
    expect(info.textureId, 7);
  });

  test('setZoom above 1 parses the zoomed preview', () async {
    final info = await MeterChannel().setZoom(4);
    expect(calls.single.arguments, {'zoom': 4.0});
    expect(info.wide, isFalse);
    expect(info.zoom, 4.0);
    expect(info.phoneEqFocal, 98.0);
  });

  test('a preview without zoom keys is unzoomed', () async {
    final info = await MeterChannel().start();
    expect(info.zoom, 1.0);
    expect(info.maxZoom, 1.0);
  });

  test('startScan calls startScan and parses PreviewInfo', () async {
    final info = await MeterChannel().startScan();
    expect(calls.single.method, 'startScan');
    expect(info.wide, isFalse);
    expect(info.phoneEqFocal, 24.5);
    expect(info.size, const Size(1440, 1080));
  });

  test('startScan surfaces a denied PlatformException', () async {
    messenger.setMockMethodCallHandler(method, (call) async {
      throw PlatformException(code: 'denied');
    });
    expect(
      MeterChannel().startScan(),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'denied')),
    );
  });

  test('start without the new keys defaults them', () async {
    final info = await MeterChannel().start();
    expect(info.mainEqFocal, info.phoneEqFocal);
    expect(info.mainEqFocal, 24.5);
    expect(info.wideEqFocal, isNull);
    expect(info.wide, isFalse);
  });

  test('qrCodes maps events to strings', () async {
    messenger.setMockStreamHandler(
      qr,
      MockStreamHandler.inline(onListen: (args, sink) => sink.success('abc')),
    );
    expect(await MeterChannel().qrCodes.first, 'abc');
  });

  test('snapshot passes the id and returns the path', () async {
    const id = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
    final path = await MeterChannel().snapshot(id);
    expect(calls.single.method, 'snapshot');
    expect(calls.single.arguments, {'id': id});
    expect(
      path,
      '/data/user/0/io.github.wladikrin.grain/files/snapshots/'
      'f47ac10b-58cc-4372-a567-0e02b2c3d479.jpg',
    );
  });

  test('a failed snapshot answers null', () async {
    messenger.setMockMethodCallHandler(method, (call) async {
      throw PlatformException(code: 'camera_error');
    });
    expect(
      await MeterChannel().snapshot('f47ac10b-58cc-4372-a567-0e02b2c3d479'),
      isNull,
    );
  });

  test('snapshot without a running camera answers null', () async {
    messenger.setMockMethodCallHandler(method, (call) async => null);
    expect(
      await MeterChannel().snapshot('f47ac10b-58cc-4372-a567-0e02b2c3d479'),
      isNull,
    );
  });

  test('snapshot without the native plugin answers null', () async {
    messenger.setMockMethodCallHandler(method, (call) async {
      throw MissingPluginException();
    });
    expect(
      await MeterChannel().snapshot('f47ac10b-58cc-4372-a567-0e02b2c3d479'),
      isNull,
    );
  });
}
