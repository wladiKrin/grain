import 'package:material_ui/material_ui.dart';

import '../../ui/theme.dart';
import '../../gear/model.dart';
import '../model.dart';

enum BodyChangeChoice { continueRoll, finishAndStart, meterOnly }

/// Asked once another body is selected while a roll is active in a different
/// one. The roll can continue in [to] from frame [nextLabel] when that takes
/// the same film format; earlier frames keep their camera. Not
/// barrier-dismissible: the user decides.
Future<BodyChangeChoice?> showBodyChangeDialog(
  BuildContext context, {
  required Roll roll,
  required String nextLabel,
  Body? to,
}) => showDialog<BodyChangeChoice>(
  context: context,
  barrierDismissible: false,
  builder: (c) => AlertDialog(
    backgroundColor: c.grain.ground,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: c.grain.border),
    ),
    title: Text('Roll ${roll.number} is in the ${roll.bodyName}'),
    actionsOverflowDirection: VerticalDirection.down,
    actions: [
      if (to != null && to.format == roll.format)
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
          onPressed: () => Navigator.pop(c, BodyChangeChoice.continueRoll),
          child: Text(
            'Continue roll ${roll.number} in the ${to.displayName} '
            'from frame $nextLabel',
          ),
        ),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
        onPressed: () => Navigator.pop(c, BodyChangeChoice.meterOnly),
        child: const Text("Meter only (don't log)"),
      ),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
        onPressed: () => Navigator.pop(c, BodyChangeChoice.finishAndStart),
        child: Text('Finish roll ${roll.number} and start a new one'),
      ),
    ],
  ),
);
