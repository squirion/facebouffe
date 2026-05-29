import 'package:flutter_test/flutter_test.dart';

import 'package:facebouffe/data/format.dart';

void main() {
  test('friendly fractions', () {
    expect(fmtQty(0.75), '¾');
    expect(fmtQty(1.5), '1 ½');
    expect(fmtQty(2), '2');
  });

  test('temperature conversion rounds to nearest 5°', () {
    expect(fmtTemp(180, 'c', 'f'), '355 °F');
    expect(fmtTemp(180, 'c', 'c'), '180 °C');
  });

  test('temperature tokenize/detokenize round-trips', () {
    expect(tokenizeTemps('chauffer à 180 °C'), 'chauffer à {{temp:180:c}}');
    expect(detokenizeTemps('chauffer à {{temp:180:c}}'), 'chauffer à 180 °C');
  });
}
