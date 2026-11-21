import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/exposure/scales.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/rolls/ids.dart';
import 'package:grain/rolls/latitude.dart';
import 'package:grain/rolls/model.dart';

import 'support.dart';

void main() {
  test('roll derived values', () {
    final r = roll(pushThirds: 3);
    expect(r.bodyName, 'Canon A-1');
    expect(r.copyWith(bodyId: () => null).bodyName, 'No camera');
    expect(r.exposedIso, 800);
    expect(r.pushStops, 1.0);
    expect(r.isActive, isTrue);
    expect(r.copyWith(status: RollStatus.finished).isActive, isFalse);
    expect(roll(boxIso: 3200, pushThirds: 9).exposedIso, 3200);
  });

  test('copyWith clears nullable fields', () {
    final f = Frame(
      id: 'f',
      rollId: 'r',
      position: 0,
      number: 1,
      exposure: const Exposure(aperture: 2.8, mode: MeterMode.manual),
      takenAt: t0,
      utcOffsetMinutes: 60,
      note: 'n',
      location: const GeoFix(latitude: 1, longitude: 2, accuracy: 3),
      snapshot: 'a.jpg',
      updatedAt: t0,
    );
    final c = f.copyWith(snapshot: () => null);
    expect(c.snapshot, isNull);
    expect(c.copyWith(snapshot: () => 'a.jpg'), f);
    expect(f.copyWith(note: () => null).note, isNull);
    expect(f.copyWith(location: () => null).location, isNull);
    expect(f.copyWith(takenAt: () => null).takenAt, isNull);
    expect(f.copyWith(utcOffsetMinutes: () => null).utcOffsetMinutes, isNull);
    expect(f.copyWith(), f);
    expect(f.copyWith().hashCode, f.hashCode);
    final r = roll().copyWith(finishedAt: () => t0);
    expect(r.finishedAt, t0);
    expect(r.copyWith(finishedAt: () => null).finishedAt, isNull);
  });

  test('value equality and exposure blank', () {
    expect(Exposure.blank.isBlank, isTrue);
    expect(const Exposure(iso: 100).isBlank, isFalse);
    expect(const Exposure(iso: 100), const Exposure(iso: 100));
    expect(
      const Exposure(iso: 100).hashCode,
      const Exposure(iso: 100).hashCode,
    );
    expect(const Exposure(iso: 100).copyWith(iso: () => null).isBlank, isTrue);
    expect(const Exposure(area: MeterArea.spot), isNot(Exposure.blank));
    final s = SavedReading(
      id: 's',
      format: FilmFormat.f135,
      exposure: Exposure.blank,
      takenAt: t0,
      utcOffsetMinutes: 0,
      updatedAt: t0,
    );
    expect(s.bodyName, 'No camera');
    expect(
      s.copyWith(bodyId: () => 'x', bodyMake: 'A', bodyModel: 'B').bodyName,
      'A B',
    );
    expect(s.copyWith(), s);
  });

  test('enum lookups', () {
    expect(FilmType.byId('slide'), FilmType.slide);
    expect(FilmType.byId('x'), isNull);
    expect(StartFrame.byLabel('00'), StartFrame.doubleZero);
    expect(StartFrame.doubleZero.number, -1);
    expect(StartFrame.byLabel('2'), isNull);
  });

  test('ids', () {
    expect(newId(), isNot(newId()));
    expect(newId().length, 36);
    final t = atSecond(DateTime.utc(2026, 1, 2, 3, 4, 5, 678, 9));
    expect(t, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(t.isUtc, isTrue);
    expect(atSecond(DateTime(2026, 1, 2, 3, 4, 5, 6)).isUtc, isTrue);
  });

  test('nominalValue', () {
    expect(nominalValue('1/125'), .008);
    expect(nominalValue('2"'), 2);
    expect(nominalValue('5.6'), 5.6);
  });

  test('latitude follows the film type unless set', () {
    expect(roll(filmType: FilmType.slide).latitude, FilmLatitude.slide);
    expect(
      roll(filmType: FilmType.slide, latitudeOverHalves: 2).latitude,
      const FilmLatitude(under: -0.5, over: 1),
    );
    expect(
      roll(filmType: FilmType.bwNeg, latitudeUnderHalves: -3).latitude,
      const FilmLatitude(under: -1.5, over: 3),
    );
    final r = roll(latitudeUnderHalves: -3);
    expect(
      r.copyWith(latitudeUnderHalves: () => null).latitudeUnderHalves,
      isNull,
    );
    expect(r.copyWith().latitudeUnderHalves, -3);
    expect(r == roll(latitudeUnderHalves: -3), isTrue);
    expect(r == roll(latitudeUnderHalves: -4), isFalse);
  });
}
