import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/ids.dart';

void main() {
  test('slugify and uniqueId', () {
    expect(slugify('Canon A-1 (copy)'), 'canon-a-1-copy');
    expect(uniqueId('canon-a1', {'canon-a1'}), 'canon-a1-2');
    expect(uniqueId('canon-a1', {'canon-a1', 'canon-a1-2'}), 'canon-a1-3');
    expect(uniqueId('canon-a1', {}), 'canon-a1');
  });

  test('slugify keeps dots, trims dashes, caps at 64', () {
    expect(slugify('  FD 50mm f/1.8 '), 'fd-50mm-f-1.8');
    expect(slugify('---'), '');
    final long = slugify('a' * 70);
    expect(long.length, 64);
    expect(slugify('${'a' * 63} b'), 'a' * 63);
  });
}
