import 'model.dart';

class FilmStock {
  const FilmStock(this.name, this.short, this.iso, this.type);

  final String name;
  final String short;
  final int iso;
  final FilmType type;
}

const List<FilmStock> filmStocks = [
  FilmStock('Ilford HP5 Plus', 'HP5', 400, FilmType.bwNeg),
  FilmStock('Ilford FP4 Plus', 'FP4', 125, FilmType.bwNeg),
  FilmStock('Ilford Delta 100', 'Delta 100', 100, FilmType.bwNeg),
  FilmStock('Ilford Delta 400', 'Delta 400', 400, FilmType.bwNeg),
  FilmStock('Ilford Delta 3200', 'Delta 3200', 3200, FilmType.bwNeg),
  FilmStock('Ilford Pan F Plus', 'Pan F', 50, FilmType.bwNeg),
  FilmStock('Ilford XP2 Super', 'XP2', 400, FilmType.bwNeg),
  FilmStock('Kentmere Pan 400', 'Kentmere 400', 400, FilmType.bwNeg),
  FilmStock('Kodak Tri-X 400', 'Tri-X', 400, FilmType.bwNeg),
  FilmStock('Kodak T-Max 100', 'TMX', 100, FilmType.bwNeg),
  FilmStock('Kodak T-Max 400', 'TMY', 400, FilmType.bwNeg),
  FilmStock('Fomapan 100', 'Foma 100', 100, FilmType.bwNeg),
  FilmStock('Fomapan 400', 'Foma 400', 400, FilmType.bwNeg),
  FilmStock('Kodak Portra 160', 'Portra 160', 160, FilmType.colorNeg),
  FilmStock('Kodak Portra 400', 'Portra 400', 400, FilmType.colorNeg),
  FilmStock('Kodak Portra 800', 'Portra 800', 800, FilmType.colorNeg),
  FilmStock('Kodak Ektar 100', 'Ektar', 100, FilmType.colorNeg),
  FilmStock('Kodak Gold 200', 'Gold', 200, FilmType.colorNeg),
  FilmStock('Kodak UltraMax 400', 'UltraMax', 400, FilmType.colorNeg),
  FilmStock('Fujifilm 200', 'Fuji 200', 200, FilmType.colorNeg),
  FilmStock('CineStill 800T', '800T', 800, FilmType.colorNeg),
  FilmStock('CineStill 400D', '400D', 400, FilmType.colorNeg),
  FilmStock(
    'Lomography Color Negative 400',
    'Lomo 400',
    400,
    FilmType.colorNeg,
  ),
  FilmStock('Kodak Ektachrome E100', 'E100', 100, FilmType.slide),
  FilmStock('Fujifilm Velvia 50', 'Velvia 50', 50, FilmType.slide),
  FilmStock('Fujifilm Provia 100F', 'Provia', 100, FilmType.slide),
];

/// Short display name for a known stock (exact name match), else [stock].
String shortFilmName(String stock) {
  for (final f in filmStocks) {
    if (f.name == stock) return f.short;
  }
  return stock;
}
