import 'package:flutter_test/flutter_test.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/numbering.dart';

import 'support.dart';

void main() {
  test('first number per start frame', () {
    expect(
      frameLabel(nextNumber(roll(startFrame: StartFrame.doubleZero), [])),
      '00',
    );
    expect(frameLabel(nextNumber(roll(startFrame: StartFrame.zero), [])), '0');
    expect(frameLabel(nextNumber(roll(startFrame: StartFrame.one), [])), '1');
  });

  test('00 start on a 36 roll overruns to 37 and 38', () {
    final r = roll(startFrame: StartFrame.doubleZero, size: 36);
    final fs = frames([for (var n = -1; n <= 36; n++) n]);
    expect(fs.first.label, '00');
    expect(fs.last.label, '36');
    expect(nextNumber(r, fs), 37);
    expect(overrun(r, 37), 1);
    expect(overrun(r, 38), 2);
    expect(overrun(r, 36), 0);
    expect(overrun(r, -1), 0);
  });

  test('insert blank shifts the rest up', () {
    final out = insertBlankAt(
      frames([1, 2, 3, 4]),
      2,
      id: 'b',
      rollId: 'r',
      now: t0,
    );
    expect(out.map((f) => f.number), [1, 2, 3, 4, 5]);
    expect(out.map((f) => f.position), [0, 1, 2, 3, 4]);
    expect(out[2].id, 'b');
    expect(out[2].exposure.isBlank, isTrue);
    expect(out[3].id, 'f2');
    expect(
      insertBlankAt(
        frames([1, 2]),
        2,
        id: 'b',
        rollId: 'r',
        now: t0,
      ).last.number,
      3,
    );
  });

  test('insert on an empty list uses the given rollId', () {
    final out = insertBlankAt([], 0, id: 'b', rollId: 'rr', now: t0);
    expect(out.single.rollId, 'rr');
    expect(out.single.position, 0);
  });

  test('only changed frames get updatedAt', () {
    final t1 = DateTime.utc(2026, 2, 1);
    final out = deleteAt(frames([1, 2, 3, 4]), 1, now: t1);
    expect(out.map((f) => f.updatedAt), [t0, t1, t1]);
  });

  test('delete shifts the rest down', () {
    final out = deleteAt(frames([1, 2, 3, 4]), 1, now: t0);
    expect(out.map((f) => f.id), ['f0', 'f2', 'f3']);
    expect(out.map((f) => f.number), [1, 2, 3]);
    expect(out.map((f) => f.position), [0, 1, 2]);
  });

  test('renumber from a frame keeps order', () {
    final out = renumberFrom(frames([-1, 0, 1, 2, 3]), 2, 5, now: t0);
    expect(out.map((f) => f.label), ['00', '0', '5', '6', '7']);
    expect(
      renumberFrom(frames([5, 6, 7]), 0, -1, now: t0).map((f) => f.label),
      ['00', '0', '1'],
    );
    expect(out.map((f) => f.id), ['f0', 'f1', 'f2', 'f3', 'f4']);
  });

  test('parseFrameLabel', () {
    expect(parseFrameLabel('00'), -1);
    expect(parseFrameLabel('0'), 0);
    expect(parseFrameLabel('37'), 37);
    expect(parseFrameLabel('999'), 999);
    for (final s in ['', '-1', '000', 'a', '1.5', '01', '1000']) {
      expect(parseFrameLabel(s), isNull, reason: s);
    }
  });
}
