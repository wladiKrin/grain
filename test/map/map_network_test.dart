import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/map/map_network.dart';
import 'package:grain/map/map_styles.dart';

const _osm = MapStyleDoc(
  style: '{"version":8}',
  attribution: osmAttribution,
  hosts: {'tile.openstreetmap.org'},
);
final _liberty = MapStyleDoc(
  style: OpenFreeMapStyle.liberty.url,
  attribution: openFreeMapAttribution,
  hosts: const {'tiles.openfreemap.org'},
);

MapRequest _tile({bool ok = true, String host = 'tile.openstreetmap.org'}) =>
    MapRequest(Uri.parse('https://$host/5/16/10.png'), ok: ok);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the note shows after a few failures with no answer between', () {
    var told = 0;
    final f = MapFailures()
      ..addListener(() => told++)
      ..watch(_osm);
    for (var i = 0; i < MapFailures.failuresBeforeNote - 1; i++) {
      f.request(_tile(ok: false));
    }
    expect(f.showing, isFalse);
    expect(f.failing, isTrue);
    f.request(_tile());
    expect(f.failing, isFalse);
    for (var i = 0; i < MapFailures.failuresBeforeNote; i++) {
      f.request(_tile(ok: false));
    }
    expect(f.showing, isTrue);
    expect(told, 2);
    f.request(_tile());
    expect(f.showing, isFalse);
    expect(told, 3);
  });

  test('a style that cannot be read shows it at once', () {
    final f = MapFailures()..watch(_liberty);
    f.request(MapRequest(Uri.parse(_liberty.url!), ok: false));
    expect(f.styleFailed, isTrue);
    expect(f.showing, isTrue);
  });

  test('other servers, refused requests and a new style do not count', () {
    final f = MapFailures()..watch(_osm);
    for (var i = 0; i < 5; i++) {
      f.request(_tile(ok: false, host: 'tiles.openfreemap.org'));
      f.request(
        MapRequest(
          Uri.parse('https://tile.openstreetmap.org/1/0/0.png'),
          ok: false,
          blocked: true,
        ),
      );
    }
    expect(f.failing, isFalse);
    for (var i = 0; i < 5; i++) {
      f.request(_tile(ok: false));
    }
    expect(f.showing, isTrue);
    f.watch(_liberty);
    expect(f.showing, isFalse);
    expect(f.failures, 0);
    // Offline: nothing counts.
    f.watch(
      const MapStyleDoc(style: '{}', attribution: naturalEarthAttribution),
    );
    for (var i = 0; i < 5; i++) {
      f.request(_tile(ok: false));
    }
    expect(f.failing, isFalse);
  });

  test('dismissed, it stays away until the map answers and fails again', () {
    final f = MapFailures()..watch(_osm);
    for (var i = 0; i < 4; i++) {
      f.request(_tile(ok: false));
    }
    f.dismiss();
    expect(f.showing, isFalse);
    f.request(_tile(ok: false));
    expect(f.showing, isFalse);
    f.request(_tile());
    for (var i = 0; i < 3; i++) {
      f.request(_tile(ok: false));
    }
    expect(f.showing, isTrue);
  });

  test('the platform client is told the User-Agent and Offline, and its '
      'requests come back', () async {
    const channel = MethodChannel('grain/map_net');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async {
          calls.add(c);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final net = PlatformMapNetwork.instance;
    await net.configure(userAgent: osmUserAgent, offline: true);
    expect(calls.single.method, 'configure');
    expect(calls.single.arguments, {
      'userAgent': osmUserAgent,
      'offline': true,
    });

    final got = net.requests.first;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'grain/map_net',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('request', {
              'url': 'https://tile.openstreetmap.org/1/0/0.png',
              'ok': false,
              'blocked': false,
            }),
          ),
          (_) {},
        );
    final r = await got;
    expect(r.url.host, 'tile.openstreetmap.org');
    expect(r.ok, isFalse);
    expect(r.blocked, isFalse);
  });
}
