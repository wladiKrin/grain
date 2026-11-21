import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/scales.dart';
import 'package:grain/rolls/film_stocks.dart';
import 'package:grain/rolls/model.dart';

void main() {
  test('suggestions are unique, on the ISO scale, and HP5 is B&W 400', () {
    expect(filmStocks.map((f) => f.name).toSet().length, filmStocks.length);
    final labels = isoScale().map((v) => v.label).toSet();
    for (final f in filmStocks) {
      expect(labels, contains('${f.iso}'), reason: f.name);
    }
    expect(filmStocks.length, 26);
    final hp5 = filmStocks.firstWhere((f) => f.name == 'Ilford HP5 Plus');
    expect(hp5.iso, 400);
    expect(hp5.type, FilmType.bwNeg);
    expect(shortFilmName('Ilford HP5 Plus'), 'HP5');
    expect(shortFilmName('Rollei RPX 400'), 'Rollei RPX 400');
  });
}
