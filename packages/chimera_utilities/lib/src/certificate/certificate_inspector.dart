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
    final version = _validateTbs(tbsSequence, serialIndex);
    _bitString(sequence.elements[2]);
    final validity = tbsSequence.elements[serialIndex + 3] as ASN1Sequence;
    if (validity.elements.length != 2) _invalid('malformed-certificate');
    final notBefore = _time(validity.elements[0]);
    final notAfter = _time(validity.elements[1]);
    _algorithm(tbsSequence.elements[serialIndex + 1] as ASN1Sequence);
    final spki = tbsSequence.elements[serialIndex + 5] as ASN1Sequence;
    if (spki.elements.length != 2) _invalid('malformed-certificate');
    _bitString(spki.elements[1]);
    final publicKeyAlgorithm = _algorithm(spki.elements[0] as ASN1Sequence);
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
    return CertificateInspectionResult(
      representation: representation,
      version: version,
      serialNumberHex: serialHex,
      subject: _attributes(
        tbsSequence.elements[serialIndex + 4] as ASN1Sequence,
      ),
      issuer: _attributes(
        tbsSequence.elements[serialIndex + 2] as ASN1Sequence,
      ),
      notBefore: notBefore,
      notAfter: notAfter,
      signatureAlgorithm: _algorithm(sequence.elements[1] as ASN1Sequence),
      publicKeyAlgorithm: publicKeyAlgorithm,
      extensions: _extensions(tbsSequence, serialIndex),
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

  int _validateTbs(ASN1Sequence tbs, int offset) {
    if (tbs.tag != 48) _invalid('malformed-certificate');
    final fields = tbs.elements;
    if (fields.length < offset + 6) _invalid('malformed-certificate');
    var version = 1;
    if (offset == 1) {
      final parser = ASN1Parser(fields.first.valueBytes());
      final encodedVersion = parser.nextObject() as ASN1Integer;
      if (encodedVersion.tag != 2 ||
          parser.hasNext() ||
          encodedVersion.valueAsBigInteger < BigInt.zero ||
          encodedVersion.valueAsBigInteger > BigInt.two) {
        _invalid('malformed-certificate');
      }
      version = encodedVersion.intValue + 1;
    }
    const tags = [2, 48, 48, 48, 48, 48];
    for (var i = 0; i < tags.length; i++) {
      if (fields[offset + i].tag != tags[i]) _invalid('malformed-certificate');
    }
    var lastOptional = 0;
    for (final field in fields.skip(offset + 6)) {
      final order = switch (field.tag) {
        0x81 => 1,
        0x82 => 2,
        0xA3 => 3,
        _ => 0,
      };
      if (order <= lastOptional ||
          version == 1 ||
          (order == 3 && version != 3)) {
        _invalid('malformed-certificate');
      }
      lastOptional = order;
      if (order == 3) {
        final parser = ASN1Parser(field.valueBytes());
        final extensions = parser.nextObject();
        if (extensions.tag != 48 ||
            extensions is! ASN1Sequence ||
            parser.hasNext()) {
          _invalid('malformed-certificate');
        }
      } else if (field.valueBytes().isEmpty || field.valueBytes().first > 7) {
        _invalid('malformed-certificate');
      }
    }
    return version;
  }

  void _bitString(ASN1Object object) {
    if (object.tag != 3 || object is! ASN1BitString) {
      _invalid('malformed-certificate');
    }
    final bytes = object.valueBytes();
    if (bytes.isEmpty ||
        bytes.first > 7 ||
        (bytes.length == 1 && bytes.first != 0) ||
        (bytes.last & ((1 << bytes.first) - 1)) != 0) {
      _invalid('malformed-certificate');
    }
  }

  DateTime _time(ASN1Object object) {
    final utc = object.tag == 23;
    if (!utc && object.tag != 24) _invalid('malformed-certificate');
    final text = ascii.decode(object.valueBytes());
    if (text.length != (utc ? 13 : 15)) _invalid('malformed-certificate');
    if (!(utc ? _utcTime : _generalizedTime).hasMatch(text)) {
      _invalid('malformed-certificate');
    }
    final yearWidth = utc ? 2 : 4;
    var year = int.parse(text.substring(0, yearWidth));
    if (utc) year += year >= 50 ? 1900 : 2000;
    final month = int.parse(text.substring(yearWidth, yearWidth + 2));
    final day = int.parse(text.substring(yearWidth + 2, yearWidth + 4));
    final hour = int.parse(text.substring(yearWidth + 4, yearWidth + 6));
    final minute = int.parse(text.substring(yearWidth + 6, yearWidth + 8));
    final second = int.parse(text.substring(yearWidth + 8, yearWidth + 10));
    final value = DateTime.utc(year, month, day, hour, minute, second);
    if (value.year != year ||
        value.month != month ||
        value.day != day ||
        value.hour != hour ||
        value.minute != minute ||
        value.second != second) {
      _invalid('malformed-certificate');
    }
    return value;
  }

  List<CertificateAttribute> _attributes(ASN1Sequence name) {
    final attributes = <CertificateAttribute>[];
    for (final rdn in name.elements) {
      final set = rdn as ASN1Set;
      if (set.elements.isEmpty) _invalid('malformed-certificate');
      for (final field in set.elements) {
        final pair = field as ASN1Sequence;
        if (pair.tag != 48 || pair.elements.length != 2) {
          _invalid('malformed-certificate');
        }
        final oid = _oid(pair.elements.first);
        // Convert one original attribute at a time through x509's public
        // model, so its value conversion cannot collapse repeated OIDs.
        final single = ASN1Sequence()..add(ASN1Set()..add(pair));
        final value =
            x509.Name.fromAsn1(single).names.single.values.single as Object?;
        attributes.add(
          CertificateAttribute(oid: oid, name: _name(oid), value: '$value'),
        );
      }
    }
    return attributes;
  }

  CertificateAlgorithm _algorithm(ASN1Sequence algorithm) {
    if (algorithm.tag != 48 ||
        algorithm.elements.isEmpty ||
        algorithm.elements.length > 2) {
      _invalid('malformed-certificate');
    }
    final oid = _oid(algorithm.elements.first);
    return CertificateAlgorithm(oid: oid, name: _name(oid));
  }

  List<CertificateExtensionMetadata> _extensions(ASN1Sequence tbs, int offset) {
    final extensions = <CertificateExtensionMetadata>[];
    for (final field in tbs.elements.skip(offset + 6)) {
      if (field.tag != 0xA3) continue;
      final sequence =
          ASN1Parser(field.valueBytes()).nextObject() as ASN1Sequence;
      if (sequence.elements.isEmpty) _invalid('malformed-certificate');
      for (final item in sequence.elements) {
        final extension = item as ASN1Sequence;
        final fields = extension.elements;
        if (extension.tag != 48 || (fields.length != 2 && fields.length != 3)) {
          _invalid('malformed-certificate');
        }
        final oid = _oid(fields.first);
        final critical = fields.length == 3
            ? (fields[1] as ASN1Boolean).booleanValue
            : false;
        if (fields.last is! ASN1OctetString) _invalid('malformed-certificate');
        extensions.add(
          CertificateExtensionMetadata(
            oid: oid,
            name: _name(oid),
            critical: critical,
          ),
        );
      }
    }
    return extensions;
  }

  // X.690 combines the first two arcs into a single base-128 subidentifier.
  // Both x509's one-byte split and int accumulation lose valid OID values.
  String _oid(ASN1Object object) {
    if (object is! ASN1ObjectIdentifier) _invalid('malformed-certificate');
    final bytes = object.valueBytes();
    if (bytes.isEmpty) _invalid('malformed-certificate');
    final values = <BigInt>[];
    var value = BigInt.zero;
    var start = true;
    for (final byte in bytes) {
      if (start && byte == 128) _invalid('malformed-certificate');
      value = (value << 7) | BigInt.from(byte & 127);
      start = byte < 128;
      if (start) {
        values.add(value);
        value = BigInt.zero;
      }
    }
    if (!start) _invalid('malformed-certificate');
    final first = values.first;
    final firstArc = first < BigInt.from(40)
        ? 0
        : first < BigInt.from(80)
        ? 1
        : 2;
    return [
      BigInt.from(firstArc),
      first - BigInt.from(firstArc * 40),
      ...values.skip(1),
    ].join('.');
  }

  String? _name(String oid) {
    final nodes = oid.split('.').map(BigInt.parse).toList();
    if (nodes.any((node) => node > BigInt.from(0x7FFFFFFF))) return null;
    try {
      return x509.ObjectIdentifier(nodes.map((node) => node.toInt()).toList())
          .name;
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
final _utcTime = RegExp(r'^[0-9]{12}Z$');
final _generalizedTime = RegExp(r'^[0-9]{14}Z$');
