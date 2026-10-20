# Classical cipher rules

Chimera's cipher operations use ASCII `A` through `Z` as their selected
alphabet and retain ASCII letter case. Callers must choose whether all other
Unicode scalars are preserved exactly or rejected at their zero-based scalar
position. Input, keys, and output remain local and ephemeral.

| Cipher | Parameter contract | Encoding rule |
| --- | --- | --- |
| Caesar | `shift` is 0 through 25 | Rotate each letter forward by `shift`. |
| ROT13 | No parameters | Caesar with shift 13. |
| Vigenere | Non-empty ASCII-letter `key` | Add repeated key offsets; advance the key only for supported letters. |
| Atbash | No parameters | Reverse the alphabet (`A` to `Z`). |
| Affine | `a` and `b` are 0 through 25; `gcd(a, 26) = 1` | `(a*x + b) mod 26`. |
| Bacon | No parameters | 26-letter five-bit `A/B` groups, `A = AAAAA` through `Z = BBAAB`; group case retains source case. |
| Rail Fence | `rails >= 2` | Standard down/up zigzag over supported letters; preserved scalars stay in their original positions. |

Rail counts at least as large as the supported-letter count are valid no-ops.
No cipher inserts separators. These rules are shared by encode and decode so
round trips remain deterministic.

## Known answers

| Request | Result |
| --- | --- |
| Caesar shift 3: `Hello, World!` | `Khoor, Zruog!` |
| ROT13: `Hello, World!` | `Uryyb, Jbeyq!` |
| Vigenere key `LEMON`: `ATTACKATDAWN` | `LXFOPVEFRNHR` |
| Atbash: `Abc Xyz!` | `Zyx Cba!` |
| Affine `a=5`, `b=8`: `AFFINECIPHER` | `IHHWVCSWFRCP` |
| Bacon: `Abz!` | `AAAAAaaaabbbaab!` |
| Rail Fence 3: `WEAREDISCOVEREDFLEEATONCE` | `WECRLTEERDSOEEFEAOCAIVDEN` |
