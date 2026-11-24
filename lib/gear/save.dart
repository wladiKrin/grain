import 'package:flutter/services.dart';

/// How a save to the device ended.
sealed class SaveResult {
  const SaveResult();
}

class Saved extends SaveResult {
  const Saved(this.names);

  final List<String> names;
}

class SaveCancelled extends SaveResult {
  const SaveCancelled();
}

class SaveFailed extends SaveResult {
  const SaveFailed(this.message);

  final String message;
}

/// `Saved 3 files` / `Saved grain-backup-2026-11-24.zip`.
String savedMessage(List<String> names) =>
    names.length == 1 ? 'Saved ${names.single}' : 'Saved ${names.length} files';

String mimeOf(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'csv' => 'text/csv',
    'json' => 'application/json',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}

/// The `grain/save` channel: one file asks for a place to create it, several
/// ask for a folder (Android storage access framework).
class SaveChannel {
  const SaveChannel();

  static const _channel = MethodChannel('grain/save');

  Future<SaveResult> save(List<({String path, String name})> files) async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('save', {
        'files': [
          for (final f in files)
            {'path': f.path, 'name': f.name, 'mime': mimeOf(f.name)},
        ],
      });
      if (r?['status'] == 'saved') {
        return Saved([for (final n in r!['names']! as List) n as String]);
      }
      return const SaveCancelled();
    } on PlatformException catch (e) {
      return SaveFailed(e.message ?? 'unknown error');
    } on MissingPluginException {
      return const SaveFailed('not available here');
    }
  }
}
