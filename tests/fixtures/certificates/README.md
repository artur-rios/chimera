# Certificate fixture

This synthetic public X.509 v3 certificate was authored for Chimera on
2026-10-17 and is dedicated to the public domain under CC0-1.0:
https://creativecommons.org/publicdomain/zero/1.0/.
No external certificate or private key was used, generated, or committed.

The canonical DER was assembled directly from the X.509 ASN.1 structure.
The public RSA modulus is the deterministic integer 2^1015 + 643 and the
exponent is 65537. The signature is 128 zero bytes, deliberately not a valid
cryptographic signature. This is a structural inspection fixture, never a
trust or signature-validation fixture. Validity is exactly 2024-01-01 through
2034-01-01 UTC; serial is 0x01AB. It includes an unknown subject OID 1.2.3.4
and unknown noncritical extension 1.2.3.5 to exercise nullable friendly names.

The manifest pins independently checked ASN.1 field values, canonical DER hex,
and exact byte counts. certificate.pem uses LF and 64-column Base64 wrapping;
certificate.base64 is unwrapped with one final LF; certificate.der is the exact
decode of either text form. Regenerate DER mechanically with PowerShell:

```powershell
[IO.File]::WriteAllBytes('certificate.der', [Convert]::FromBase64String([IO.File]::ReadAllText('certificate.base64')))
openssl x509 -in certificate.pem -text -noout
```

## Algorithm/century fixtures

`ed25519.pem` and `unknown-key.pem` are additional directly assembled public
structural certificates under the same CC0 dedication. Both use the public
Ed25519 verification key `d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a`
from [RFC 8032 section 7.1 test 1](https://www.rfc-editor.org/rfc/rfc8032#section-7.1)
(public key only; no private key is retained).
The former declares public-key OID 1.3.101.112; the latter deliberately declares
the structurally valid unknown OID 2.999.5. Each signature algorithm is Ed25519
with a dummy 64-byte zero signature. They prove structural inspection does not
attempt key instantiation, signature validation, or trust decisions.

Validity bytes are UTCTime `500101000000Z` and `491231235959Z`: exactly 1950-01-01
through 2049-12-31T23:59:59Z under RFC 5280. `algorithm-manifest.json` pins
the independent metadata and exact byte counts. `algorithm_fixtures.dart`
embeds their identical DER Base64 for native runners whose working directory
cannot be assumed. Each PEM has LF wrapping and is 509 bytes; each DER is
335 bytes. Existing subject, issuer, serial, and extensions are unchanged.
