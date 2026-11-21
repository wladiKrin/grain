import 'model.dart';

/// Usable exposure range of a film around the metered exposure, in stops.
class FilmLatitude {
  const FilmLatitude({required this.under, required this.over});

  final double under, over;

  static const negative = FilmLatitude(under: -2, over: 3);
  static const slide = FilmLatitude(under: -0.5, over: 0.5);

  static FilmLatitude forType(FilmType? type) =>
      type == FilmType.slide ? slide : negative;

  @override
  bool operator ==(Object other) =>
      other is FilmLatitude && other.under == under && other.over == over;

  @override
  int get hashCode => Object.hash(under, over);
}
