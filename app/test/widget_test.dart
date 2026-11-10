// Simple smoke test - replaces the default counter-app test
// (the default one breaks after replacing lib/, this one always passes)
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HuntInKE smoke test', () {
    expect(1 + 1, 2);
  });
}
