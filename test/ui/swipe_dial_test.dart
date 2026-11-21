import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/scales.dart';
import 'package:grain/ui/dial/swipe_dial.dart';
import 'package:grain/ui/haptics.dart';

class FakeHaptics implements Haptics {
  final ticks = <bool>[];
  @override
  void tick({required bool strong}) => ticks.add(strong);
}

final values = List.generate(
  10,
  (i) => ScaleValue('v$i', i.toDouble(), i % 3 == 0),
);

class Host extends StatefulWidget {
  const Host({super.key, required this.start, required this.haptics});
  final int start;
  final Haptics haptics;
  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  late int index = widget.start;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 360,
        child: SwipeDial(
          values: values,
          index: index,
          haptics: widget.haptics,
          onChanged: (i) => setState(() => index = i),
        ),
      ),
    ),
  );
}

Future<void> pump(WidgetTester t, int start, FakeHaptics h) =>
    t.pumpWidget(Host(start: start, haptics: h));

int idxOf(WidgetTester t) => t.state<HostState>(find.byType(Host)).index;

Future<void> dragBy(WidgetTester t, double dx) async {
  final g = await t.startGesture(t.getCenter(find.byType(SwipeDial)));
  await g.moveBy(Offset(dx, 0));
  await t.pump();
  await g.up();
  await t.pump();
}

void main() {
  testWidgets('drag left 40px steps +1 with one tick', (t) async {
    final h = FakeHaptics();
    await pump(t, 3, h);
    await dragBy(t, -40);
    expect(idxOf(t), 4);
    expect(h.ticks, [values[4].isFullStop]);
  });

  testWidgets('drag left 120px steps +3, three ticks, strong on full stops', (
    t,
  ) async {
    final h = FakeHaptics();
    await pump(t, 2, h);
    await dragBy(t, -120);
    expect(idxOf(t), 5);
    expect(h.ticks, [
      values[3].isFullStop,
      values[4].isFullStop,
      values[5].isFullStop,
    ]);
    expect(h.ticks, [true, false, false]);
  });

  testWidgets('drag right steps backwards', (t) async {
    final h = FakeHaptics();
    await pump(t, 5, h);
    await dragBy(t, 80);
    expect(idxOf(t), 3);
    expect(h.ticks.length, 2);
  });

  testWidgets('drag past the end clamps and stops ticking', (t) async {
    final h = FakeHaptics();
    await pump(t, 8, h);
    await dragBy(t, -400);
    expect(idxOf(t), 9);
    expect(h.ticks.length, 1);
  });

  testWidgets('drag past the start clamps and stops ticking', (t) async {
    final h = FakeHaptics();
    await pump(t, 1, h);
    await dragBy(t, 400);
    expect(idxOf(t), 0);
    expect(h.ticks.length, 1);
  });

  testWidgets('tap next label steps +1; tap previous steps -1', (t) async {
    final h = FakeHaptics();
    await pump(t, 4, h);
    await t.tap(find.text('v5'));
    await t.pump();
    expect(idxOf(t), 5);
    await t.tap(find.text('v4'));
    await t.pump();
    expect(idxOf(t), 4);
  });

  testWidgets('neighbour tap targets are at least 44px', (t) async {
    await pump(t, 4, FakeHaptics());
    final next = t.getSize(
      find
          .ancestor(of: find.text('v5'), matching: find.byType(GestureDetector))
          .first,
    );
    expect(next.width, greaterThanOrEqualTo(44));
    expect(next.height, greaterThanOrEqualTo(44));
  });

  testWidgets('no neighbour rendered beyond the ends', (t) async {
    await pump(t, 0, FakeHaptics());
    expect(find.text('v1'), findsOneWidget);
    expect(find.text('v0'), findsOneWidget);
    expect(find.text('v9'), findsNothing);
  });

  testWidgets('drag of 19px does not change value', (t) async {
    final h = FakeHaptics();
    await pump(t, 3, h);
    await dragBy(t, -19);
    expect(idxOf(t), 3);
    expect(h.ticks, isEmpty);
  });

  testWidgets('semantics increase/decrease step the value', (t) async {
    final h = FakeHaptics();
    final handle = t.ensureSemantics();
    await pump(t, 3, h);
    expect(find.semantics.byValue('v3'), findsOneWidget);
    t.semantics.increase(find.semantics.byValue('v3'));
    await t.pump();
    expect(idxOf(t), 4);
    handle.dispose();
  });
}
