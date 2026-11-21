import 'package:uuid/uuid.dart';

/// A fresh random id (UUID v4).
String newId() => const Uuid().v4();

/// [t] as UTC with milliseconds and microseconds dropped.
DateTime atSecond(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute, u.second);
}
