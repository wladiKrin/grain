import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/rolls/codec.dart';
import 'package:grain/rolls/model.dart';

import 'support.dart';

final r4 = roll(number: 4, pushThirds: 4);

Frame frame({
  int number = 12,
  String? note,
  Exposure? exposure,
  bool located = true,
  String? snapshot = 'abc.jpg',
}) => Frame(
  id: 'f$number',
  rollId: 'r',
  position: 0,
  number: number,
  exposure:
      exposure ??
      const Exposure(
        mode: MeterMode.aperturePriority,
        aperture: 5.6,
        shutter: '1/125',
        exposureTime: 0.008,
        iso: 1000,
        lensId: 'canon-fd-50-1.8',
        lensMake: 'Canon',
        lensName: 'FD 50mm f/1.8',
        focal: 50,
        meteredEv: 12.34,
        area: MeterArea.spot,
      ),
  takenAt: DateTime.utc(2026, 11, 21, 13, 3, 22),
  utcOffsetMinutes: 60,
  note: note,
  location: located ? const GeoFix(latitude: 52.52, longitude: 13.405) : null,
  snapshot: snapshot,
  updatedAt: t0,
);

String row(String csv, int i) => csv.split('\r\n')[i];

void main() {
  test('CSV escapes commas, quotes and line breaks', () {
    final csv = rollToCsv(r4, [
      frame(note: 'Window light, "golden"\nsecond line'),
    ]);
    expect(
      csv.startsWith(
        '﻿roll,film,film_type,box_iso,push_stops,exposed_iso,body,frame,',
      ),
      isTrue,
    );
    expect(csv, contains(',"Window light, ""golden""\nsecond line",'));
    expect(csv.endsWith('\r\n'), isTrue);
    expect('\r\n'.allMatches(csv).length, 2);
  });

  test('CSV row values', () {
    final csv = rollToCsv(r4, [frame()]);
    expect(
      row(csv, 1),
      '4,Ilford HP5 Plus,bw-neg,400,+1.33,1000,Canon A-1,12,2026-11-21T14:03:22,+01:00,5.6,1/125,0.008,1000,FD 50mm f/1.8,50,aperture-priority,12.3,,52.52,13.405,,abc.jpg',
    );
  });

  test('push_stops formatting', () {
    String stops(int t) =>
        row(rollToCsv(roll(pushThirds: t), [frame()]), 1).split(',')[4];
    expect(stops(-2), '-0.67');
    expect(stops(0), '0');
    expect(stops(3), '+1');
    expect(stops(4), '+1.33');
  });

  test('offset_stops has two decimals; negative offsets render', () {
    final f = frame(exposure: const Exposure(offset: -0.5))
        .copyWith(utcOffsetMinutes: () => -330);
    final r = row(rollToCsv(r4, [f]), 1).split(',');
    expect(r[9], '-05:30');
    expect(r[18], '-0.50');
  });

  test('blank frame is an empty row with its number', () {
    final blank = Frame(
      id: 'b',
      rollId: 'r',
      position: 0,
      number: 7,
      updatedAt: t0,
    );
    expect(
      row(rollToCsv(r4, [blank]), 1),
      '4,Ilford HP5 Plus,bw-neg,400,+1.33,1000,Canon A-1,7,,,,,,,,,,,,,,,',
    );
  });

  test('JSON is EXIF-ready', () {
    final f = (rollToJson(r4, [frame()])['frames'] as List).single as Map;
    expect(f['number'], '12');
    expect(f['aperture'], 5.6);
    expect(f['shutter'], '1/125');
    expect(f['exposureTime'], .008);
    expect(f['iso'], 1000);
    expect(f['focalLength'], 50);
    expect(f['takenAt'], '2026-11-21T14:03:22+01:00');
    expect(f['lens'], {
      'id': 'canon-fd-50-1.8',
      'make': 'Canon',
      'name': 'FD 50mm f/1.8',
    });
    expect(
      (rollToJson(r4, [])['roll'] as Map)['film'],
      containsPair('pushStops', closeTo(4 / 3, 1e-12)),
    );
  });

  test('frame 00 and location null', () {
    final f =
        (rollToJson(r4, [frame(number: -1, located: false)])['frames'] as List)
                .single
            as Map;
    expect(f['number'], '00');
    expect(f['location'], isNull);
  });

  test('roll JSON round-trips exactly, incl. blank frames', () {
    final blank = Frame(
      id: 'b',
      rollId: 'r',
      position: 1,
      number: 13,
      updatedAt: t0,
    );
    final odd = frame(number: 5).copyWith(
      takenAt: () => DateTime.utc(2026, 11, 21, 13, 3, 22, 123, 456),
      utcOffsetMinutes: () => -330,
    );
    final src = r4.copyWith(
      finishedAt: () => DateTime.utc(2026, 12),
      notes: 'a, "b"',
      startFrame: StartFrame.doubleZero,
    );
    final list = [frame(number: -1), odd, blank];
    final (back, frames) = rollFromJson(rollToJson(src, list));
    expect(back, src);
    expect(frames, list);
  });

  test('reading JSON round-trips', () {
    final r = SavedReading(
      id: 's1',
      bodyId: null,
      format: FilmFormat.f66,
      exposure: frame().exposure,
      takenAt: DateTime.utc(2026, 11, 21, 13, 3, 22),
      utcOffsetMinutes: 60,
      note: 'n',
      location: const GeoFix(latitude: 1, longitude: 2, accuracy: 3.5),
      snapshot: 'x.jpg',
      updatedAt: t0,
    );
    expect(readingFromJson(readingToJson(r)), r);
  });

  test('foreign JSON is refused with a path', () {
    expect(
      () => rollFromJson({'schema': 1, 'type': 'grain-roll', 'roll': {}}),
      throwsA(
        isA<RollFormatException>().having(
          (e) => e.message,
          'message',
          startsWith('roll.id:'),
        ),
      ),
    );
    expect(() => rollFromJson([]), throwsA(isA<RollFormatException>()));
  });

  test('isoWithOffset', () {
    final t = DateTime.utc(2026, 11, 21, 13, 3, 22);
    expect(isoWithOffset(t, 60), '2026-11-21T14:03:22+01:00');
    expect(isoWithOffset(t, -330), '2026-11-21T07:33:22-05:30');
    expect(isoWithOffset(t, 0), '2026-11-21T13:03:22+00:00');
  });

  test('CSV neutralises formula triggers in free text only', () {
    final f = frame(note: '=SUM(A1)').copyWith(
      exposure: const Exposure(lensName: '+cmd', offset: -0.5, shutter: '@x'),
    );
    final csv = rollToCsv(roll(number: 4), [f]);
    final cols = row(csv, 1).split(',');
    expect(cols[14], "'+cmd");
    expect(cols[11], "'@x");
    expect(cols[18], '-0.50');
    expect(cols[21], "'=SUM(A1)");
    final tab = rollToCsv(roll(number: 4), [frame(note: '\tx')]);
    expect(tab, contains(",'\tx,"));
    final neg = rollToCsv(roll(pushThirds: -2), [frame()]);
    expect(row(neg, 1).split(',')[4], '-0.67');
  });

  test('BOM leads the CSV', () {
    expect(rollToCsv(r4, []).codeUnitAt(0), 0xFEFF);
  });

  test('null utc offset invents no offset', () {
    final f = frame().copyWith(utcOffsetMinutes: () => null);
    final cols = row(rollToCsv(r4, [f]), 1).split(',');
    expect(cols[8], '2026-11-21T13:03:22');
    expect(cols[9], '');
    final j = (rollToJson(r4, [f])['frames'] as List).single as Map;
    expect(j['takenAt'], '2026-11-21T13:03:22.000Z');
    expect(rollFromJson(rollToJson(r4, [f])).$2.single, f);
  });
}
