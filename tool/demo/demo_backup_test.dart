// Writes a demo backup (invented rolls and readings at public places in
// Lisbon and Sintra) for screenshots, so no real data or location is shown.
//
//   GRAIN_DEMO_OUT=/some/dir flutter test tool/demo/demo_backup_test.dart
//
// Import the zip with Settings > Import everything on a clean install.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/backup/backup.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/rolls/location.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/snapshot_store.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/ui/permissions.dart';

import '../../test/support/gear_fixtures.dart';

/// A frame to log: where, when (minutes after the day's start) and how.
typedef Shot = ({
  double lat,
  double lon,
  int minute,
  String lens,
  double? aperture,
  String? shutter,
  double ev,
  String? note,
  bool spot,
  bool skip,
});

Shot shot(
  double lat,
  double lon,
  int minute,
  String lens, {
  double? f,
  String? t,
  double ev = 13,
  String? note,
  bool spot = false,
  bool skip = false,
}) => (
  lat: lat,
  lon: lon,
  minute: minute,
  lens: lens,
  aperture: f,
  shutter: t,
  ev: ev,
  note: note,
  spot: spot,
  skip: skip,
);

double seconds(String t) {
  if (t.startsWith('1/')) return 1 / double.parse(t.substring(2));
  return double.parse(t.replaceAll('"', ''));
}

/// Answers each fix request with [next], as the phone's location would.
class DemoLocation implements LocationSource {
  GeoFix? next;
  @override
  Future<GeoFix?> current() async => next;
  @override
  Future<PermissionOutcome> requestPermission() async =>
      PermissionOutcome.granted;
}

void main() {
  test('demo backup', () async {
    final out = Platform.environment['GRAIN_DEMO_OUT'] ?? 'build/demo';
    var clock = DateTime(2026, 10, 3, 9);
    final settings = Settings.inMemory();
    await settings.setLocation(true);
    final place = DemoLocation();
    final gear = GearController.inMemory(library: fixtureLibrary());
    await gear.load();
    final dir = Directory.systemTemp.createTempSync('grain-demo');
    final rolls = RollController.inMemory(
      settings: settings,
      snapshots: SnapshotStore(dir),
      now: () => clock,
      location: place,
    );
    await rolls.load();

    for (final id in [
      'canon-a1',
      'nikon-fm2',
      'pentax-67',
      'canon-ae1-program',
    ]) {
      await gear.toggleFavorite(libBody(id));
    }
    for (final id in [
      'canon-fd-50-1.8',
      'canon-fd-28-2.8',
      'canon-fd-50-1.4',
      'nikon-ais-50-1.4',
      'pentax-67-105-2.4',
    ]) {
      await gear.toggleFavorite(libLens(id));
    }

    Future<void> shoot(DateTime day, List<Shot> shots, {int iso = 400}) async {
      for (final s in shots) {
        clock = day.add(Duration(minutes: s.minute));
        final lens = libLens(s.lens);
        final lensPart = Exposure(
          lensId: lens.id,
          lensMake: lens.make,
          lensName: lens.name,
          focal: lens.focalMin,
        );
        place.next = GeoFix(latitude: s.lat, longitude: s.lon, accuracy: 8);
        if (s.skip) {
          await rolls.skipFrame(lens: lensPart);
        } else {
          await rolls.logFrame(
            lensPart.copyWith(
              mode: () => MeterMode.aperturePriority,
              aperture: () => s.aperture,
              shutter: () => s.shutter,
              exposureTime: () => seconds(s.shutter!),
              iso: () => iso,
              meteredEv: () => s.ev,
              area: () => s.spot ? MeterArea.spot : MeterArea.average,
            ),
            note: s.note,
          );
        }
        // The fix attaches after the frame is saved.
        await pumpEventQueue();
      }
    }

    // Roll 1: Portra 400 on the Canon A-1, Lisbon's old town.
    final day1 = DateTime(2026, 10, 3, 9, 30);
    clock = day1;
    var roll = await rolls.startRoll(
      filmStock: 'Kodak Portra 400',
      filmType: FilmType.colorNeg,
      boxIso: 400,
      pushThirds: 0,
      body: libBody('canon-a1'),
      size: 36,
      startFrame: StartFrame.one,
    );
    await shoot(day1, [
      shot(
        38.7139,
        -9.1334,
        0,
        'canon-fd-50-1.8',
        f: 8,
        t: '1/250',
        ev: 14,
        note: 'Tram 28 at Graça',
      ),
      shot(
        38.7187,
        -9.1328,
        25,
        'canon-fd-28-2.8',
        f: 11,
        t: '1/250',
        ev: 15,
        note: 'Miradouro da Senhora do Monte',
      ),
      shot(
        38.7116,
        -9.1300,
        55,
        'canon-fd-50-1.8',
        f: 5.6,
        t: '1/125',
        ev: 12,
        note: 'Alfama stairs, shade',
      ),
      shot(
        38.7108,
        -9.1306,
        70,
        'canon-fd-50-1.8',
        f: 4,
        t: '1/60',
        ev: 10,
        spot: true,
        note: 'Doorway, spot on the tiles',
      ),
      shot(38.7107, -9.1305, 72, 'canon-fd-50-1.8', skip: true),
      shot(
        38.7097,
        -9.1335,
        110,
        'canon-fd-28-2.8',
        f: 8,
        t: '1/500',
        ev: 15,
        note: 'Sé Cathedral',
      ),
      shot(
        38.7075,
        -9.1364,
        150,
        'canon-fd-28-2.8',
        f: 11,
        t: '1/500',
        ev: 15.5,
        note: 'Praça do Comércio',
      ),
      shot(
        38.7107,
        -9.1393,
        230,
        'canon-fd-50-1.8',
        f: 2.8,
        t: '1/60',
        ev: 9,
        note: 'Café, window light',
      ),
      shot(
        38.7139,
        -9.1405,
        290,
        'canon-fd-50-1.8',
        f: 5.6,
        t: '1/250',
        ev: 13,
        note: 'Elevador de Santa Justa',
      ),
      shot(
        38.7108,
        -9.1430,
        520,
        'canon-fd-50-1.8',
        f: 1.8,
        t: '1/30',
        ev: 6.5,
        spot: true,
        note: 'Bairro Alto at dusk',
      ),
    ]);
    await rolls.finishRoll(roll.id);

    // Roll 2: HP5 pushed a stop, on the Nikon FM2, then the Canon AE-1
    // Program from frame 7 (Belém and LX Factory).
    final day2 = DateTime(2026, 10, 4, 10);
    clock = day2;
    roll = await rolls.startRoll(
      filmStock: 'Ilford HP5 Plus',
      filmType: FilmType.bwNeg,
      boxIso: 400,
      pushThirds: 3,
      body: libBody('nikon-fm2'),
      size: 36,
      startFrame: StartFrame.one,
    );
    await shoot(day2, [
      shot(
        38.6916,
        -9.2160,
        0,
        'nikon-ais-50-1.4',
        f: 11,
        t: '1/500',
        ev: 15,
        note: 'Belém Tower',
      ),
      shot(
        38.6935,
        -9.2058,
        30,
        'nikon-ais-50-1.4',
        f: 8,
        t: '1/500',
        ev: 14.5,
        note: 'Monument to the Discoveries',
      ),
      shot(
        38.6979,
        -9.2068,
        70,
        'nikon-ais-50-1.4',
        f: 5.6,
        t: '1/250',
        ev: 12,
        note: 'Jerónimos cloister',
      ),
      shot(
        38.6976,
        -9.2034,
        100,
        'nikon-ais-50-1.4',
        f: 2.8,
        t: '1/125',
        ev: 10,
        spot: true,
        note: 'Pastéis queue',
      ),
      shot(
        38.6957,
        -9.1937,
        150,
        'nikon-ais-50-1.4',
        f: 16,
        t: '1/500',
        ev: 16,
        note: 'MAAT roof, river glare',
      ),
      shot(
        38.6960,
        -9.1940,
        160,
        'nikon-ais-50-1.4',
        f: 8,
        t: '1/1000',
        ev: 15,
        note: '25 de Abril bridge',
      ),
    ], iso: 800);
    await rolls.continueRoll(roll.id, libBody('canon-ae1-program'));
    await shoot(day2, [
      shot(
        38.7033,
        -9.1789,
        260,
        'canon-fd-50-1.4',
        f: 4,
        t: '1/125',
        ev: 11,
        note: 'LX Factory, Ler Devagar',
      ),
      shot(
        38.7031,
        -9.1786,
        280,
        'canon-fd-50-1.4',
        f: 2,
        t: '1/60',
        ev: 9,
        note: 'Murals, overcast',
      ),
      shot(
        38.7028,
        -9.1792,
        300,
        'canon-fd-50-1.4',
        f: 1.4,
        t: '1/60',
        ev: 7.5,
        spot: true,
        note: 'Street lamps',
      ),
    ], iso: 800);
    await rolls.finishRoll(roll.id);

    // Roll 3, still loaded: Velvia 50 on the Pentax 67, a day in Sintra.
    final day3 = DateTime(2026, 10, 6, 9);
    clock = day3;
    roll = await rolls.startRoll(
      filmStock: 'Fujifilm Velvia 50',
      filmType: FilmType.slide,
      boxIso: 50,
      pushThirds: 0,
      body: libBody('pentax-67'),
      size: 10,
      startFrame: StartFrame.one,
    );
    await shoot(day3, [
      shot(
        38.7876,
        -9.3906,
        0,
        'pentax-67-105-2.4',
        f: 8,
        t: '1/60',
        ev: 12,
        note: 'Pena Palace, morning',
      ),
      shot(
        38.7963,
        -9.3960,
        90,
        'pentax-67-105-2.4',
        f: 5.6,
        t: '1/15',
        ev: 9,
        spot: true,
        note: 'Quinta da Regaleira well',
      ),
      shot(
        38.7975,
        -9.3906,
        150,
        'pentax-67-105-2.4',
        f: 11,
        t: '1/60',
        ev: 13,
        note: 'Sintra village',
      ),
      shot(
        38.7804,
        -9.4989,
        330,
        'pentax-67-105-2.4',
        f: 16,
        t: '1/60',
        ev: 14,
        note: 'Cabo da Roca',
      ),
    ], iso: 50);

    // Saved readings, no roll.
    for (final (lat, lon, minute, ev, note) in [
      (38.7223, -9.1393, 0, 12.0, 'Avenida da Liberdade, shade'),
      (38.7166, -9.1500, 40, 8.0, 'Jardim da Estrela, under the trees'),
      (38.7069, -9.1450, 90, 11.0, 'Cais do Sodré, overcast'),
    ]) {
      clock = DateTime(2026, 10, 5, 15).add(Duration(minutes: minute));
      place.next = GeoFix(latitude: lat, longitude: lon, accuracy: 10);
      await rolls.saveReading(
        Exposure(
          mode: MeterMode.aperturePriority,
          aperture: 5.6,
          shutter: '1/125',
          exposureTime: 1 / 125,
          iso: 400,
          meteredEv: ev,
          area: MeterArea.average,
        ),
        body: null,
        format: FilmFormat.f135,
        note: note,
      );
      await pumpEventQueue();
    }

    final file = await writeBackup(
      out: Directory(out),
      gear: gear,
      rolls: rolls,
      settings: settings,
      now: DateTime(2026, 10, 7, 12),
    );
    // ignore: avoid_print
    print('DEMO ${file.path}');
  });
}
