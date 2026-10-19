# QR image fixtures

`unicode.png` is a 256-pixel PNG containing `QR Olá 世界 🌍`, generated locally
with Chimera's UC-26 encoder (medium correction, four-module quiet zone).
It contains no URLs or personal data. The browser and native Safari harnesses
use it to prove local image ingestion and exact Unicode copy/save behavior.
Utility tests also use independent ZXing-produced symbols and image formats.
