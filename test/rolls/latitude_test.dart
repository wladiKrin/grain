import 'package:flutter_test/flutter_test.dart';
import 'package:grain/rolls/latitude.dart';
import 'package:grain/rolls/model.dart';

void main() {
  test('film types map to their latitude', () {
    expect(
      FilmLatitude.forType(FilmType.colorNeg),
      const FilmLatitude(under: -2, over: 3),
    );
    expect(FilmLatitude.forType(FilmType.bwNeg), FilmLatitude.negative);
    expect(
      FilmLatitude.forType(FilmType.slide),
      const FilmLatitude(under: -0.5, over: 0.5),
    );
    expect(FilmLatitude.forType(null), FilmLatitude.negative);
  });

  test('equality and hashCode are by value', () {
    expect(
      const FilmLatitude(under: -1, over: 1),
      const FilmLatitude(under: -1, over: 1),
    );
    expect(
      const FilmLatitude(under: -1, over: 1).hashCode,
      const FilmLatitude(under: -1, over: 1).hashCode,
    );
    expect(const FilmLatitude(under: -1, over: 1), isNot(FilmLatitude.slide));
  });
}
