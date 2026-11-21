import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/ui/roll_editor.dart';
import 'package:grain/ui/haptics.dart';
import 'package:grain/ui/dial/swipe_dial.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/gear_fixtures.dart';
import '../../support/rolls_fixtures.dart';

class _Haptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

void main() {
  late RollController rolls;
  final a1 = libBody('canon-a1');
  final p67 = libBody('pentax-67');

  setUp(() => rolls = inMemoryRolls());
  tearDown(() => rolls.dispose());

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump();
  }

  Future<void> pumpEditor(WidgetTester t, {Body? body, Roll? initial}) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(),
        home: RollEditorScreen(
          rolls: rolls,
          haptics: _Haptics(),
          body: body,
          initial: initial,
        ),
      ),
    );
  }

  Future<void> save(WidgetTester t) async {
    await t.tap(find.text('Save'));
    await settle(t);
  }

  Future<void> typeFilm(WidgetTester t, String s) async {
    await t.enterText(find.byType(TextField).first, s);
    await t.pump();
  }

  Future<void> drag(WidgetTester t, double dx) async {
    final dial = find.byType(SwipeDial).first;
    await t.ensureVisible(dial);
    await t.drag(dial, Offset(dx, 0));
    await t.pump();
  }

  Future<void> dragDial(WidgetTester t, int index, double dx) async {
    final dial = find.byType(SwipeDial).at(index);
    await t.ensureVisible(dial);
    await t.drag(dial, Offset(dx, 0));
    await t.pump();
  }

  SegmentedButton<FilmType> typeButton(WidgetTester t) =>
      t.widget(find.byType(SegmentedButton<FilmType>));

  Future<void> startHp5(WidgetTester t) async {
    await t.runAsync(
      () => rolls.startRoll(
        filmStock: 'Ilford HP5 Plus',
        filmType: FilmType.bwNeg,
        boxIso: 400,
        pushThirds: 3,
        body: a1,
        size: 36,
        startFrame: StartFrame.one,
      ),
    );
  }

  testWidgets('new roll: HP5 suggestion fills type and box speed', (t) async {
    await pumpEditor(t, body: a1);
    expect(typeButton(t).selected, {FilmType.colorNeg});
    await typeFilm(t, 'hp5');
    await t.tap(find.text('Ilford HP5 Plus'));
    await t.pump();
    expect(typeButton(t).selected, {FilmType.bwNeg});
    expect(
      find.descendant(
        of: find.byType(DropdownButton<int>),
        matching: find.text('400'),
      ),
      findsOneWidget,
    );
    expect(find.text('Canon A-1'), findsOneWidget);
  });

  testWidgets('push +1 shows exposed ISO 800 and saves pushThirds 3', (
    t,
  ) async {
    await pumpEditor(t, body: a1);
    await typeFilm(t, 'hp5');
    await t.tap(find.text('Ilford HP5 Plus'));
    await t.pump();
    expect(find.text('Exposed at ISO 400'), findsOneWidget);
    await drag(t, -120);
    expect(find.text('Exposed at ISO 800'), findsOneWidget);
    await save(t);
    final r = rolls.active!;
    expect(r.pushThirds, 3);
    expect(r.exposedIso, 800);
    expect(r.status, RollStatus.active);
    expect(r.number, 1);
    expect(r.bodyId, 'canon-a1');
    expect(r.filmStock, 'Ilford HP5 Plus');
  });

  testWidgets('frames default from the body', (t) async {
    await pumpEditor(t, body: p67);
    ChoiceChip chip(String l) => t.widget(find.widgetWithText(ChoiceChip, l));
    expect(chip('Custom').selected, isTrue);
    expect(find.widgetWithText(TextField, '10'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await pumpEditor(t, body: a1);
    expect(chip('36').selected, isTrue);
    expect(chip('Custom').selected, isFalse);
  });

  testWidgets('first frame 00 is stored', (t) async {
    await pumpEditor(t, body: a1);
    await typeFilm(t, 'Mystery 400');
    final seg = find.byType(SegmentedButton<StartFrame>);
    await t.ensureVisible(seg);
    await t.tap(find.descendant(of: seg, matching: find.text('00')));
    await t.pump();
    await save(t);
    expect(rolls.active!.startFrame, StartFrame.doubleZero);
    expect(rolls.active!.filmStock, 'Mystery 400');
  });

  testWidgets('defaults copy the last roll but not its push', (t) async {
    await startHp5(t);
    await pumpEditor(t, body: a1);
    expect(find.widgetWithText(TextField, 'Ilford HP5 Plus'), findsOneWidget);
    expect(find.text('Exposed at ISO 400'), findsOneWidget);
    expect(typeButton(t).selected, {FilmType.bwNeg});
    expect(find.text('Saving finishes Roll 1.'), findsOneWidget);
  });

  testWidgets('refuses empty film and out-of-range push', (t) async {
    await pumpEditor(t, body: a1);
    await save(t);
    expect(find.text('Film: enter a film stock.'), findsOneWidget);
    expect(rolls.rolls, isEmpty);

    await typeFilm(t, 'delta 3200');
    await t.tap(find.text('Ilford Delta 3200'));
    await t.pump();
    await drag(t, -360); // +3 stops: 25600
    expect(find.text('Out of range (ISO 6–12800)'), findsOneWidget);
    await save(t);
    expect(find.textContaining('out of range'), findsOneWidget);
    expect(rolls.rolls, isEmpty);

    await drag(t, 360);
    await t.pump();
    expect(find.text('Out of range (ISO 6–12800)'), findsNothing);
  });

  testWidgets('refuses an invalid custom size', (t) async {
    await pumpEditor(t, body: p67);
    await typeFilm(t, 'Mystery 400');
    final field = find.byType(TextField).at(1);
    await t.ensureVisible(field);
    await t.enterText(field, '201');
    await save(t);
    expect(find.textContaining('1 to 200'), findsOneWidget);
    expect(rolls.rolls, isEmpty);
    await t.enterText(field, '200');
    await save(t);
    expect(rolls.active!.size, 200);
  });

  testWidgets('editing keeps number and body', (t) async {
    await startHp5(t);
    final r = rolls.active!;
    await t.runAsync(
      () => rolls.startRoll(
        filmStock: 'Kodak Portra 400',
        filmType: FilmType.colorNeg,
        boxIso: 400,
        pushThirds: 0,
        body: p67,
        size: 10,
        startFrame: StartFrame.one,
      ),
    );
    await pumpEditor(t, initial: r);
    expect(find.text('Saving finishes Roll 2.'), findsNothing);
    expect(find.text('Canon A-1'), findsOneWidget);
    await typeFilm(t, 'Ilford FP4 Plus');
    await drag(t, 120);
    await t.pump();
    await save(t);
    final u = rolls.rolls.firstWhere((x) => x.id == r.id);
    expect(u.filmStock, 'Ilford FP4 Plus');
    expect(u.pushThirds, 0);
    expect(u.number, 1);
    expect(u.bodyId, 'canon-a1');
    expect(u.status, RollStatus.finished);
    expect(rolls.active!.number, 2);
  });

  testWidgets('latitude follows the film type until a dial is moved', (
    t,
  ) async {
    await pumpEditor(t, body: a1);
    await t.tap(find.text('Slide'));
    await t.pump();
    final under = find.byType(SwipeDial).at(1);
    final over = find.byType(SwipeDial).at(2);
    await t.ensureVisible(under);
    expect(find.descendant(of: under, matching: find.text('−½')), findsWidgets);
    expect(find.descendant(of: over, matching: find.text('+½')), findsWidgets);
    expect(find.text('Default for Slide: −½ to +½'), findsOneWidget);
    await t.ensureVisible(find.text('Colour negative'));
    await t.tap(find.text('Colour negative'));
    await t.pump();
    await t.ensureVisible(under);
    expect(find.descendant(of: under, matching: find.text('−2')), findsWidgets);
    expect(find.descendant(of: over, matching: find.text('+3')), findsWidgets);
    await dragDial(t, 2, -40); // one detent right: +3½
    expect(find.descendant(of: over, matching: find.text('+3½')), findsWidgets);
    expect(find.text('Use film default'), findsOneWidget);
    await typeFilm(t, 'Mystery 400');
    await save(t);
    final r = rolls.active!;
    expect(r.latitudeOverHalves, 7);
    expect(r.latitudeUnderHalves, isNull);
  });

  testWidgets('an untouched latitude dial follows a film-type change', (
    t,
  ) async {
    await pumpEditor(t, body: a1);
    final under = find.byType(SwipeDial).at(1);
    final over = find.byType(SwipeDial).at(2);
    await t.ensureVisible(under);
    expect(find.descendant(of: under, matching: find.text('−2')), findsWidgets);
    await dragDial(t, 1, -40); // Under one detent right: −1½
    expect(find.descendant(of: under, matching: find.text('−1½')), findsWidgets);
    await t.ensureVisible(find.text('Slide'));
    await t.tap(find.text('Slide'));
    await t.pump();
    await t.ensureVisible(under);
    expect(find.descendant(of: under, matching: find.text('−1½')), findsWidgets);
    expect(find.descendant(of: over, matching: find.text('+½')), findsWidgets);
    await typeFilm(t, 'Mystery 100');
    await save(t);
    final r = rolls.active!;
    expect(r.latitudeUnderHalves, -3);
    expect(r.latitudeOverHalves, isNull);
  });

  testWidgets('Use film default clears both overrides', (t) async {
    final r = (await t.runAsync(
      () => rolls.startRoll(
        filmStock: 'Ilford HP5 Plus',
        filmType: FilmType.bwNeg,
        boxIso: 400,
        pushThirds: 0,
        body: a1,
        size: 36,
        startFrame: StartFrame.one,
        latitudeUnderHalves: -4,
        latitudeOverHalves: 5,
      ),
    ))!;
    await pumpEditor(t, initial: r);
    final b = find.text('Use film default');
    await t.ensureVisible(b);
    await t.tap(b);
    await t.pump();
    expect(find.text('Use film default'), findsNothing);
    await save(t);
    final u = rolls.rolls.firstWhere((x) => x.id == r.id);
    expect(u.latitudeUnderHalves, isNull);
    expect(u.latitudeOverHalves, isNull);
  });
}
