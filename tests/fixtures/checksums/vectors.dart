// Literal Python zlib answers; see README.md for independent provenance.
const checksumKnownVectors = <String, Map<String, String>>{
  'empty': {'crc32': '00000000', 'adler32': '00000001'},
  'digits': {'crc32': 'cbf43926', 'adler32': '091e01de'},
  'abc': {'crc32': '352441c2', 'adler32': '024d0127'},
  'binary': {'crc32': 'ac697d3f', 'adler32': '05a50197'},
  'bom': {'crc32': 'beb3f7ed', 'adler32': '0e8d0390'},
  'Wikipedia': {'crc32': 'adaac02e', 'adler32': '11e60398'},
  'allbytes': {'crc32': '29058c73', 'adler32': 'adf67f81'},
};
