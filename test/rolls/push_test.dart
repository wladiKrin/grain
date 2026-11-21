import 'package:flutter_test/flutter_test.dart';
import 'package:grain/rolls/push.dart';

import 'support.dart';

void main() {
  test('exposed-at ISO in thirds', () {
    for (final (box, p, iso) in [
      (400, 3, 800),
      (400, 1, 500),
      (400, 2, 640),
      (400, -1, 320),
      (400, -2, 250),
      (400, 9, 3200),
      (400, -9, 50),
      (125, 3, 250),
      (100, 4, 250),
      (160, 2, 250),
      (320, 0, 320),
      (3200, 6, 12800),
      (50, -3, 25),
    ]) {
      expect(exposedIsoFor(box, p), iso, reason: '$box $p');
    }
    expect(exposedIsoFor(3200, 9), isNull);
    expect(exposedIsoFor(6, -1), isNull);
  });

  test('push labels and header lines', () {
    expect(pushLabel(0), 'Box speed');
    expect(pushLabel(3), 'Push +1');
    expect(pushLabel(4), 'Push +1⅓');
    expect(pushLabel(-2), 'Pull −⅔');
    final hp5 = roll(
      filmStock: 'Ilford HP5 Plus',
      boxIso: 400,
      pushThirds: 3,
      number: 4,
      size: 36,
    );
    expect(filmLine(hp5), 'HP5 · 400 → 800');
    expect(filmLine(hp5.copyWith(pushThirds: 0)), 'HP5 · 400');
    expect(
      filmLine(hp5.copyWith(filmStock: 'Rollei RPX 400')),
      'Rollei RPX 400 · 400 → 800',
    );
    expect(rollStatus(hp5, 12), 'Roll 4 · frame 12/36');
    expect(rollStatus(hp5, 37), 'Roll 4 · frame 37/36 +1');
    expect(rollStatus(hp5, -1), 'Roll 4 · frame 00/36');
  });
}
