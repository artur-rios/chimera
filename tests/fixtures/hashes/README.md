# Hash known answers

The empty and `abc` values are the RFC 1321 (MD5) and RFC 6234 / FIPS
180-4 SHA examples. `binary` is hex `00ff80efbbbf000a`; `bom` is hex
`efbbbf`. Binary expectations were independently calculated with Python
hashlib (OpenSSL), never with the production Dart crypto implementation.
All answers are literal checked-in lowercase hexadecimal digests.

References: https://www.rfc-editor.org/rfc/rfc1321
and https://www.rfc-editor.org/rfc/rfc6234 .

`published_binary_vectors.json` additionally pins RFC 6234 section 8.5 test 6
for SHA-1/256/384/512, and the first published 128-byte MD5 collision block
from Peter Selinger's demonstration (https://www.mscs.dal.ca/~selinger/md5collision/).
Its expected digest is published independently for every supported algorithm;
these values are transcribed, then cross-checked separately with OpenSSL.
