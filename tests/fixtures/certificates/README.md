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
