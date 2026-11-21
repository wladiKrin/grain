import 'package:grain/rolls/location.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/ui/permissions.dart';

class FakeLocation implements LocationSource {
  FakeLocation([this.fix]);

  GeoFix? fix;
  PermissionOutcome outcome = PermissionOutcome.granted;
  int calls = 0;
  int permissionRequests = 0;

  @override
  Future<GeoFix?> current() async {
    calls++;
    return fix;
  }

  @override
  Future<PermissionOutcome> requestPermission() async {
    permissionRequests++;
    return outcome;
  }
}
