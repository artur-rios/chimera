import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'empty_file_save.dart';

typedef HtmlEncodeOperationService =
    OperationService<HtmlEncodeOperationRequest, HtmlEncodeOutput>;
typedef HtmlEncodeFilePicker = Future<List<int>?> Function();
typedef HtmlEncodeClipboardReader = Future<String?> Function();
typedef HtmlEncodeClipboardWriter = Future<void> Function(String value);
typedef HtmlEncodeFileSaver = Future<bool> Function(
  String fileName,
  Uint8List bytes,
  String mimeType,
);
typedef HtmlEncodeOutputEncoder = Uint8List Function(String value);

Future<List<int>?> pickHtmlEncodeFile() async {
  final file = await FilePicker.pickFile();
  return await file?.readAsBytes();
}

Future<String?> readHtmlEncodeClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeHtmlEncodeClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

Uint8List encodeHtmlEncodeOutput(String value) => utf8.encode(value);

Future<bool> saveHtmlEncodeFile(
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

final class HtmlEncodePage extends StatefulWidget {
  const HtmlEncodePage({
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
  final HtmlEncodeOperationService service;
  final HtmlEncodeFilePicker filePicker;
  final HtmlEncodeClipboardReader clipboardReader;
  final HtmlEncodeClipboardWriter clipboardWriter;
  final HtmlEncodeFileSaver fileSaver;
  final HtmlEncodeOutputEncoder outputEncoder;

  @override
  State<HtmlEncodePage> createState() => _HtmlEncodePageState();
}

final class _HtmlEncodePageState extends State<HtmlEncodePage> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode(debugLabel: 'HTML encoding input');
  final _resultFocus = FocusNode(debugLabel: 'HTML encoding result');
  List<int>? _fileBytes;
  HtmlEncodeOutput? _output;
  String? _error;
  String? _notice;
  String _context = 'all';
  int _editorGeneration = 0;
  int _generation = 0;
  bool _busy = false;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'htmlEncode.$key');

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
      _error = widget.catalog.lookup(widget.localeTag, 'error.htmlEncode.$key');
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

  Future<void> _encode() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final bytes = _fileBytes;
      final request = bytes == null
          ? HtmlEncodeOperationRequest.text(
              _inputController.text,
              context: _context,
            )
          : HtmlEncodeOperationRequest.utf8Bytes(bytes, context: _context);
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
        'chimera-html-encoded.txt',
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

  void _textChanged(String _) => setState(() {
    _fileBytes = null;
    _busy = false;
    _clearResult();
  });

  void _contextChanged(String? value) {
    if (value == null || value == _context) return;
    setState(() {
      _context = value;
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
                        key: const Key('html-encode-input'),
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
                          key: const Key('html-encode-file'),
                          onPressed: _busy ? null : _loadFile,
                          icon: const Icon(Icons.file_open),
                          label: Text(_label('fileAction')),
                        ),
                      ),
                      _ordered(
                        3,
                        OutlinedButton.icon(
                          key: const Key('html-encode-paste'),
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
                      key: const Key('html-encode-context'),
                      initialValue: _context,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _label('contextLabel'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final entry in const {
                          'all': 'contextAll',
                          'element': 'contextElement',
                          'double-quoted-attribute':
                              'contextDoubleQuotedAttribute',
                          'single-quoted-attribute':
                              'contextSingleQuotedAttribute',
                        }.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(_label(entry.value)),
                          ),
                      ],
                      onChanged: _busy ? null : _contextChanged,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ordered(
                    5,
                    ElevatedButton(
                      key: const Key('html-encode-submit'),
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
                        key: const Key('html-encode-error'),
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
                      child: Text(notice, key: const Key('html-encode-notice')),
                    ),
                  ],
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    _ordered(
                      6,
                      Focus(
                        focusNode: _resultFocus,
                        child: Semantics(
                          key: const Key('html-encode-result'),
                          container: true,
                          focusable: true,
                          liveRegion: true,
                          excludeSemantics: true,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _label('outputLabel'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 240,
                                  ),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      output.encoded,
                                      key: const Key('html-encode-output'),
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
                        key: const Key('html-encode-copy'),
                        onPressed: _busy ? null : _copy,
                        icon: const Icon(Icons.copy),
                        label: Text(_label('copyAction')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ordered(
                      8,
                      OutlinedButton.icon(
                        key: const Key('html-encode-save'),
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
