import 'dart:math' as math;
import 'dart:ui';

import 'package:grain/gear/model.dart';

const focalStops = [
  12, 14, 16, 18, 20, 21, 24, 28, 35, 40, 45, 50, 55, 58, 60, 70, 85, 90, //
  100, 105, 120, 135, 150, 180, 200, 250, 300, 400, 500, 600,
];

/// Size in [preview] px of a frame of [aspect] (width / height) whose
/// diagonal is `phoneEqFocal / lensFocal` of the preview diagonal.
Size _frame(
  Size preview,
  double lensFocal,
  double phoneEqFocal,
  double aspect,
) {
  final fraction = phoneEqFocal / lensFocal;
  final diag = preview.width * preview.width + preview.height * preview.height;
  final w =
      fraction * math.sqrt(diag) * aspect / math.sqrt(aspect * aspect + 1);
  return Size(w, w / aspect);
}

/// Whether the whole field of [lensFocal], framed at [aspect], is inside the
/// [preview] of a camera that frames like [phoneEqFocal].
bool lensFits({
  required Size preview,
  required double lensFocal,
  required double phoneEqFocal,
  double aspect = 2 / 3,
}) {
  final f = _frame(preview, lensFocal, phoneEqFocal, aspect);
  const slack = 1 + 1e-9;
  return f.width <= preview.width * slack && f.height <= preview.height * slack;
}

/// Normalized, centred rect of [aspect] (width / height) in the [preview]
/// whose diagonal is `phoneEqFocal / lensFocal` of the preview diagonal. If
/// it does not fit ([lensFits] is false), the largest such rect that does.
Rect lensCrop({
  required Size preview,
  required double lensFocal,
  required double phoneEqFocal,
  double aspect = 2 / 3,
}) {
  final f = _frame(preview, lensFocal, phoneEqFocal, aspect);
  var w = f.width, h = f.height;
  final fit = math.min(1.0, math.min(preview.width / w, preview.height / h));
  w *= fit;
  h *= fit;
  final nw = w / preview.width, nh = h / preview.height;
  return Rect.fromLTWH((1 - nw) / 2, (1 - nh) / 2, nw, nh);
}

/// Focal length on 135 film that frames like [focal] on [format].
double equivalentFocal(double focal, FilmFormat format) =>
    focal * 43.27 / format.diagonalMm;
