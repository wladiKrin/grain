import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/scales.dart';
import 'package:grain/gear/model.dart';

void main() {
  test('FilmFormat geometry', () {
    expect(FilmFormat.f135.portraitAspect, closeTo(2 / 3, 1e-12));
    expect(FilmFormat.f66.portraitAspect, 1.0);
    expect(FilmFormat.f66.diagonalMm, closeTo(79.196, 1e-3));
    expect(FilmFormat.byId('120-67'), FilmFormat.f67);
    expect(FilmFormat.byId('nope'), isNull);
  });

  const body = Body(
    id: 'x',
    make: 'M',
    model: 'N',
    mount: 'm',
    format: FilmFormat.f135,
    frames: 36,
    shutter: ['1/60', 'B'],
  );
  const lens = Lens(
    id: 'l',
    make: 'Canon',
    name: 'FD 50mm f/1.8',
    mount: 'm',
    focalMin: 50,
    focalMax: 50,
    maxAperture: [ApertureAt(50, 1.8)],
    minAperture: 22,
    apertureStep: StepSize.half,
  );

  test('Body value equality and copyWith', () {
    expect(body.copyWith(), body);
    expect(body.copyWith().hashCode, body.hashCode);
    expect(body.copyWith(shutter: ['1/60', 'B']), body);
    expect(body.copyWith(shutter: ['1/60']), isNot(body));
    expect(body.copyWith(isoMax: 3200), isNot(body));
    expect(body.hasBulb, isTrue);
    expect(body.copyWith(shutter: ['1/60']).hasBulb, isFalse);
    expect(body.displayName, 'M N');
  });

  test('Lens value equality, shortName, isZoom', () {
    expect(lens.copyWith(), lens);
    expect(lens.copyWith().hashCode, lens.hashCode);
    expect(lens.copyWith(maxAperture: [const ApertureAt(50, 2)]), isNot(lens));
    expect(lens.shortName, 'FD 50/1.8');
    expect(lens.isZoom, isFalse);
    expect(lens.copyWith(focalMax: 70).isZoom, isTrue);
    expect(const ApertureAt(1, 2), const ApertureAt(1, 2));
  });
}
