import 'package:grain/gear/model.dart';
import 'package:grain/rolls/model.dart';

final t0 = DateTime.utc(2026, 1, 1);

Roll roll({
  String filmStock = 'Ilford HP5 Plus',
  int boxIso = 400,
  int pushThirds = 0,
  int number = 1,
  int size = 36,
  StartFrame startFrame = StartFrame.one,
  String? bodyId = 'b1',
}) => Roll(
  id: 'r',
  number: number,
  filmStock: filmStock,
  filmType: FilmType.bwNeg,
  boxIso: boxIso,
  pushThirds: pushThirds,
  bodyId: bodyId,
  bodyMake: 'Canon',
  bodyModel: 'A-1',
  format: FilmFormat.f135,
  size: size,
  startFrame: startFrame,
  status: RollStatus.active,
  startedAt: t0,
  updatedAt: t0,
);

List<Frame> frames(List<int> numbers) => [
  for (var i = 0; i < numbers.length; i++)
    Frame(
      id: 'f$i',
      rollId: 'r',
      position: i,
      number: numbers[i],
      updatedAt: t0,
    ),
];
