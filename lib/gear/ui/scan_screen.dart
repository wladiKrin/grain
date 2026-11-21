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

  /// Shown instead of the hint for a moment after a code that is not a
  /// usable profile.
  String? _refusal;
  bool _closing = false;
  bool _stopped = false;

  /// Released because the app left the foreground; reopened on resume.
  bool _suspended = false;

  /// Bumped by every open and suspend; an open that answers after a newer
  /// one (or after a suspend) is dropped.
  int _openGen = 0;
  Future<void>? _stopping;
  StreamSubscription<String>? _sub;
  Timer? _refusalTimer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: _suspend,
      onPause: _suspend,
      onResume: _reopen,
    );
    _sub = widget.source.qrCodes.listen(_onCode, onError: _onCameraError);
    unawaited(_open());
  }

  Future<void> _open() async {
    final gen = ++_openGen;
    try {
      final info = await widget.source.startScan();
      if (mounted && gen == _openGen) setState(() => _preview = info);
    } on PlatformException catch (e) {
      if (!mounted || gen != _openGen) return;
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

  /// The app went to the background: release the camera (the privacy
  /// indicator goes off, and Android cannot take it away mid-scan).
  void _suspend() {
    if (_closing || _suspended || _denied) return;
    _suspended = true;
    _openGen++;
    if (_preview != null) setState(() => _preview = null);
    if (_stopped) return;
    _stopped = true;
    _stopping = _stopQuietly();
  }

  Future<void> _reopen() async {
    if (_closing || !_suspended) return;
    _suspended = false;
    await _stopping;
    if (_closing || _suspended || !mounted) return;
    _stopping = null;
    _stopped = false;
    if (_error != null) setState(() => _error = null);
    await _open();
  }

  Future<void> _stopQuietly() async {
    try {
      await widget.source.stop();
    } on Object {
      // The camera is gone either way.
    }
  }

  /// The native side tears the scan down after reporting an error.
  void _onCameraError(Object e) {
    if (_closing || !mounted) return;
    _stopped = true;
    _openGen++;
    setState(() {
      _preview = null;
      _error = e is PlatformException ? (e.message ?? e.code) : '$e';
    });
  }

  void _onCode(String text) {
    if (_closing) return;
    final GearDoc doc;
    try {
      doc = parseGearString(text);
    } on GearFormatException catch (e) {
      final first = e.errors.first;
      // A newer Grain's profile gets the upgrade message, as a file does.
      final refusal = first.startsWith('schema: made by a newer')
          ? first
          : 'Not a Grain profile';
      _refusalTimer?.cancel();
      setState(() => _refusal = refusal);
      _refusalTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _refusal = null);
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
    _openGen++;
    if (!_stopped) {
      _stopped = true;
      await _stopQuietly();
    } else {
      await _stopping;
    }
    if (mounted) Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _refusalTimer?.cancel();
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
              _refusal ?? 'Point at a Grain QR code',
              textAlign: TextAlign.center,
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
