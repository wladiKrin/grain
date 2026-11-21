import 'package:material_ui/material_ui.dart';

import '../../meter/meter_controller.dart';
import '../../metering/meter_channel.dart';
import '../codec.dart';
import '../gear_controller.dart';
import '../model.dart';
import '../platform.dart';
import 'scan_screen.dart';

String _importQuestion(GearDoc doc) => switch (doc) {
  Body() => 'Import ${doc.displayName}?',
  Lens() => 'Import ${doc.displayName}?',
  Kit() =>
    'Import ${doc.body.displayName} and '
        '${doc.lenses.length == 1 ? '1 lens' : '${doc.lenses.length} lenses'}?',
};

/// Tells the user that a text is not a usable profile; [error] is the first
/// parser message.
Future<void> showNotGrainProfile(BuildContext context, String error) =>
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Not a Grain profile'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    );

/// Asks, then imports [doc] and says so. Null when cancelled.
Future<ImportResult?> confirmImport(
  BuildContext context,
  GearController gear,
  GearDoc doc,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(_importQuestion(doc)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Import'),
        ),
      ],
    ),
  );
  if (ok != true) return null;
  final result = await gear.importDoc(doc);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Imported ${result.summary}')));
  }
  return result;
}

/// Picks a file, parses it and confirms the import. A file that is not a
/// profile (or too large) is explained and nothing is stored.
Future<ImportResult?> importFromFile(
  BuildContext context, {
  required GearController gear,
  required GearPlatform platform,
}) async {
  final GearDoc doc;
  try {
    final text = await platform.pickTextFile();
    if (text == null) return null;
    doc = parseGearString(text);
  } on GearFormatException catch (e) {
    if (context.mounted) await showNotGrainProfile(context, e.errors.first);
    return null;
  }
  if (!context.mounted) return null;
  return confirmImport(context, gear, doc);
}

/// Scans a QR code with the meter's camera lent out, then confirms the import.
Future<ImportResult?> importFromScan(
  BuildContext context, {
  required GearController gear,
  required MeterController meter,
  required MeterSource source,
}) async {
  final navigator = Navigator.of(context);
  final doc = await meter.lendCamera(
    () => navigator.push<GearDoc>(
      MaterialPageRoute(builder: (_) => ScanScreen(source: source)),
    ),
  );
  if (doc == null || !context.mounted) return null;
  return confirmImport(context, gear, doc);
}

/// The import entry of the pickers: from a file or by scanning a QR code.
Future<void> showImportSheet(
  BuildContext context, {
  required GearController gear,
  required GearPlatform platform,
  required MeterController meter,
  required MeterSource source,
}) async {
  final choice = await showModalBottomSheet<bool>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('From file'),
            onTap: () => Navigator.pop(c, true),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('Scan QR code'),
            onTap: () => Navigator.pop(c, false),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice) {
    await importFromFile(context, gear: gear, platform: platform);
  } else {
    await importFromScan(context, gear: gear, meter: meter, source: source);
  }
}
