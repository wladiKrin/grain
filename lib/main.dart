import 'package:material_ui/material_ui.dart';

void main() => runApp(const GrainApp());

class GrainApp extends StatelessWidget {
  const GrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grain',
      theme: ThemeData(fontFamily: 'InterTight'),
      home: const Scaffold(),
    );
  }
}
