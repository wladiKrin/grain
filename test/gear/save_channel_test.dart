import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/save.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('grain/save');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Saved carries the names the provider gave', () async {
    late MethodCall sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent = call;
      return {
        'status': 'saved',
        'names': ['roll-4 (1).zip'],
      };
    });
    final r = await const SaveChannel().save([
      (path: '/tmp/x/roll-4.zip', name: 'roll-4.zip'),
    ]);
    expect(sent.method, 'save');
    expect((sent.arguments as Map)['files'], [
      {
        'path': '/tmp/x/roll-4.zip',
        'name': 'roll-4.zip',
        'mime': 'application/zip',
      },
    ]);
    expect(r, isA<Saved>());
    expect(savedMessage((r as Saved).names), 'Saved roll-4 (1).zip');
  });

  test('cancelled and failed', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'status': 'cancelled'},
    );
    expect(
      await const SaveChannel().save([(path: '/a', name: 'a.zip')]),
      isA<SaveCancelled>(),
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'save', message: 'No space left');
    });
    final r = await const SaveChannel().save([(path: '/a', name: 'a.zip')]);
    expect((r as SaveFailed).message, 'No space left');
  });
}
