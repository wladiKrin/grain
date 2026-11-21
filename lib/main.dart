import 'package:material_ui/material_ui.dart';

import 'metering/debug_meter_screen.dart';

void main() => runApp(const GrainApp());

class GrainApp extends StatelessWidget {
  const GrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grain',
      theme: ThemeData(fontFamily: 'InterTight'),
      // Temporary: Camera2 bridge bring-up screen, replaced in Task 8.
      home: const DebugMeterScreen(),
    );
  }
}
