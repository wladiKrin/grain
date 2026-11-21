import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/shake.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/metering/fov.dart';

void main() {
  test('1/focal rule on the 135 equivalent', () {
    expect(shakeRisk(seconds: 1 / 32, eqFocal: 50), isTrue); // 1/30 dial value
    expect(shakeRisk(seconds: 1 / 64, eqFocal: 50), isFalse); // 1/60
    expect(
      shakeRisk(seconds: 1 / 64, eqFocal: equivalentFocal(50, FilmFormat.half)),
      isTrue, // ~72 mm
    );
    expect(shakeRisk(seconds: 1 / 32, eqFocal: 24), isFalse);
  });
}
