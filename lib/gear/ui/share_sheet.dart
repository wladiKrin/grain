import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../ui/theme.dart';
import '../codec.dart';
import '../gear_controller.dart';
import '../model.dart';
import '../platform.dart';

/// [body] with its mount's favorite lenses and the current lens when it
/// fits and is not already among them. [Kit.lenses] is empty when there are
/// none, in which case no kit is offered.
Kit kitFor(GearController gear, Body body) {
  final lenses = gear.favoriteLensesFor(body.mount);
  final current = gear.lens;
  if (current != null &&
      current.mount == body.mount &&
      !lenses.any((l) => l.id == current.id)) {
    lenses.add(current);
  }
  return Kit(body, lenses);
}

String _count(int n) => n == 1 ? '1 lens' : '$n lenses';

String _title(GearDoc doc) => switch (doc) {
  Body() => doc.displayName,
  Lens() => doc.displayName,
  Kit() => '${doc.body.displayName} + ${_count(doc.lenses.length)}',
};

String _fileName(GearDoc doc) => switch (doc) {
  Body() => '${doc.id}.json',
  Lens() => '${doc.id}.json',
  Kit() => '${doc.body.id}-kit.json',
};

Future<void> showShareSheet(
  BuildContext context, {
  required GearDoc doc,
  required GearPlatform platform,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ShareSheet(doc: doc, platform: platform),
);

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.doc, required this.platform});

  final GearDoc doc;
  final GearPlatform platform;

  @override
  Widget build(BuildContext context) {
    final payload = qrPayloadFor(doc);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              _title(doc),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            if (payload != null)
              QrImageView(
                data: payload.data,
                version: QrVersions.auto,
                errorCorrectionLevel: payload.ec == QrEc.m
                    ? QrErrorCorrectLevel.M
                    : QrErrorCorrectLevel.L,
                size: 240,
                backgroundColor: Colors.white,
              )
            else
              const Text(
                'Too large for one QR code — share it as a file.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: GrainColors.secondary),
              ),
            FilledButton(
              onPressed: () => platform.shareFile(
                fileName: _fileName(doc),
                text: encodePretty(doc),
              ),
              child: const Text('Share file'),
            ),
          ],
        ),
      ),
    );
  }
}
