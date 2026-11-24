import 'package:material_ui/material_ui.dart';

import '../../ui/theme.dart';
import '../../gear/model.dart';
import '../model.dart';

enum BodyChangeChoice { moveRoll, finishAndStart, meterOnly }

/// Asked once another body is selected while a roll is active in a different
/// one. The roll can move to [to] when that takes the same film format. Not
/// barrier-dismissible: the user decides.
Future<BodyChangeChoice?> showBodyChangeDialog(
  BuildContext context, {
  required Roll roll,
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
          onPressed: () => Navigator.pop(c, BodyChangeChoice.moveRoll),
          child: Text('Move roll ${roll.number} to the ${to.displayName}'),
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
