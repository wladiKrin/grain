import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/solver.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/metering/histogram.dart';
import 'package:grain/metering/reading.dart';

import '../support/fake_source.dart';

/// f/2, 1/100 s, ISO 100: log2(4 / 0.01) = 8.64 at mid grey.
final double midEv = math.log(400) / math.ln2;

double log2(double x) => math.log(x) / math.ln2;

void main() {
  group('manual engine', () {
    test('the stats map carries the engine and loop fields', () {
      final s = manualStats(requestedExposureNs: 5000000, requestedIso: 200);
      expect(s.engine, MeterEngine.manual);
      expect(s.tonemap, 'gamma2.2');
      expect(s.toneGamma, 2.2);
      expect(s.requestedExposureNs, 5000000);
      expect(s.requestedSensitivity, 200);
      expect(s.loop, 'steady');
      expect(s.atMinExposure, isFalse);
      expect(s.atMaxExposure, isFalse);
    });

    test('mid grey reads the exposure EV', () {
      final r = readingFrom(manualStats(), area: MeterArea.average)!;
      expect(r.ev100, closeTo(midEv, 1e-9));
      expect(r.flag, RangeFlag.ok);
    });

    test('a region twice mid grey reads +1 EV; the frame luma is ignored', () {
      final r = readingFrom(
        manualStats(crop: .36, frame: .9),
        area: MeterArea.average,
      )!;
      expect(r.ev100, closeTo(midEv + 1, 1e-9));
    });

    test('spot reads the spot luma', () {
      final s = manualStats(crop: .36, spot: .09);
      expect(
        readingFrom(s, area: MeterArea.spot)!.ev100,
        closeTo(midEv - 1, 1e-9),
      );
      expect(
        readingFrom(s, area: MeterArea.average)!.ev100,
        closeTo(midEv + 1, 1e-9),
      );
    });

    test('ISO, boost and time enter as in the AE formula', () {
      // 1/25 s at ISO 400: four stops more exposure, four stops less EV.
      final s = manualStats(exposureNs: 40000000, iso: 400);
      expect(
        readingFrom(s, area: MeterArea.average)!.ev100,
        closeTo(midEv - 4, 1e-9),
      );
    });

    test('the frame\'s own result values are used, not the request', () {
      final settled = manualStats();
      final asked = manualStats(
        requestedExposureNs: 2500000,
        requestedIso: 400,
        loop: 'settling',
      );
      expect(
        readingFrom(asked, area: MeterArea.average)!.ev100,
        readingFrom(settled, area: MeterArea.average)!.ev100,
      );
    });

    test('calibration is added', () {
      expect(
        readingFrom(
          manualStats(),
          area: MeterArea.average,
          calibration: -1 / 3,
        )!.ev100,
        closeTo(midEv - 1 / 3, 1e-9),
      );
    });

    test('a clipped region gives no reading while the loop can re-expose', () {
      expect(
        readingFrom(manualStats(crop: .97), area: MeterArea.average),
        isNull,
      );
      expect(
        readingFrom(manualStats(crop: .001), area: MeterArea.average),
        isNull,
      );
      expect(readingFrom(manualStats(spot: .99), area: MeterArea.spot), isNull);
    });

    test('clipped bright at the shortest exposure is over-range', () {
      final s = manualStats(crop: .97, cropClip: .8, atMin: true);
      final r = readingFrom(s, area: MeterArea.average)!;
      expect(r.flag, RangeFlag.over);
      expect(r.ev100.isFinite, isTrue);
      // A bright window in the crop at the minimum: still over.
      expect(
        readingFrom(
          manualStats(crop: .2, cropClip: .1, atMin: true),
          area: MeterArea.average,
        )!.flag,
        RangeFlag.over,
      );
      // Not at the minimum: the loop still steps down, so no reading.
      expect(
        readingFrom(
          manualStats(crop: .2, cropClip: .1),
          area: MeterArea.average,
        ),
        isNull,
      );
    });

    test(
      'clipped highlights the loop still steps down for give no reading',
      () {
        // A bright window: 40 % of the crop at the top code pulls the mean
        // down, the EV would under-read.
        expect(
          readingFrom(
            manualStats(crop: .7, cropClip: .4),
            area: MeterArea.average,
          ),
          isNull,
        );
        expect(
          readingFrom(
            manualStats(spot: .3, spotClip: .05),
            area: MeterArea.spot,
          ),
          isNull,
        );
        // The same share in the other region does not matter.
        expect(
          readingFrom(
            manualStats(crop: .3, spotClip: .5),
            area: MeterArea.average,
          )!.flag,
          RangeFlag.ok,
        );
        // At most [clipShare] clipped still reads.
        expect(
          readingFrom(
            manualStats(crop: .3, cropClip: .02),
            area: MeterArea.average,
          )!.flag,
          RangeFlag.ok,
        );
      },
    );

    test('clipped highlights at the loop\'s floor still read', () {
      // The loop stops stepping down at [clipFloor]: a lamp in the frame
      // must not blank the meter for good.
      for (final crop in [.1, .105, .06]) {
        expect(
          readingFrom(
            manualStats(crop: crop, cropClip: .1),
            area: MeterArea.average,
          )!.flag,
          RangeFlag.ok,
          reason: 'crop $crop',
        );
      }
      expect(
        readingFrom(
          manualStats(crop: .108, cropClip: .1),
          area: MeterArea.average,
        ),
        isNull,
      );
    });

    test('a held frame gives a clipped region\'s bound, flagged', () {
      final bright = readingFrom(
        manualStats(spot: .97, spotClip: .9),
        area: MeterArea.spot,
        held: true,
      )!;
      expect(bright.flag, RangeFlag.over);
      expect(bright.ev100, closeTo(midEv + log2(.97 / .18), 1e-9));
      final glare = readingFrom(
        manualStats(crop: .4, cropClip: .3),
        area: MeterArea.average,
        held: true,
      )!;
      expect(glare.flag, RangeFlag.over);
      final dark = readingFrom(
        manualStats(spot: .001),
        area: MeterArea.spot,
        held: true,
      )!;
      expect(dark.flag, RangeFlag.under);
      // An unclipped region reads as usual.
      expect(
        readingFrom(manualStats(), area: MeterArea.spot, held: true)!.flag,
        RangeFlag.ok,
      );
    });

    test('black at the longest exposure is under-range', () {
      final r = readingFrom(
        manualStats(crop: .0005, atMax: true),
        area: MeterArea.average,
      )!;
      expect(r.flag, RangeFlag.under);
      expect(r.ev100.isFinite, isTrue);
    });

    test('range flags follow the metered area', () {
      final s = manualStats(crop: .2, spot: .97, spotClip: 1, atMin: true);
      expect(readingFrom(s, area: MeterArea.spot)!.flag, RangeFlag.over);
      expect(readingFrom(s, area: MeterArea.average)!.flag, RangeFlag.ok);
    });

    test('degenerate metadata still yields no reading', () {
      expect(
        readingFrom(manualStats(aperture: 0), area: MeterArea.average),
        isNull,
      );
      expect(
        readingFrom(manualStats(exposureNs: 0), area: MeterArea.average),
        isNull,
      );
    });
  });

  group('AE fallback', () {
    Map<Object?, Object?> ae() => {
      'exposureNs': 1000000,
      'sensitivity': 100,
      'boost': 100,
      'aperture': 2.0,
      'minExposureNs': 10000,
      'maxExposureNs': 500000000,
      'minIso': 50,
      'maxIso': 6400,
      'frameLuma': .09,
      'cropLuma': .18,
      'spotLuma': .18,
      'histogram': List<Object?>.filled(64, 0),
    };

    test('no engine key means AE, with region relative to the frame', () {
      final s = MeterStats.fromMap(ae());
      expect(s.engine, MeterEngine.ae);
      // log2(4 / 0.001) + log2(0.18 / 0.09)
      expect(
        readingFrom(s, area: MeterArea.average)!.ev100,
        closeTo(log2(4000) + 1, 1e-9),
      );
    });

    test('engine=ae is the same; a clipped AE region still reads', () {
      final s = MeterStats.fromMap({...ae(), 'engine': 'ae', 'cropLuma': .97});
      expect(s.engine, MeterEngine.ae);
      expect(readingFrom(s, area: MeterArea.average), isNotNull);
    });
  });

  group('stats line', () {
    test('names the manual engine, tone curve, request, result and loop', () {
      final line = statsLine(
        manualStats(
          exposureNs: 8000000,
          iso: 30,
          requestedExposureNs: 4000000,
          requestedIso: 30,
          loop: 'settling',
          atMax: true,
        ),
        null,
      );
      for (final part in [
        'engine=manual',
        'tonemap=gamma2.2',
        'req=1/250.0,iso30',
        'res=1/125.0,iso30',
        'loop=settling',
        'loopLimit=max',
      ]) {
        expect(line, contains(part));
      }
    });

    test('says engine=ae for the fallback', () {
      final s = MeterStats.fromMap({
        'exposureNs': 1000000,
        'sensitivity': 100,
        'aperture': 2.0,
        'minExposureNs': 1,
        'maxExposureNs': 2,
        'minIso': 50,
        'maxIso': 6400,
        'frameLuma': .18,
        'cropLuma': .18,
        'spotLuma': .18,
        'histogram': <Object?>[1],
      });
      expect(statsLine(s, null), endsWith('engine=ae'));
    });
  });

  test('the histogram places luma with the stream\'s gamma', () {
    expect(
      histogramX(.18, gamma: 2.2),
      closeTo((255 * math.pow(.18, 1 / 2.2) + .5) / 256, 1e-12),
    );
    expect(histogramX(.18), closeTo(.4615, 1e-3));
  });
}
