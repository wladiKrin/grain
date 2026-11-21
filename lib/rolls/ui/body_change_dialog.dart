import 'package:material_ui/material_ui.dart';

import '../../ui/theme.dart';
import '../model.dart';

enum BodyChangeChoice { finishAndStart, meterOnly }

/// Asked once the library closes with another body selected while a roll is
/// active in a different one. Not barrier-dismissible: the user decides.
Future<BodyChangeChoice?> showBodyChangeDialog(
  BuildContext context, {
  required Roll roll,
}) => showDialog<BodyChangeChoice>(
  context: context,
  barrierDismissible: false,
  builder: (c) => AlertDialog(
    backgroundColor: GrainColors.ground,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: GrainColors.border),
    ),
    title: Text('Roll ${roll.number} is in the ${roll.bodyName}'),
    actionsOverflowDirection: VerticalDirection.down,
    actions: [
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
