import 'dart:math' as math;

import 'model.dart';

/// `-1` is shown as `00`.
String frameLabel(int number) => number == -1 ? '00' : '$number';

/// `00` → −1, `0`…`999` → int (no leading zeros, no sign), else null.
int? parseFrameLabel(String s) {
  if (s == '00') return -1;
  if (!RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(s)) return null;
  return int.parse(s);
}

int nextNumber(Roll roll, List<Frame> frames) =>
    frames.isEmpty ? roll.startFrame.number : frames.last.number + 1;

/// Frames beyond the nominal roll size.
int overrun(Roll roll, int number) => math.max(0, number - roll.size);

/// Inserts a blank at [position]; it takes the number of the frame now at
/// [position] (or the next number at the end), later frames move up by one.
/// It takes the camera of the frame before it, or [camera] at the start.
List<Frame> insertBlankAt(
  List<Frame> frames,
  int position, {
  required String id,
  required String rollId,
  required DateTime now,
  RollCamera camera = const RollCamera(null, '', ''),
}) {
  final number = position < frames.length
      ? frames[position].number
      : (frames.isEmpty ? 1 : frames.last.number + 1);
  final c = position > 0 ? frames[position - 1].camera : camera;
  return [
    ...frames.sublist(0, position),
    Frame(
      id: id,
      rollId: rollId,
      position: position,
      number: number,
      bodyId: c.id,
      bodyMake: c.make,
      bodyModel: c.model,
      updatedAt: now,
    ),
    for (final f in frames.sublist(position))
      f.copyWith(
        position: f.position + 1,
        number: f.number + 1,
        updatedAt: now,
      ),
  ];
}

List<Frame> deleteAt(
  List<Frame> frames,
  int position, {
  required DateTime now,
}) => [
  ...frames.sublist(0, position),
  for (final f in frames.sublist(position + 1))
    f.copyWith(position: f.position - 1, number: f.number - 1, updatedAt: now),
];

/// `frames[position]` gets [number]; each later frame previous + 1.
List<Frame> renumberFrom(
  List<Frame> frames,
  int position,
  int number, {
  required DateTime now,
}) => [
  ...frames.sublist(0, position),
  for (var i = position; i < frames.length; i++)
    frames[i].copyWith(number: number + i - position, updatedAt: now),
];
