# Checksum known answers

CRC32 means CRC-32/ISO-HDLC: reflected polynomial `0xedb88320`, initial
register and final XOR `0xffffffff`. The independent reference is
[zlib's CRC32 implementation](https://github.com/madler/zlib/blob/develop/crc32.c).
Adler-32 follows [RFC 1950 §8](https://www.rfc-editor.org/rfc/rfc1950.html#section-8):
`s1=1`, `s2=0`, modulus 65521. The common Wikipedia text fixture yields `11e60398`, independently cross-checked below.

Every literal answer in `vectors.json` was cross-checked using CPython's separate
zlib library; fixture values are never calculated using Chimera. `vectors.dart`
contains the same literal answers for Flutter tests. Regenerate the independent
check locally with:

```python
import json, zlib
for v in json.load(open('tests/fixtures/checksums/vectors.json')):
    data = bytes(v['bytes'])
    assert v['checksums']['crc32'] == f'{zlib.crc32(data):08x}'
    assert v['checksums']['adler32'] == f'{zlib.adler32(data):08x}'
```

`digits` checks the common `123456789` answer. `binary` covers NUL, high-bit
bytes, CR and LF. `bom` ensures UTF-8 BOM bytes are preserved. `allbytes` covers
all 256 byte values and an Adler32 result with the high bit set. Browser and
native Safari tests exercise those exact inputs against compiled JavaScript.
One million ASCII `a` bytes additionally cross-check CRC `dc25bfbc` and Adler
`15d870f9`, including many modulo reductions and no product size cap.
