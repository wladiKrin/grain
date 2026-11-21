import 'package:material_ui/material_ui.dart';

import 'meter/meter_controller.dart';
import 'meter/meter_screen.dart';
import 'metering/meter_channel.dart';
import 'ui/haptics.dart';
import 'ui/theme.dart';

void main() => runApp(GrainApp());

class GrainApp extends StatefulWidget {
  GrainApp({super.key, MeterSource? source, Haptics? haptics})
    : source = source ?? MeterChannel(),
      haptics = haptics ?? SystemHaptics();

  final MeterSource source;
  final Haptics haptics;

  @override
  State<GrainApp> createState() => _GrainAppState();
}

class _GrainAppState extends State<GrainApp> {
  late final MeterController _controller = MeterController(
    source: widget.source,
  );
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Camera is held only while the app is in the foreground.
    _lifecycle = AppLifecycleListener(
      onResume: _controller.resume,
      onInactive: _controller.pause,
      onHide: _controller.pause,
      onPause: _controller.pause,
    );
    _controller.resume();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grain',
      theme: grainTheme(),
      home: MeterScreen(controller: _controller, haptics: widget.haptics),
    );
  }
}
