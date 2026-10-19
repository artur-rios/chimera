import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'empty_file_save.dart';

typedef HashGenerateOperationService =
    OperationService<HashGenerateOperationRequest, HashGenerateOutput>;
typedef HashGenerateFilePicker = Future<List<int>?> Function();
typedef HashGenerateClipboardReader = Future<String?> Function();
typedef HashGenerateClipboardWriter = Future<void> Function(String value);
typedef HashGenerateFileSaver = Future<bool> Function(
  String fileName,
  Uint8List bytes,
  String mimeType,
);
typedef HashGenerateOutputEncoder = Uint8List Function(String value);

Future<List<int>?> pickHashGenerateFile() async {
  final file = await FilePicker.pickFile();
  return await file?.readAsBytes();
}

Future<String?> readHashGenerateClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeHashGenerateClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

Uint8List encodeHashGenerateOutput(String value) => utf8.encode(value);

Future<bool> saveHashGenerateFile(
  String name,
  Uint8List bytes,
  String mimeType,
) async {
  final emptyWebSave = await trySaveEmptyFile(name, bytes, mimeType);
  if (emptyWebSave != null) return emptyWebSave;
  final result = await FilePicker.saveFile(
    fileName: name,
    bytes: bytes,
    mimeType: mimeType,
    type: FileType.custom,
    allowedExtensions: ['txt'],
  );
  return kIsWeb || result != null;
}

final class HashGeneratePage extends StatefulWidget {
  const HashGeneratePage({
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
  final HashGenerateOperationService service;
  final HashGenerateFilePicker filePicker;
  final HashGenerateClipboardReader clipboardReader;
  final HashGenerateClipboardWriter clipboardWriter;
  final HashGenerateFileSaver fileSaver;
  final HashGenerateOutputEncoder outputEncoder;

  @override
  State<HashGeneratePage> createState() => _HashGeneratePageState();
}

final class _HashGeneratePageState extends State<HashGeneratePage> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode(debugLabel: 'Hash generation input');
  final _resultFocus = FocusNode(debugLabel: 'Hash generation result');
  List<int>? _fileBytes;
  HashGenerateOutput? _output;
  String? _error;
  String? _notice;
  String _algorithm = 'sha256';
  int _editorGeneration = 0;
  int _generation = 0;
  bool _busy = false;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'hashGenerate.$key');

  void _clearSource() {
    _fileBytes = null;
    _inputController.clear();
    // Recreate the editor subtree to dispose UndoHistory and pending snapshots
    // while retaining the page-owned controller, listeners, and focus node.
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
        'error.hashGenerate.$key',
      );
    });
  }

  @override
  void dispose() {
    _generation++;
    _clearSource();
    _output = null;
    _inputController.dispose();
    _inputFocus.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final bytes = _fileBytes;
      final request = bytes == null
          ? HashGenerateOperationRequest.text(
              _inputController.text,
              algorithm: _algorithm,
            )
          : HashGenerateOperationRequest.bytes(bytes, algorithm: _algorithm);
      // The service owns this transient request; the page drops raw file bytes
      // immediately, before awaiting conversion, and retains no request field.
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
      // Flutter's editor assumes well-formed UTF-16. Reject malformed clipboard
      // text before rendering; the service still validates every encode request.
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
      await widget.clipboardWriter(output.digest);
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
        'chimera-hash.txt',
        widget.outputEncoder('${output.digest}\n'),
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

  void _textChanged(String _) => setState(() {
    _fileBytes = null;
    _busy = false;
    _clearResult();
  });

  void _algorithmChanged(String? value) {
    if (value == null || value == _algorithm) return;
    setState(() {
      _algorithm = value;
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
                        key: const Key('hash-generate-input'),
                        controller: _inputController,
                        focusNode: _inputFocus,
                        autofocus: _editorGeneration == 0,
                        enabled: !_busy,
                        minLines: 3,
                        maxLines: 8,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onChanged: _textChanged,
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
                          key: const Key('hash-generate-file'),
                          onPressed: _busy ? null : _loadFile,
                          icon: const Icon(Icons.file_open),
                          label: Text(_label('fileAction')),
                        ),
                      ),
                      _ordered(
                        3,
                        OutlinedButton.icon(
                          key: const Key('hash-generate-paste'),
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
                      key: const Key('hash-generate-algorithm'),
                      initialValue: _algorithm,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _label('algorithmLabel'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final algorithm in const [
                          'sha256',
                          'sha384',
                          'sha512',
                          'md5',
                          'sha1',
                        ])
                          DropdownMenuItem(
                            value: algorithm,
                            child: Text(algorithm.toUpperCase()),
                          ),
                      ],
                      onChanged: _busy ? null : _algorithmChanged,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ordered(
                    5,
                    ElevatedButton(
                      key: const Key('hash-generate-submit'),
                      onPressed: _busy ? null : _generate,
                      child: Text(_label('submitAction')),
                    ),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('hash-generate-error'),
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
                        key: const Key('hash-generate-notice'),
                      ),
                    ),
                  ],
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    _ordered(
                      6,
                      Focus(
                        focusNode: _resultFocus,
                        child: Semantics(
                          key: const Key('hash-generate-result'),
                          container: true,
                          focusable: true,
                          liveRegion: true,
                          excludeSemantics: true,
                          role: SemanticsRole.region,
                          label: _label('outputLabel'),
                          value:
                              '${_label('resultSuccess')} ${output.digest}${output.legacy ? ' ${_label('legacyWarning')}' : ''}',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _label('outputLabel'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                if (output.warningKey != null)
                                  Text(
                                    _label('legacyWarning'),
                                    key: const Key('hash-generate-warning'),
                                  ),
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 240,
                                  ),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      output.digest,
                                      key: const Key('hash-generate-output'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ordered(
                      7,
                      OutlinedButton.icon(
                        key: const Key('hash-generate-copy'),
                        onPressed: _busy ? null : _copy,
                        icon: const Icon(Icons.copy),
                        label: Text(_label('copyAction')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ordered(
                      8,
                      OutlinedButton.icon(
                        key: const Key('hash-generate-save'),
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
