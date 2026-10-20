# Classical cipher rules

Chimera's cipher operations use ASCII `A` through `Z` as their selected
alphabet and retain ASCII letter case. Callers must choose whether all other
Unicode scalars are preserved exactly or rejected at their zero-based scalar
position. Input, keys, and output remain local and ephemeral.

| Cipher | Parameter contract | Encoding rule | Decoding rule |
| --- | --- | --- | --- |
| Caesar | `shift` is 0 through 25 | Rotate each letter forward by `shift`. | Rotate each letter backward by `shift`. |
| ROT13 | No parameters | Caesar with shift 13. | Apply ROT13 again. |
| Vigenere | Non-empty ASCII-letter `key` | Add repeated key offsets; advance the key only for supported letters. | Subtract repeated key offsets; advance the key only for supported letters. |
| Atbash | No parameters | Reverse the alphabet (`A` to `Z`). | Apply Atbash again. |
| Affine | `a` and `b` are 0 through 25; `gcd(a, 26) = 1` | `(a*x + b) mod 26`. | `a^-1 * (y - b) mod 26`. |
| Bacon | No parameters | 26-letter five-bit `A/B` groups, `A = AAAAA` through `Z = BBAAB`; group case retains source case. | Convert each complete, uniform-case five-symbol group to one letter. |
| Rail Fence | `rails >= 2` | Standard down/up zigzag over supported letters; preserved scalars stay in their original positions. | Reconstruct the zigzag row lengths and read supported letters in path order. |

Rail counts at least as large as the supported-letter count are valid no-ops.
No cipher inserts separators. These rules are shared by encode and decode so
round trips remain deterministic.

Bacon decoding accepts preserved scalars only between complete five-symbol
groups. Partial groups, mixed-case groups, non-`A`/`B` ASCII letters, and
five-bit values outside 0 through 25 are rejected as ambiguous input at the
first determinable scalar position.

## Known answers

| Plain text | Cipher and parameters | Encoded text |
| --- | --- | --- |
| `Hello, World!` | Caesar shift 3 | `Khoor, Zruog!` |
| `Hello, World!` | ROT13 | `Uryyb, Jbeyq!` |
| `ATTACKATDAWN` | Vigenere key `LEMON` | `LXFOPVEFRNHR` |
| `Abc Xyz!` | Atbash | `Zyx Cba!` |
| `AFFINECIPHER` | Affine `a=5`, `b=8` | `IHHWVCSWFRCP` |
| `Abz!` | Bacon | `AAAAAaaaabbbaab!` |
| `WEAREDISCOVEREDFLEEATONCE` | Rail Fence 3 | `WECRLTEERDSOEEFEAOCAIVDEN` |

Each row is bidirectional: encoding maps the plain text to the encoded text,
and decoding maps the encoded text back to the plain text.
