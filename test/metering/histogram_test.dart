import 'package:flutter_test/flutter_test.dart';
import 'package:grain/metering/histogram.dart';
import 'package:grain/rolls/latitude.dart';

void main() {
  final bins = List<int>.filled(64, 0)
    ..[10] = 100
    ..[20] = 25;

  test(
    'mid grey sits at x 0.4615',
    () => expect(histogramX(.18), closeTo(.4615, 1e-3)),
  );

  test('negative film band around 18 % grey', () {
    final v = histogramView(
      bins: bins,
      meteredLuma: .18,
      latitude: FilmLatitude.negative,
    )!;
    expect(v.marker, closeTo(.4615, 1e-3));
    expect(v.bandStart, closeTo(.2358, 1e-3)); // 0.045
    expect(v.bandEnd, closeTo(.9980, 1e-3)); // 1.44 clamps to white
  });

  test('slide band', () {
    final v = histogramView(
      bins: bins,
      meteredLuma: .18,
      latitude: FilmLatitude.slide,
    )!;
    expect(v.bandStart, closeTo(.3923, 1e-3));
    expect(v.bandEnd, closeTo(.5414, 1e-3));
  });

  test('a +1 manual offset moves the band one stop down the scene', () {
    final v = histogramView(
      bins: bins,
      meteredLuma: .18,
      latitude: FilmLatitude.negative,
      offsetStops: 1,
    )!;
    expect(v.bandStart, closeTo(.1634, 1e-3)); // 0.0225
    expect(v.bandEnd, closeTo(.8636, 1e-3)); // 0.72
    expect(v.marker, closeTo(.4615, 1e-3));
  });

  test('heights are sqrt of the share of the largest bin', () {
    final v = histogramView(
      bins: bins,
      meteredLuma: .18,
      latitude: FilmLatitude.negative,
    )!;
    expect(v.heights.length, 64);
    expect(v.heights[10], 1.0);
    expect(v.heights[20], closeTo(.5, 1e-9));
    expect(v.heights[0], 0.0);
    expect(() => v.heights[0] = 1, throwsUnsupportedError);
  });

  test('no view for empty, short or unmetered input', () {
    expect(
      histogramView(
        bins: List.filled(64, 0),
        meteredLuma: .18,
        latitude: FilmLatitude.negative,
      ),
      isNull,
    );
    expect(
      histogramView(
        bins: List.filled(32, 1),
        meteredLuma: .18,
        latitude: FilmLatitude.negative,
      ),
      isNull,
    );
    expect(
      histogramView(
        bins: bins,
        meteredLuma: 0,
        latitude: FilmLatitude.negative,
      ),
      isNull,
    );
    expect(
      histogramView(
        bins: bins,
        meteredLuma: double.nan,
        latitude: FilmLatitude.negative,
      ),
      isNull,
    );
    expect(
      histogramView(
        bins: bins,
        meteredLuma: double.infinity,
        latitude: FilmLatitude.negative,
      ),
      isNull,
    );
  });

  test('srgbEncode inverts the decode curve', () {
    expect(srgbEncode(0), 0);
    expect(srgbEncode(1), closeTo(1, 1e-12));
    expect(srgbEncode(0.002), closeTo(0.02584, 1e-9));
  });
}
