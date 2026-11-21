import 'package:grain/ui/click_sound.dart';
import 'package:grain/ui/haptics.dart';

/// Records `'setEnabled true'`, `'click strong'` and `'click light'` into
/// [log], which may be shared with a [LogHaptics] to check ordering.
class FakeClickSound implements ClickSound {
  FakeClickSound([List<String>? log]) : log = log ?? [];

  final List<String> log;

  @override
  void setEnabled(bool on) => log.add('setEnabled $on');

  @override
  void click({required bool strong}) =>
      log.add(strong ? 'click strong' : 'click light');
}

/// Records `'tick strong'` and `'tick light'`.
class LogHaptics implements Haptics {
  LogHaptics([List<String>? log]) : log = log ?? [];

  final List<String> log;

  @override
  void tick({required bool strong}) =>
      log.add(strong ? 'tick strong' : 'tick light');
}
