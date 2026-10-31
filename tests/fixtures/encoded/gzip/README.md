# GZIP fixtures

These fixtures are independent inputs for UC-21. Archive bytes are stored as
lowercase hexadecimal text so Git reviews remain readable; tests decode the
hexadecimal text before calling the public utility.

The ordinary members were generated with CPython 3.14.0 `gzip.compress`,
compression level 9, and `mtime=0`. The optional-fields member was assembled
with CPython's `zlib.compressobj(wbits=-15)` and RFC 1952 framing. It includes
FEXTRA (`abcd`), FNAME (`name.bin`), FCOMMENT (`comment`), and FHCRC (the low
16 bits of the CRC-32 of the header through the comment terminator). The
concatenated fixture is the byte-for-byte concatenation of the ASCII and
Unicode members. SHA-256 values in `manifest.json` were recorded from the raw
payload and raw GZIP bytes with CPython `hashlib.sha256`.

`compressible.source.json` describes 4,096 repetitions of byte `0x61`; this
avoids storing a large redundant source file while keeping the source exact.
All other `.source.hex` files are the complete raw source bytes.
