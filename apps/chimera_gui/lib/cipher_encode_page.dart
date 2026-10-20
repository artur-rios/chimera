import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_file_save.dart';

typedef CipherEncodeOperationService =
    OperationService<CipherEncodeOperationRequest, CipherEncodeOutput>;
typedef CipherEncodeFilePicker = Future<List<int>?> Function();
typedef CipherEncodeClipboardReader = Future<String?> Function();
typedef CipherEncodeClipboardWriter = Future<void> Function(String value);
typedef CipherEncodeFileSaver = Future<bool> Function(
  String fileName,
  Uint8List bytes,
  String mimeType,
);
typedef CipherEncodeOutputEncoder = Uint8List Function(String value);

Future<List<int>?> pickCipherEncodeFile() async =>
    (await FilePicker.pickFile())?.readAsBytes();

Future<String?> readCipherEncodeClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeCipherEncodeClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

Uint8List encodeCipherEncodeOutput(String value) => utf8.encode(value);

Future<bool> saveCipherEncodeFile(
  String name,
  Uint8List bytes,
  String mimeType, {
  LocalSaveLocationChooser? chooseLocation,
  LocalFileTransactionWriter? writeTransaction,
}) => saveLocalFile(
  name,
  bytes,
  mimeType,
  extensions: const ['txt'],
  chooseLocation: chooseLocation,
  writeTransaction: writeTransaction,
);

final class CipherEncodePage extends StatefulWidget {
  const CipherEncodePage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.clipboardReader,
    required this.clipboardWriter,
    required this.fileSaver,
    required this.outputEncoder,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final CipherEncodeOperationService service;
  final CipherEncodeFilePicker filePicker;
  final CipherEncodeClipboardReader clipboardReader;
  final CipherEncodeClipboardWriter clipboardWriter;
  final CipherEncodeFileSaver fileSaver;
  final CipherEncodeOutputEncoder outputEncoder;

  @override
  State<CipherEncodePage> createState() => _CipherEncodePageState();
}

final class _CipherEncodePageState extends State<CipherEncodePage> {
  final _inputController = TextEditingController();
  final _shiftController = TextEditingController();
  final _keyController = TextEditingController();
  final _aController = TextEditingController();
  final _bController = TextEditingController();
  final _railsController = TextEditingController();
  final _inputFocus = FocusNode(debugLabel: 'Cipher encoding input');
  final _resultFocus = FocusNode(debugLabel: 'Cipher encoding result');
  List<int>? _fileBytes;
  CipherEncodeOutput? _output;
  String? _error;
  String? _notice;
  String _cipher = 'caesar';
  String _policy = 'preserve';
  int _editorGeneration = 0;
  int _generation = 0;
  bool _busy = false;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'cipherEncode.$key');

  String? _optional(TextEditingController controller) =>
      controller.text.isEmpty ? null : controller.text;

  void _clearSource() {
    _fileBytes = null;
    _inputController.clear();
    _editorGeneration++;
  }

  void _clearResult() {
    _generation++;
    _output = null;
    _error = null;
    _notice = null;
  }

  bool _current(int generation) => mounted && generation == _generation;

  int _begin({bool preserveResult = false}) {
    setState(() {
      if (preserveResult) {
        _generation++;
        _error = null;
        _notice = null;
      } else {
        _clearResult();
      }
      _busy = true;
    });
    return _generation;
  }

  void _fail(int generation, String key) {
    if (!_current(generation)) return;
    setState(() {
      _clearResult();
      _clearSource();
      _busy = false;
      _error = widget.catalog.lookup(
        widget.localeTag,
        'error.cipherEncode.$key',
      );
    });
  }

  CipherEncodeOperationRequest _request(List<int>? bytes) {
    final named = (
      cipher: _cipher,
      characterPolicy: _policy,
      shift: _cipher == 'caesar' ? _optional(_shiftController) : null,
      key: _cipher == 'vigenere' ? _optional(_keyController) : null,
      affineA: _cipher == 'affine' ? _optional(_aController) : null,
      affineB: _cipher == 'affine' ? _optional(_bController) : null,
      rails: _cipher == 'rail-fence' ? _optional(_railsController) : null,
    );
    return bytes == null
        ? CipherEncodeOperationRequest.text(
            _inputController.text,
            cipher: named.cipher,
            characterPolicy: named.characterPolicy,
            shift: named.shift,
            key: named.key,
            affineA: named.affineA,
            affineB: named.affineB,
            rails: named.rails,
          )
        : CipherEncodeOperationRequest.utf8Bytes(
            bytes,
            cipher: named.cipher,
            characterPolicy: named.characterPolicy,
            shift: named.shift,
            key: named.key,
            affineA: named.affineA,
            affineB: named.affineB,
            rails: named.rails,
          );
  }

  Future<void> _encode() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final request = _request(_fileBytes);
      _fileBytes = null;
      final result = await widget.service.execute(request);
      if (!_current(generation)) return;
      result.fold(
        onSuccess: (output) {
          setState(() {
            _clearSource();
            _output = output;
            _busy = false;
          });
          _resultFocus.requestFocus();
        },
        onFailure: (failure) => _fail(generation, switch (failure.kind) {
          FailureKind.resource => 'resource',
          FailureKind.validation || FailureKind.range => 'validation',
          _ => 'interactiveInputAccess',
        }),
      );
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'interactiveInputAccess');
    }
  }

  Future<void> _loadFile() async {
    if (_busy) return;
    final generation = _begin(preserveResult: true);
    try {
      final bytes = await widget.filePicker();
      if (!_current(generation)) return;
      setState(() {
        if (bytes != null) {
          _clearResult();
          _clearSource();
          _fileBytes = bytes;
        }
        _busy = false;
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'fileAccess');
    }
  }

  Future<void> _paste() async {
    if (_busy) return;
    final generation = _begin(preserveResult: true);
    try {
      final text = await widget.clipboardReader();
      if (!_current(generation)) return;
      if (text != null && !_isScalarText(text)) {
        _fail(generation, 'validation');
        return;
      }
      setState(() {
        if (text != null) {
          _clearResult();
          _clearSource();
          _inputController.text = text;
        }
        _busy = false;
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'clipboardRead');
    }
  }

  Future<void> _copy() async {
    final output = _output;
    if (_busy || output == null) return;
    final generation = _begin(preserveResult: true);
    try {
      await widget.clipboardWriter(output.encoded);
      if (!_current(generation)) return;
      setState(() {
        _busy = false;
        _notice = _label('copiedResult');
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'clipboardWrite');
    }
  }

  Future<void> _save() async {
    final output = _output;
    if (_busy || output == null) return;
    final generation = _begin(preserveResult: true);
    try {
      final saved = await widget.fileSaver(
        'chimera-cipher-encoded.txt',
        widget.outputEncoder(output.encoded),
        'text/plain; charset=utf-8',
      );
      if (!_current(generation)) return;
      setState(() {
        _busy = false;
        if (saved) _notice = _label('fileSaved');
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'outputAccess');
    }
  }

  void _textChanged() => setState(() {
    _fileBytes = null;
    _busy = false;
    _clearResult();
  });

  void _configurationChanged() => setState(() {
    _busy = false;
    _clearResult();
  });

  void _cipherChanged(String? value) {
    if (value == null || value == _cipher) return;
    setState(() {
      _cipher = value;
      _shiftController.clear();
      _keyController.clear();
      _aController.clear();
      _bController.clear();
      _railsController.clear();
      _busy = false;
      _clearResult();
    });
  }

  void _policyChanged(String? value) {
    if (value == null || value == _policy) return;
    setState(() {
      _policy = value;
      _busy = false;
      _clearResult();
    });
  }

  bool _isScalarText(String text) {
    for (var index = 0; index < text.length; index++) {
      final unit = text.codeUnitAt(index);
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++index == text.length) return false;
        final next = text.codeUnitAt(index);
        if (next < 0xdc00 || next > 0xdfff) return false;
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        return false;
      }
    }
    return true;
  }

  Widget _ordered(double order, Widget child) =>
      FocusTraversalOrder(order: NumericFocusOrder(order), child: child);

  Widget _parameterField({
    required Key key,
    required TextEditingController controller,
    required String label,
    bool numeric = false,
  }) => TextField(
    key: key,
    controller: controller,
    enabled: !_busy,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    obscureText: controller == _keyController,
    enableSuggestions: controller != _keyController,
    autocorrect: false,
    onChanged: (_) => _configurationChanged(),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );

  @override
  void dispose() {
    _generation++;
    _fileBytes = null;
    _output = null;
    _inputController.dispose();
    _shiftController.dispose();
    _keyController.dispose();
    _aController.dispose();
    _bController.dispose();
    _railsController.dispose();
    _inputFocus.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_label('pageTitle'))),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ordered(
                    1,
                    KeyedSubtree(
                      key: ValueKey(_editorGeneration),
                      child: TextField(
                        key: const Key('cipher-encode-input'),
                        controller: _inputController,
                        focusNode: _inputFocus,
                        autofocus: _editorGeneration == 0,
                        enabled: !_busy,
                        minLines: 3,
                        maxLines: 8,
                        onChanged: (_) => _textChanged(),
                        decoration: InputDecoration(
                          labelText: _label('inputLabel'),
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ordered(
                        2,
                        OutlinedButton.icon(
                          key: const Key('cipher-encode-file'),
                          onPressed: _busy ? null : _loadFile,
                          icon: const Icon(Icons.file_open),
                          label: Text(_label('fileAction')),
                        ),
                      ),
                      _ordered(
                        3,
                        OutlinedButton.icon(
                          key: const Key('cipher-encode-paste'),
                          onPressed: _busy ? null : _paste,
                          icon: const Icon(Icons.content_paste),
                          label: Text(_label('pasteAction')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ordered(
                    4,
                    DropdownButtonFormField<String>(
                      key: const Key('cipher-encode-cipher'),
                      initialValue: _cipher,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _label('cipherLabel'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final value in const [
                          'caesar',
                          'rot13',
                          'vigenere',
                          'atbash',
                          'affine',
                          'bacon',
                          'rail-fence',
                        ])
                          DropdownMenuItem(
                            value: value,
                            child: Text(_label('cipher.$value')),
                          ),
                      ],
                      onChanged: _busy ? null : _cipherChanged,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ordered(
                    5,
                    DropdownButtonFormField<String>(
                      key: const Key('cipher-encode-policy'),
                      initialValue: _policy,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _label('policyLabel'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final value in const ['preserve', 'reject'])
                          DropdownMenuItem(
                            value: value,
                            child: Text(_label('policy.$value')),
                          ),
                      ],
                      onChanged: _busy ? null : _policyChanged,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_cipher == 'caesar')
                    _ordered(
                      6,
                      _parameterField(
                        key: const Key('cipher-encode-shift'),
                        controller: _shiftController,
                        label: _label('shiftLabel'),
                        numeric: true,
                      ),
                    ),
                  if (_cipher == 'vigenere')
                    _ordered(
                      6,
                      _parameterField(
                        key: const Key('cipher-encode-key'),
                        controller: _keyController,
                        label: _label('keyLabel'),
                      ),
                    ),
                  if (_cipher == 'affine')
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 300,
                          child: _ordered(
                            6,
                            _parameterField(
                              key: const Key('cipher-encode-a'),
                              controller: _aController,
                              label: _label('aLabel'),
                              numeric: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _ordered(
                            7,
                            _parameterField(
                              key: const Key('cipher-encode-b'),
                              controller: _bController,
                              label: _label('bLabel'),
                              numeric: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_cipher == 'rail-fence')
                    _ordered(
                      6,
                      _parameterField(
                        key: const Key('cipher-encode-rails'),
                        controller: _railsController,
                        label: _label('railsLabel'),
                        numeric: true,
                      ),
                    ),
                  const SizedBox(height: 8),
                  _ordered(
                    8,
                    ElevatedButton(
                      key: const Key('cipher-encode-submit'),
                      onPressed: _busy ? null : _encode,
                      child: Text(_label('submitAction')),
                    ),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('cipher-encode-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  if (_notice case final notice?) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        notice,
                        key: const Key('cipher-encode-notice'),
                      ),
                    ),
                  ],
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    _ordered(
                      9,
                      Focus(
                        focusNode: _resultFocus,
                        child: Semantics(
                          key: const Key('cipher-encode-result'),
                          container: true,
                          focusable: true,
                          liveRegion: true,
                          explicitChildNodes: true,
                          role: SemanticsRole.region,
                          label: _label('outputLabel'),
                          value: _label('resultSuccess'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              output.encoded,
                              key: const Key('cipher-encode-output'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ordered(
                      10,
                      OutlinedButton.icon(
                        key: const Key('cipher-encode-copy'),
                        onPressed: _busy ? null : _copy,
                        icon: const Icon(Icons.copy),
                        label: Text(_label('copyAction')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ordered(
                      11,
                      OutlinedButton.icon(
                        key: const Key('cipher-encode-save'),
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.save_alt),
                        label: Text(_label('saveAction')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
