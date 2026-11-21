import 'dart:math' as math;

import '../rolls/latitude.dart';

/// Inverse of the sRGB decode: linear 0..1 to encoded 0..1.
double srgbEncode(double linear) => linear <= 0.0031308
    ? linear * 12.92
    : 1.055 * math.pow(linear, 1 / 2.4).toDouble() - 0.055;

/// Histogram x (0..1) of a linear luma, centred on its 8-bit bin.
double histogramX(double linear) =>
    (255 * srgbEncode(linear.clamp(0.0, 1.0).toDouble()) + 0.5) / 256;

class HistogramView {
  const HistogramView({
    required this.heights,
    required this.marker,
    required this.bandStart,
    required this.bandEnd,
  });

  final List<double> heights;
  final double marker, bandStart, bandEnd;
}

HistogramView? histogramView({
  required List<int> bins,
  required double meteredLuma,
  required FilmLatitude latitude,
  double offsetStops = 0,
}) {
  if (bins.length != 64) return null;
  if (!meteredLuma.isFinite || meteredLuma <= 0) return null;
  final peak = bins.reduce(math.max);
  if (peak <= 0) return null;
  double at(double stops) =>
      histogramX(meteredLuma * math.pow(2, stops - offsetStops));
  return HistogramView(
    heights: List.unmodifiable([for (final b in bins) math.sqrt(b / peak)]),
    marker: histogramX(meteredLuma),
    bandStart: at(latitude.under),
    bandEnd: at(latitude.over),
  );
}
