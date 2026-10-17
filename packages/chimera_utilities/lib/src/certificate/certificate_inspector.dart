import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:x509/x509.dart' as x509;

import '../base64/base64_byte_decoder.dart';

enum CertificateInputRepresentation { auto, pem, der, base64 }

final class CertificateAttribute {
  const CertificateAttribute({
    required this.oid,
    required this.name,
    required this.value,
  });
  final String oid;
  final String? name;
  final String value;
}

final class CertificateAlgorithm {
  const CertificateAlgorithm({required this.oid, required this.name});
  final String oid;
  final String? name;
}

final class CertificateExtensionMetadata {
  const CertificateExtensionMetadata({
    required this.oid,
    required this.name,
    required this.critical,
  });
  final String oid;
  final String? name;
  final bool critical;
}

final class CertificateInspectionResult {
  CertificateInspectionResult({
    required this.representation,
    required this.version,
    required this.serialNumberHex,
    required List<CertificateAttribute> subject,
    required List<CertificateAttribute> issuer,
    required DateTime notBefore,
    required DateTime notAfter,
    required this.signatureAlgorithm,
    required this.publicKeyAlgorithm,
    required List<CertificateExtensionMetadata> extensions,
    required this.inputByteCount,
    required this.derByteCount,
  }) : subject = List.unmodifiable(subject),
       issuer = List.unmodifiable(issuer),
       notBefore = notBefore.toUtc(),
       notAfter = notAfter.toUtc(),
       extensions = List.unmodifiable(extensions);

  final CertificateInputRepresentation representation;
  final int version;
  final String serialNumberHex;
  final List<CertificateAttribute> subject;
  final List<CertificateAttribute> issuer;
  final DateTime notBefore;
  final DateTime notAfter;
  final CertificateAlgorithm signatureAlgorithm;
  final CertificateAlgorithm publicKeyAlgorithm;
  final List<CertificateExtensionMetadata> extensions;
  final int inputByteCount;
  final int derByteCount;
}

final class CertificateInspectionException implements Exception {
  const CertificateInspectionException({required this.reason});
  final String reason;
  String get code => 'certificate-inspect.invalid-input';
  String get field => 'input';
}

final class CertificateInspectionResourceException implements Exception {
  const CertificateInspectionResourceException({required this.reason});
  final String reason;
  String get code => 'certificate-inspect.resource-limit';
  String get field => 'input';
}

/// Inspects one certificate locally; does not verify signatures or trust.
final class CertificateInspector {
  const CertificateInspector({this.maxInputBytes, this.maxDecodedBytes})
    : assert(maxInputBytes == null || maxInputBytes >= 0),
      assert(maxDecodedBytes == null || maxDecodedBytes >= 0);

  final int? maxInputBytes;
  final int? maxDecodedBytes;

  CertificateInspectionResult inspectText(
    String input, {
    CertificateInputRepresentation representation =
        CertificateInputRepresentation.auto,
  }) => _translate(() {
    final count = _utf8Length(input);
    _inputBudget(count);
    if (representation == CertificateInputRepresentation.der) {
      _invalid('unsupported-representation');
    }
    final selected = representation == CertificateInputRepresentation.auto
        ? (_startsWithPem(input)
              ? CertificateInputRepresentation.pem
              : CertificateInputRepresentation.base64)
        : representation;
    return _inspect(_decodeText(input, selected), selected, count);
  });

  CertificateInspectionResult inspectBytes(
    List<int> input, {
    CertificateInputRepresentation representation =
        CertificateInputRepresentation.auto,
  }) => _translate(() {
    for (final byte in input) {
      if (byte < 0 || byte > 255) _invalid('byte-range');
    }
    _inputBudget(input.length);
    final selected = representation == CertificateInputRepresentation.auto
        ? (_bytesStartWithPem(input)
              ? CertificateInputRepresentation.pem
              : input.every(
                  (byte) => _isBase64(byte) || byte == 61 || _whitespace(byte),
                )
              ? CertificateInputRepresentation.base64
              : CertificateInputRepresentation.der)
        : representation;
    if (selected == CertificateInputRepresentation.der) {
      _decodedBudget(input.length);
      return _inspect(Uint8List.fromList(input), selected, input.length);
    }
    if (selected == CertificateInputRepresentation.pem &&
        !_bytesStartWithPem(input)) {
      _invalid('unsupported-representation');
    }
    return _inspect(
      _decodeText(ascii.decode(input), selected),
      selected,
      input.length,
    );
  });

  Uint8List _decodeText(String input, CertificateInputRepresentation selected) {
    var body = input;
    if (selected == CertificateInputRepresentation.pem) {
      if (_begin.allMatches(input).length > 1) {
        _invalid('multiple-certificates');
      }
      final match = _pem.firstMatch(input);
      if (match == null) _invalid('unsupported-representation');
      body = match.group(1)!;
      if (body.contains('-----BEGIN') || body.contains('-----END')) {
        _invalid('unsupported-representation');
      }
    }
    final normalized = StringBuffer();
    for (var i = 0; i < body.length; i++) {
      final unit = body.codeUnitAt(i);
      if (!_whitespace(unit)) normalized.writeCharCode(unit);
    }
    try {
      return Base64ByteDecoder(maxOutputBytes: maxDecodedBytes)
          .decodeString(normalized.toString(), mode: Base64DecodeMode.binary)
          .bytes;
    } on Base64DecodeException catch (error) {
      if (error.kind == Base64DecodeFailureKind.resource) {
        _resource(
          error.reason == 'allocation-limit'
              ? 'allocation-limit'
              : 'decoded-limit',
        );
      }
      _invalid('malformed-certificate');
    }
  }

  CertificateInspectionResult _inspect(
    Uint8List der,
    CertificateInputRepresentation representation,
    int count,
  ) {
    _decodedBudget(der.length);
    _validateFraming(der);
    final sequence = ASN1Parser(der).nextObject() as ASN1Sequence;
    if (sequence.elements.length != 3) _invalid('malformed-certificate');
    final tbsSequence = sequence.elements.first as ASN1Sequence;
    final serialIndex = tbsSequence.elements.first.tag == 0xA0 ? 1 : 0;
    final serial = (tbsSequence.elements[serialIndex] as ASN1Integer)
        .valueBytes();
    if (serial.isEmpty || serial.first >= 128) {
      _invalid('malformed-certificate');
    }
    final unsigned = serial.length > 1 && serial.first == 0
        ? serial.skip(1)
        : serial;
    final serialHex = unsigned
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    final objects = x509
        .parsePem('$_marker\n${base64Encode(der)}\n-----END CERTIFICATE-----')
        .toList();
    if (objects.length != 1 || objects.single is! x509.X509Certificate) {
      _invalid('malformed-certificate');
    }
    final certificate = objects.single as x509.X509Certificate;
    final tbs = certificate.tbsCertificate;
    final version = tbs.version!;
    if (version < 1 || version > 3) _invalid('malformed-certificate');
    return CertificateInspectionResult(
      representation: representation,
      version: version,
      serialNumberHex: serialHex,
      subject: _attributes(tbs.subject!),
      issuer: _attributes(tbs.issuer!),
      notBefore: tbs.validity!.notBefore,
      notAfter: tbs.validity!.notAfter,
      signatureAlgorithm: _algorithm(certificate.signatureAlgorithm),
      publicKeyAlgorithm: _algorithm(tbs.subjectPublicKeyInfo!.algorithm),
      extensions: [
        for (final extension in tbs.extensions ?? <x509.Extension>[])
          CertificateExtensionMetadata(
            oid: extension.extnId.nodes.join('.'),
            name: _name(extension.extnId),
            critical: extension.isCritical,
          ),
      ],
      inputByteCount: count,
      derByteCount: der.length,
    );
  }

  // Check framing on the original bytes. x509.toAsn1 is lossy and must not
  // be used for this check. An explicit boundary stack avoids recursion.
  void _validateFraming(Uint8List bytes) {
    if (bytes.isEmpty || bytes.first != 0x30) _invalid('malformed-certificate');
    final boundaries = <int>[bytes.length];
    var offset = 0;
    var topLevel = true;
    while (boundaries.isNotEmpty) {
      final boundary = boundaries.last;
      if (offset == boundary) {
        boundaries.removeLast();
        continue;
      }
      if (offset > boundary || offset + 2 > boundary) {
        _invalid('malformed-certificate');
      }
      final tag = bytes[offset++];
      if (tag == 0) _invalid('malformed-certificate');
      if (tag & 31 == 31) {
        if (offset >= boundary || bytes[offset] & 127 == 0) {
          _invalid('malformed-certificate');
        }
        while (true) {
          if (offset >= boundary) _invalid('malformed-certificate');
          if (bytes[offset++] & 128 == 0) break;
        }
      }
      if (offset >= boundary) _invalid('malformed-certificate');
      var length = bytes[offset++];
      if (length >= 128) {
        final octets = length & 127;
        if (octets == 0 || offset + octets > boundary || bytes[offset] == 0) {
          _invalid('malformed-certificate');
        }
        length = 0;
        for (var i = 0; i < octets; i++) {
          length = length * 256 + bytes[offset++];
          if (length > bytes.length) _invalid('malformed-certificate');
        }
        if (length < 128) _invalid('malformed-certificate');
      }
      final end = offset + length;
      if (end > boundary || (topLevel && end != bytes.length)) {
        _invalid('malformed-certificate');
      }
      topLevel = false;
      if (tag & 32 != 0) {
        boundaries.add(end);
      } else {
        offset = end;
      }
    }
  }

  List<CertificateAttribute> _attributes(x509.Name name) => [
    for (final rdn in name.names)
      for (final entry in rdn.entries)
        CertificateAttribute(
          oid: entry.key!.nodes.join('.'),
          name: _name(entry.key!),
          value: '${entry.value as Object?}',
        ),
  ];

  CertificateAlgorithm _algorithm(x509.AlgorithmIdentifier algorithm) =>
      CertificateAlgorithm(
        oid: algorithm.algorithm.nodes.join('.'),
        name: _name(algorithm.algorithm),
      );

  String? _name(x509.ObjectIdentifier oid) {
    try {
      return oid.name;
    } on x509.UnknownOIDNameError {
      return null;
    }
  }

  CertificateInspectionResult _translate(
    CertificateInspectionResult Function() action,
  ) {
    try {
      return action();
    } on CertificateInspectionException {
      rethrow;
    } on CertificateInspectionResourceException {
      rethrow;
    } on OutOfMemoryError {
      _resource('allocation-limit');
    } catch (_) {
      _invalid('malformed-certificate');
    }
  }

  void _inputBudget(int count) {
    if (maxInputBytes case final maximum? when count > maximum) {
      _resource('input-limit');
    }
  }

  void _decodedBudget(int count) {
    if (maxDecodedBytes case final maximum? when count > maximum) {
      _resource('decoded-limit');
    }
  }
}

int _utf8Length(String source) {
  var length = 0;
  for (var i = 0; i < source.length; i++) {
    final unit = source.codeUnitAt(i);
    if (unit < 128) {
      length++;
    } else if (unit < 2048) {
      length += 2;
    } else if (unit >= 0xD800 &&
        unit <= 0xDBFF &&
        i + 1 < source.length &&
        source.codeUnitAt(i + 1) >= 0xDC00 &&
        source.codeUnitAt(i + 1) <= 0xDFFF) {
      length += 4;
      i++;
    } else {
      length += 3;
    }
  }
  return length;
}

bool _startsWithPem(String source) {
  var offset = 0;
  while (offset < source.length && _whitespace(source.codeUnitAt(offset))) {
    offset++;
  }
  return source.startsWith(_marker, offset);
}

bool _bytesStartWithPem(List<int> source) {
  var offset = 0;
  while (offset < source.length && _whitespace(source[offset])) {
    offset++;
  }
  if (source.length - offset < _marker.length) return false;
  for (var i = 0; i < _marker.length; i++) {
    if (source[offset + i] != _marker.codeUnitAt(i)) return false;
  }
  return true;
}

bool _whitespace(int unit) => unit == 32 || unit >= 9 && unit <= 13;
bool _isBase64(int unit) =>
    unit >= 65 && unit <= 90 ||
    unit >= 97 && unit <= 122 ||
    unit >= 48 && unit <= 57 ||
    unit == 43 ||
    unit == 47;
Never _invalid(String reason) =>
    throw CertificateInspectionException(reason: reason);
Never _resource(String reason) =>
    throw CertificateInspectionResourceException(reason: reason);
const _marker = '-----BEGIN CERTIFICATE-----';
final _begin = RegExp('-----BEGIN CERTIFICATE-----');
final _pem = RegExp(
  r'^[\x09-\x0D ]*-----BEGIN CERTIFICATE-----([\s\S]*?)-----END CERTIFICATE-----[\x09-\x0D ]*$',
);
