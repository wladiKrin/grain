import 'dart:async';

import 'package:flutter/services.dart';

import 'haptics.dart';

/// The optional click played with a dial detent. Calls never block and never
/// fail: the sound is a nicety beside the haptic.
abstract class ClickSound {
  /// Loads (on) or releases (off) the native sound.
  void setEnabled(bool on);

  /// [strong] for full stops, otherwise a quieter click.
  void click({required bool strong});
}

/// [ClickSound] over the `grain/click` channel (Android SoundPool).
class ClickChannel implements ClickSound {
  ClickChannel() : _channel = const MethodChannel('grain/click');

  final MethodChannel _channel;

  void _send(String method, Map<String, bool> args) {
    unawaited(
      _channel
          .invokeMethod<void>(method, args)
          .then<void>(
            (_) {},
            onError: (Object _) {
              // No plugin (tests, other platforms) or a native failure: silent.
            },
          ),
    );
  }

  @override
  void setEnabled(bool on) => _send('setEnabled', {'on': on});

  @override
  void click({required bool strong}) => _send('play', {'strong': strong});
}

/// Ticks the [inner] haptic first, then plays the click when enabled, so the
/// sound can never delay the haptic.
class ClickingHaptics implements Haptics {
  ClickingHaptics(this.inner, this.sound, {bool enabled = false})
    : _enabled = enabled {
    if (enabled) sound.setEnabled(true);
  }

  final Haptics inner;
  final ClickSound sound;
  bool _enabled;

  bool get enabled => _enabled;
  set enabled(bool v) {
    if (v == _enabled) return;
    _enabled = v;
    sound.setEnabled(v);
  }

  @override
  void tick({required bool strong}) {
    inner.tick(strong: strong);
    if (_enabled) sound.click(strong: strong);
  }
}
