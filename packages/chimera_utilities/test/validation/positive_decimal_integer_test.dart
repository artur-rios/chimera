import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  for (final raw in [
    '1',
    '0001',
    '17',
    '9007199254740991',
    '9007199254740992',
    '9007199254740993',
    '9007199254740994',
    '9223372036854775807',
  ]) {
    test(
      'Given${raw}NativeInteger_WhenParsed_ThenExactValueWithoutProductCap',
      () {
        final parsed = tryParsePositiveDecimalInteger(raw);
        expect(parsed, isNotNull);
        expect(BigInt.from(parsed!), BigInt.parse(raw));
      },
    );
  }
  for (final raw in [
    '',
    '0',
    '000',
    '-1',
    '+1',
    ' 1',
    '1 ',
    '1\n',
    '\n1',
    '1\r\n',
    '1\t',
    '1.0',
    '1e2',
    '0x10',
    '١',
    '１',
    '999999999999999999999999999999999',
  ]) {
    test('GivenInvalid${raw}_WhenParsed_ThenNull', () {
      expect(tryParsePositiveDecimalInteger(raw), isNull);
    });
  }
}
