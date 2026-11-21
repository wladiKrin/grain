import 'dart:math' as math;
import 'dart:ui';

import 'package:grain/gear/model.dart';

const focalStops = [
  12, 14, 16, 18, 20, 21, 24, 28, 35, 40, 45, 50, 55, 58, 60, 70, 85, 90, //
  100, 105, 120, 135, 150, 180, 200, 250, 300, 400, 500, 600,
];

/// Whether [lensFocal] sees a wider field than the phone's main camera.
bool widerThanPhone(double lensFocal, double phoneEqFocal) =>
    lensFocal < phoneEqFocal;

/// Normalized, centred rect of [aspect] (width / height) in the [preview]
/// whose diagonal is `phoneEqFocal / lensFocal` of the preview diagonal. If
/// that fraction is at least 1, the largest such rect that fits.
Rect lensCrop({
  required Size preview,
  required double lensFocal,
  required double phoneEqFocal,
  double aspect = 2 / 3,
}) {
  final fraction = phoneEqFocal / lensFocal;
  final diag = preview.width * preview.width + preview.height * preview.height;
  var w = fraction * math.sqrt(diag) * aspect / math.sqrt(aspect * aspect + 1);
  var h = w / aspect;
  final fit = math.min(1.0, math.min(preview.width / w, preview.height / h));
  w *= fit;
  h *= fit;
  final nw = w / preview.width, nh = h / preview.height;
  return Rect.fromLTWH((1 - nw) / 2, (1 - nh) / 2, nw, nh);
}

/// Focal length on 135 film that frames like [focal] on [format].
double equivalentFocal(double focal, FilmFormat format) =>
    focal * 43.27 / format.diagonalMm;
