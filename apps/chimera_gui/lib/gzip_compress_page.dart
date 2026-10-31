import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef GzipCompressOperationService =
    OperationService<GzipCompressOperationRequest, GzipCompressOutput>;
typedef GzipCompressFilePicker = Future<List<int>?> Function();
typedef GzipCompressClipboardReader = Future<String?> Function();
typedef GzipCompressFileSaver = Future<bool> Function(
  String fileName,
  Uint8List bytes,
  String mimeType,
);

Future<List<int>?> pickGzipCompressFile() async {
  final file = await FilePicker.pickFile();
  return await file?.readAsBytes();
}

Future<String?> readGzipCompressClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<bool> saveGzipCompressFile(
  String name,
  Uint8List bytes,
  String mimeType,
) async =>
    await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: mimeType,
      type: FileType.custom,
      allowedExtensions: ['gz'],
    ) !=
    null;

final class GzipCompressPage extends StatefulWidget {
  const GzipCompressPage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.clipboardReader,
    required this.fileSaver,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final GzipCompressOperationService service;
  final GzipCompressFilePicker filePicker;
  final GzipCompressClipboardReader clipboardReader;
  final GzipCompressFileSaver fileSaver;

  @override
  State<GzipCompressPage> createState() => _GzipCompressPageState();
}

final class _GzipCompressPageState extends State<GzipCompressPage> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode(debugLabel: 'GZIP compression input');
  final _resultFocus = FocusNode(debugLabel: 'GZIP compression result');
  List<int>? _fileBytes;
  GzipCompressOutput? _output;
  String? _error;
  String? _notice;
  int _level = 6;
  int _generation = 0;
  int _editorGeneration = 0;
  bool _busy = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);
  String _label(String key) => _message('gzipCompress.$key');

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

  void _clearResult() {
    _generation++;
    _output = null;
    _error = null;
    _notice = null;
  }

  void _clearSource() {
    _fileBytes = null;
    _inputController.clear();
    // UndoHistory retains editing snapshots independently of controller text.
    // Recreate the editor subtree to dispose its stack and pending snapshot
    // timer, keeping the page-owned controller/listeners and focus node stable.
    _editorGeneration++;
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
      _error = _message('error.gzipCompress.$key');
    });
  }

  void _complete(int generation, GzipCompressOutput output) {
    if (!_current(generation)) return;
    setState(() {
      // Discard source/editor history without invalidating this generation or
      // clearing the authoritative immutable result needed by the save action.
      _clearSource();
      _output = output;
      _busy = false;
    });
    _resultFocus.requestFocus();
  }

  Future<void> _compress() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final bytes = _fileBytes;
      final request = bytes == null
          ? GzipCompressOperationRequest.text(
              _inputController.text,
              level: _level,
            )
          : GzipCompressOperationRequest.bytes(bytes, level: _level);
      final result = await widget.service.execute(request);
      if (!_current(generation)) return;
      result.fold(
        onSuccess: (output) => _complete(generation, output),
        onFailure: (failure) => _fail(generation, switch (failure.kind) {
          FailureKind.resource => 'resource',
          FailureKind.validation || FailureKind.range => 'validation',
          _ => 'interactiveInputAccess',
        }),
      );
    } on GzipCompressException catch (error) {
      _fail(
        generation,
        error.kind == GzipCompressFailureKind.resource
            ? 'resource'
            : 'validation',
      );
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'interactiveInputAccess');
    }
  }

  Future<void> _loadFile() async {
    if (_busy) return;
    // Cancellation is neutral and preserves the previous source/result.
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
    final generation = _begin();
    _clearSource();
    try {
      final text = await widget.clipboardReader();
      if (!_current(generation)) return;
      setState(() {
        _inputController.text = text ?? '';
        _busy = false;
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'clipboardRead');
    }
  }

  Future<void> _save() async {
    final output = _output;
    if (_busy || output == null) return;
    final generation = _begin(preserveResult: true);
    try {
      // One exact immutable payload handoff. The platform owns its transaction.
      final saved = await widget.fileSaver(
        'chimera-compressed.gz',
        output.bytes,
        'application/gzip',
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

  void _levelChanged(int? value) {
    if (value == null || value == _level) return;
    setState(() {
      _level = value;
      _busy = false;
      _clearResult();
    });
  }

  Widget _ordered(double order, Widget child) =>
      FocusTraversalOrder(order: NumericFocusOrder(order), child: child);

  String _summary(GzipCompressOutput output) =>
      '${_label('levelLabel')}: ${output.level}\n'
      '${_label('inputByteCountLabel')}: ${output.inputByteCount}\n'
      '${_label('outputByteCountLabel')}: ${output.outputByteCount}';

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
                        key: const Key('gzip-compress-input'),
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
                          key: const Key('gzip-compress-file'),
                          onPressed: _busy ? null : _loadFile,
                          icon: const Icon(Icons.file_open),
                          label: Text(_label('fileAction')),
                        ),
                      ),
                      _ordered(
                        3,
                        OutlinedButton.icon(
                          key: const Key('gzip-compress-paste'),
                          onPressed: _busy ? null : _paste,
                          icon: const Icon(Icons.content_paste),
                          label: Text(_label('pasteAction')),
                        ),
                      ),
                    ],
                  ),
                  if (_fileBytes case final bytes?) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${_label('inputByteCountLabel')}: ${bytes.length}',
                        key: const Key('gzip-compress-file-summary'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ordered(
                    4,
                    DropdownButtonFormField<int>(
                      key: const Key('gzip-compress-level'),
                      initialValue: _level,
                      decoration: InputDecoration(
                        labelText: _label('levelLabel'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (var level = 0; level <= 9; level++)
                          DropdownMenuItem(value: level, child: Text('$level')),
                      ],
                      onChanged: _busy ? null : _levelChanged,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ordered(
                    5,
                    ElevatedButton(
                      key: const Key('gzip-compress-submit'),
                      onPressed: _busy ? null : _compress,
                      child: Text(_label('submitAction')),
                    ),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('gzip-compress-error'),
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
                        key: const Key('gzip-compress-notice'),
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
                          key: const Key('gzip-compress-result'),
                          container: true,
                          focusable: true,
                          liveRegion: true,
                          excludeSemantics: true,
                          role: SemanticsRole.region,
                          label: _label('outputLabel'),
                          value:
                              '${_label('resultSuccess')}\n${_summary(output)}',
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
                                for (final line in _summary(output).split('\n'))
                                  Text(line),
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
                        key: const Key('gzip-compress-save'),
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
