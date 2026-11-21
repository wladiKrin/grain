import 'dart:math' as math;

/// One marking on an exposure scale.
class ScaleValue {
  const ScaleValue(this.label, this.value, this.isFullStop);

  /// Nominal marking, e.g. `1.4`, `1/125`, `0.3"`.
  final String label;

  /// Exact value (f-number, seconds or ISO), e.g. √2 for f/1.4.
  final double value;

  final bool isFullStop;

  @override
  String toString() => 'ScaleValue($label, $value, $isFullStop)';
}

enum StepSize { full, half, third }

const _apertureThirds = [
  '1', '1.1', '1.2', '1.4', '1.6', '1.8', '2', '2.2', '2.5', '2.8', '3.2',
  '3.5', '4', '4.5', '5', '5.6', '6.3', '7.1', '8', '9', '10', '11', '13',
  '14', '16', '18', '20', '22', '25', '29', '32', '36', '40', '45', '51',
  '57', '64',
];
const _apertureHalves = [
  '1', '1.2', '1.4', '1.7', '2', '2.4', '2.8', '3.3', '4', '4.8', '5.6',
  '6.7', '8', '9.5', '11', '13', '16', '19', '22', '27', '32', '38', '45',
  '54', '64',
];
const _shutterThirds = [
  '1/8000', '1/6400', '1/5000', '1/4000', '1/3200', '1/2500', '1/2000',
  '1/1600', '1/1250', '1/1000', '1/800', '1/640', '1/500', '1/400', '1/320',
  '1/250', '1/200', '1/160', '1/125', '1/100', '1/80', '1/60', '1/50',
  '1/40', '1/30', '1/25', '1/20', '1/15', '1/13', '1/10', '1/8', '1/6',
  '1/5', '1/4', '0.3"', '0.4"', '1/2', '0.6"', '0.8"', '1"', '1.3"', '1.6"',
  '2"', '2.5"', '3.2"', '4"', '5"', '6"', '8"', '10"', '13"', '15"', '20"',
  '25"', '30"',
];
const _shutterHalves = [
  '1/8000', '1/6000', '1/4000', '1/3000', '1/2000', '1/1500', '1/1000',
  '1/750', '1/500', '1/350', '1/250', '1/180', '1/125', '1/90', '1/60',
  '1/45', '1/30', '1/20', '1/15', '1/10', '1/8', '1/6', '1/4', '0.3"',
  '1/2', '0.7"', '1"', '1.5"', '2"', '3"', '4"', '6"', '8"', '12"', '15"',
  '20"', '30"',
];
const _isoThirds = [
  '6', '8', '10', '12', '16', '20', '25', '32', '40', '50', '64', '80',
  '100', '125', '160', '200', '250', '320', '400', '500', '640', '800',
  '1000', '1250', '1600', '2000', '2500', '3200', '4000', '5000', '6400',
  '8000', '10000', '12800',
];

/// Limits closer than this (in stops) to a grid value are treated as that
/// grid value (e.g. a nominal f/1.8 against the exact 1.78 on the grid).
const _limitTolerance = 0.05;

double _log2(double x) => math.log(x) / math.ln2;

/// Numeric value of a nominal label: `1.8`, `1/125`, `0.3"`, `30"`.
double _nominal(String label) {
  if (label.startsWith('1/')) return 1 / double.parse(label.substring(2));
  return double.parse(label.replaceAll('"', ''));
}

/// Whether [v] is the grid value that a limit of [limit] designates, either
/// by exact value (within tolerance) or by its nominal marking (30" is the
/// grid's 32 s).
bool _isLimit(ScaleValue v, double limit) =>
    _log2(v.value / limit).abs() <= _limitTolerance ||
    _nominal(v.label) == limit;

/// Builds a scale from a label table of third (or half) steps.
///
/// [exactThird]/[exactHalf] map a grid index k to the exact value; [kOffset]
/// is the grid index of table entry 0 (ISO 6 is k = -12 from ISO 100).
List<ScaleValue> _build({
  required List<String> thirds,
  required List<String> halves,
  required StepSize step,
  required double Function(int k) exactThird,
  required double Function(int k) exactHalf,
  required double min,
  required double max,
  required String Function(double) formatLimit,
  int kOffset = 0,
}) {
  final labels = step == StepSize.half ? halves : thirds;
  final stride = step == StepSize.full ? 3 : 1;
  final exact = step == StepSize.half ? exactHalf : exactThird;
  final fullEvery = step == StepSize.half ? 2 : 3;

  final grid = <ScaleValue>[];
  for (var i = 0; i < labels.length; i += stride) {
    final k = i + kOffset;
    grid.add(ScaleValue(labels[i], exact(k), (i + kOffset) % fullEvery == 0));
  }

  final result = <ScaleValue>[];
  for (final v in grid) {
    if ((v.value > min || _isLimit(v, min)) &&
        (v.value < max || _isLimit(v, max))) {
      result.add(v);
    }
  }

  if (result.isEmpty || !_isLimit(result.first, min)) {
    result.insert(0, ScaleValue(formatLimit(min), min, false));
  }
  if (!_isLimit(result.last, max)) {
    result.add(ScaleValue(formatLimit(max), max, false));
  }
  return result;
}

String _plain(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

String _shutterLimit(double v) =>
    v < 1 ? '1/${(1 / v).round()}' : '${_plain(v)}"';

List<ScaleValue> apertureScale({
  required StepSize step,
  double min = 1,
  double max = 64,
}) =>
    _build(
      thirds: _apertureThirds,
      halves: _apertureHalves,
      step: step,
      exactThird: (k) => math.pow(2, k / 6).toDouble(),
      exactHalf: (k) => math.pow(2, k / 4).toDouble(),
      min: min,
      max: max,
      formatLimit: _plain,
    );

/// Ordered fastest → slowest.
List<ScaleValue> shutterScale({
  required StepSize step,
  double fastest = 1 / 8000,
  double slowest = 30,
}) =>
    _build(
      thirds: _shutterThirds,
      halves: _shutterHalves,
      step: step,
      exactThird: (k) => math.pow(2, k / 3) / 8192,
      exactHalf: (k) => math.pow(2, k / 2) / 8192,
      min: fastest,
      max: slowest,
      formatLimit: _shutterLimit,
    );

/// Only thirds and full stops are supported for ISO; [StepSize.half] throws
/// [ArgumentError].
List<ScaleValue> isoScale({
  StepSize step = StepSize.third,
  int min = 6,
  int max = 12800,
}) {
  if (step == StepSize.half) {
    throw ArgumentError.value(step, 'step', 'ISO supports only full and third');
  }
  return _build(
    thirds: _isoThirds,
    halves: const [],
    step: step,
    // Table index 0 is ISO 6 = 100 * 2^(-12/3).
    kOffset: -12,
    exactThird: (k) => 100 * math.pow(2, k / 3).toDouble(),
    exactHalf: (k) => throw UnimplementedError(),
    min: min.toDouble(),
    max: max.toDouble(),
    formatLimit: _plain,
  );
}

/// Index of the scale value nearest to [value] by `|log2(a/b)|`.
int nearestIndex(List<ScaleValue> scale, double value) {
  var best = 0;
  var bestDist = double.infinity;
  for (var i = 0; i < scale.length; i++) {
    final d = _log2(scale[i].value / value).abs();
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best;
}
