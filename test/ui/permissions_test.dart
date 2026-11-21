import 'package:flutter_test/flutter_test.dart';
import 'package:grain/ui/permissions.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test('statuses map to outcomes', () {
    expect(outcomeOf(PermissionStatus.granted), PermissionOutcome.granted);
    expect(outcomeOf(PermissionStatus.limited), PermissionOutcome.granted);
    expect(outcomeOf(PermissionStatus.denied), PermissionOutcome.denied);
    expect(
      outcomeOf(PermissionStatus.permanentlyDenied),
      PermissionOutcome.blocked,
    );
    expect(outcomeOf(PermissionStatus.restricted), PermissionOutcome.blocked);
  });
}
