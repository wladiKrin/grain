import 'package:flutter_test/flutter_test.dart';

import 'fake_source.dart';

void main() {
  test('setZoom switches to the ultra-wide and back', () async {
    final src = FakeMeterSource(mainEqFocal: 25, wideEqFocal: 13);
    final main = await src.start();
    expect(main.wide, isFalse);
    expect(main.phoneEqFocal, 25);
    expect(main.wideEqFocal, 13);

    final wide = await src.setZoom(0.52);
    expect(wide.wide, isTrue);
    expect(wide.phoneEqFocal, 13);
    expect(wide.mainEqFocal, 25);

    final back = await src.setZoom(1.00);
    expect(back.wide, isFalse);
    expect(back.phoneEqFocal, 25);
    expect(src.calls, ['start', 'setZoom(0.52)', 'setZoom(1.00)']);
  });

  test('setZoom without an ultra-wide answers the main camera', () async {
    final src = FakeMeterSource();
    final info = await src.setZoom(0.52);
    expect(info.wide, isFalse);
    expect(info.wideEqFocal, isNull);
    expect(info.phoneEqFocal, 25);
  });

  test('startScan is recorded and QR texts reach listeners', () async {
    final src = FakeMeterSource();
    await src.startScan();
    final first = src.qrCodes.first;
    src.emitQr('abc');
    expect(await first, 'abc');
    expect(src.calls, ['startScan']);
  });
}
