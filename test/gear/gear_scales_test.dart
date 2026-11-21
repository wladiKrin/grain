import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_scales.dart';
import 'package:grain/gear/model.dart';

import '../support/gear_fixtures.dart';

void main() {
  test('free mode is the plan-1 scales plus Bulb', () {
    final g = scalesFor(const GearSetup());
    expect(g.apertures.length, 37);
    expect(g.shutters.first.label, '1/8000');
    expect(g.shutters.last.label, '30"');
    expect(g.hasBulb, isTrue);
    expect(g.focals.length, 30);
    expect(g.format, FilmFormat.f135);
  });
  test('Canon A-1 + FD 50mm f/1.8', () {
    final g = scalesFor(
      GearSetup(
        body: libBody('canon-a1'),
        lens: libLens('canon-fd-50-1.8'),
        focal: 50,
      ),
    );
    expect(g.shutters.map((v) => v.label), [
      '1/1000',
      '1/500',
      '1/250',
      '1/125',
      '1/60',
      '1/30',
      '1/15',
      '1/8',
      '1/4',
      '1/2',
      '1"',
      '2"',
      '4"',
      '8"',
      '15"',
      '30"',
    ]);
    expect(g.apertures.map((v) => v.label), [
      '1.8',
      '2',
      '2.4',
      '2.8',
      '3.3',
      '4',
      '4.8',
      '5.6',
      '6.7',
      '8',
      '9.5',
      '11',
      '13',
      '16',
      '19',
      '22',
    ]);
    expect(g.isos.first.label, '6');
    expect(g.isos.last.label, '12800');
    expect(g.focals.map((v) => v.value), [50]);
  });
  test('varying-aperture zoom: widest aperture follows the focal length', () {
    final l = libLens('canon-fd-35-70-3.5-4.5');
    expect(effectiveMaxAperture(l, 35), 3.5);
    expect(effectiveMaxAperture(l, 50), closeTo(4, 1e-9));
    expect(effectiveMaxAperture(l, 69), 4.5);
    expect(effectiveMaxAperture(l, 70), 4.5);
    expect(
      scalesFor(GearSetup(body: libBody('canon-a1'), lens: l, focal: 70))
          .apertures
          .take(2)
          .map((v) => v.label),
      ['4.5', '5.6'],
    );
  });
  test(
    'zoom focal detents',
    () => expect(
      focalValuesFor(libLens('canon-fd-35-70-3.5-4.5')).map((v) => v.label),
      ['35', '40', '45', '50', '55', '58', '60', '70'],
    ),
  );
  test('body ISO range and Bulb flag', () {
    final g = scalesFor(GearSetup(body: libBody('canon-ae1')));
    expect(g.isos.first.label, '25');
    expect(g.isos.last.label, '3200');
    expect(g.hasBulb, isTrue);
    expect(g.apertures.length, 37);
  });
  test('GearSetup value equality', () {
    expect(const GearSetup(), const GearSetup());
    expect(const GearSetup().hashCode, const GearSetup().hashCode);
    expect(const GearSetup(focal: 35) == const GearSetup(), isFalse);
  });
}
