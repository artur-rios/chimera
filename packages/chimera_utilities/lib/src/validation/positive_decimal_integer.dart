/// Parses ASCII decimal digits as an exactly representable positive [int].
///
/// Leading zeroes are permitted. Signs, whitespace, fractional/scientific/hex
/// notation and rounded or nonfinite target-runtime values return null. No
/// product-specific ceiling is imposed: native/Wasm int64 and JavaScript number
/// targets accept every positive integer they can represent exactly.
int? tryParsePositiveDecimalInteger(String source) {
  if (source.isEmpty || source.contains(RegExp(r'[^0-9]'))) return null;
  final value = int.tryParse(source);
  if (value == null || !value.isFinite || value < 1) return null;
  // Dart's JavaScript parser can round decimal input, while int.toString may
  // display an exact large integer in scientific notation. Compare mathematical
  // integers instead of their display strings; BigInt.from preserves the actual
  // numeric value represented by the target runtime.
  return BigInt.from(value) == BigInt.parse(source, radix: 10) ? value : null;
}
