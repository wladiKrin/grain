import 'package:grain/rolls/location.dart';
import 'package:grain/rolls/model.dart';

class FakeLocation implements LocationSource {
  FakeLocation([this.fix]);

  GeoFix? fix;
  bool granted = true;
  int calls = 0;
  int permissionRequests = 0;

  @override
  Future<GeoFix?> current() async {
    calls++;
    return fix;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }
}
