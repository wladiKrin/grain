import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:grain/main.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const GrainApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
