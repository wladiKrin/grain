import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../metering/meter_channel.dart';
import '../../ui/theme.dart';
import '../codec.dart';
import '../model.dart';

/// Scans QR codes and pops with the first [GearDoc] that parses.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.source});

  final MeterSource source;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  PreviewInfo? _preview;
  bool _denied = false;
  String? _error;
  bool _foreign = false;
  bool _closing = false;
  bool _stopped = false;
  StreamSubscription<String>? _sub;
  Timer? _foreignTimer;

  @override
  void initState() {
    super.initState();
    _sub = widget.source.qrCodes.listen(_onCode);
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final info = await widget.source.startScan();
      if (mounted) setState(() => _preview = info);
    } on PlatformException catch (e) {
      if (!mounted) return;
      // Nothing was opened, so there is nothing for dispose to stop.
      _stopped = true;
      setState(() {
        if (e.code == 'denied') {
          _denied = true;
        } else {
          _error = e.message ?? e.code;
        }
      });
    }
  }

  void _onCode(String text) {
    if (_closing) return;
    final GearDoc doc;
    try {
      doc = parseGearString(text);
    } on GearFormatException {
      _foreignTimer?.cancel();
      setState(() => _foreign = true);
      _foreignTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _foreign = false);
      });
      return;
    }
    unawaited(_close(doc));
  }

  /// Releases the camera first, so whoever resumes the meter afterwards does
  /// not race the scan's teardown.
  Future<void> _close(GearDoc? result) async {
    if (_closing) return;
    _closing = true;
    unawaited(_sub?.cancel());
    _sub = null;
    if (!_stopped) {
      _stopped = true;
      try {
        await widget.source.stop();
      } on PlatformException {
        // The camera is gone either way.
      }
    }
    if (mounted) Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _foreignTimer?.cancel();
    _sub?.cancel();
    if (!_stopped) {
      _stopped = true;
      unawaited(widget.source.stop());
    }
    super.dispose();
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, color: GrainColors.ink),
      ),
    ),
  );

  Widget _camera(PreviewInfo p) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Texture(textureId: p.textureId),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, .75),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _foreign ? 'Not a Grain profile' : 'Point at a Grain QR code',
              style: const TextStyle(fontSize: 15, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close(null));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan QR code'),
          leading: BackButton(onPressed: () => _close(null)),
        ),
        body: _denied
            ? _message('Grain needs the camera to scan a profile.')
            : _error != null
            ? _message('Camera unavailable\n$_error')
            : p == null
            ? const SizedBox.shrink()
            : _camera(p),
      ),
    );
  }
}
