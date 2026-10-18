import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef GzipDecompressOperationService =
    OperationService<GzipDecompressOperationRequest, GzipDecompressOutput>;
typedef GzipDecompressFilePicker = Future<List<int>?> Function();
typedef GzipDecompressClipboardWriter = Future<void> Function(String value);
typedef GzipDecompressFileSaver = Future<bool> Function(
  String fileName,
  Uint8List bytes,
  String mimeType,
);

Future<List<int>?> pickGzipDecompressFile() async {
  final file = await FilePicker.pickFile();
  return await file?.readAsBytes();
}

Future<void> writeGzipDecompressClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

Future<bool> saveGzipDecompressFile(
  String name,
  Uint8List bytes,
  String mimeType,
) async =>
    await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: mimeType,
      type: FileType.custom,
      allowedExtensions: [name.split('.').last],
    ) !=
    null;

final class GzipDecompressPage extends StatefulWidget {
  const GzipDecompressPage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.clipboardWriter,
    required this.fileSaver,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final GzipDecompressOperationService service;
  final GzipDecompressFilePicker filePicker;
  final GzipDecompressClipboardWriter clipboardWriter;
  final GzipDecompressFileSaver fileSaver;

  @override
  State<GzipDecompressPage> createState() => _GzipDecompressPageState();
}

final class _GzipDecompressPageState extends State<GzipDecompressPage> {
  final _fileFocus = FocusNode(debugLabel: 'GZIP decompression file');
  final _resultFocus = FocusNode(debugLabel: 'GZIP decompression result');
  List<int>? _source;
  GzipDecompressMode _mode = GzipDecompressMode.text;
  GzipDecompressOutput? _output;
  String? _error;
  String? _notice;
  bool _busy = false;
  int _generation = 0;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);
  String _label(String key) => _message('gzipDecompress.$key');

  @override
  void dispose() {
    _generation++;
    _source = null;
    _output = null;
    _fileFocus.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  bool _current(int generation) => mounted && generation == _generation;

  void _clearResult() {
    _generation++;
    _output = null;
    _error = null;
    _notice = null;
  }

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
      _source = null;
      _busy = false;
      _error = _message('error.gzipDecompress.$key');
    });
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
          _source = bytes;
        }
        _busy = false;
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'fileAccess');
    }
  }

  Future<void> _decompress() async {
    if (_busy) return;
    final generation = _begin();
    final source = _source ?? const <int>[];
    final request = GzipDecompressOperationRequest.bytes(source, mode: _mode);
    // The request is now the only transient owner controlled by this adapter.
    // Clear page state before asynchronous decoding starts.
    setState(() => _source = null);
    try {
      final result = await widget.service.execute(request);
      if (!_current(generation)) return;
      result.fold(
        onSuccess: (output) {
          setState(() {
            _output = output;
            _busy = false;
          });
          _resultFocus.requestFocus();
        },
        onFailure: (failure) => _fail(
          generation,
          failure.kind == FailureKind.resource
              ? 'resource'
              : 'interactiveInputAccess',
        ),
      );
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'interactiveInputAccess');
    }
  }

  Future<void> _copy() async {
    final output = _output;
    if (_busy || output?.text == null) return;
    final generation = _begin(preserveResult: true);
    try {
      await widget.clipboardWriter(output!.text!);
      if (!_current(generation)) return;
      setState(() {
        _notice = _label('copiedResult');
        _busy = false;
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
      final text = output.mode == GzipDecompressMode.text;
      final saved = await widget.fileSaver(
        text ? 'chimera-decompressed.txt' : 'chimera-decompressed.bin',
        output.bytes,
        text ? 'text/plain; charset=utf-8' : 'application/octet-stream',
      );
      if (!_current(generation)) return;
      setState(() {
        if (saved) _notice = _label('fileSaved');
        _busy = false;
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'outputAccess');
    }
  }

  void _modeChanged(Set<GzipDecompressMode> selection) {
    if (_busy || selection.isEmpty || selection.first == _mode) return;
    setState(() {
      _mode = selection.first;
      _clearResult();
    });
  }

  Widget _ordered(double order, Widget child) =>
      FocusTraversalOrder(order: NumericFocusOrder(order), child: child);

  String _summary(GzipDecompressOutput output) =>
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
                    OutlinedButton.icon(
                      key: const Key('gzip-decompress-file'),
                      autofocus: true,
                      focusNode: _fileFocus,
                      onPressed: _busy ? null : _loadFile,
                      icon: const Icon(Icons.file_open),
                      label: Text(_label('fileAction')),
                    ),
                  ),
                  if (_source case final source?) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${_label('inputByteCountLabel')}: ${source.length}',
                        key: const Key('gzip-decompress-file-summary'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ordered(
                    2,
                    Semantics(
                      label: _label('modeLabel'),
                      child: SegmentedButton<GzipDecompressMode>(
                        key: const Key('gzip-decompress-mode'),
                        segments: [
                          ButtonSegment(
                            value: GzipDecompressMode.text,
                            label: Text(
                              _label('textMode'),
                              key: const Key('gzip-decompress-mode-text'),
                            ),
                          ),
                          ButtonSegment(
                            value: GzipDecompressMode.binary,
                            label: Text(
                              _label('binaryMode'),
                              key: const Key('gzip-decompress-mode-binary'),
                            ),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: _busy ? null : _modeChanged,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ordered(
                    3,
                    ElevatedButton(
                      key: const Key('gzip-decompress-submit'),
                      onPressed: _busy ? null : _decompress,
                      child: Text(_label('submitAction')),
                    ),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('gzip-decompress-error'),
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
                        key: const Key('gzip-decompress-notice'),
                      ),
                    ),
                  ],
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    _ordered(
                      4,
                      Focus(
                        focusNode: _resultFocus,
                        child: Semantics(
                          key: const Key('gzip-decompress-result'),
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
                                if (output.text case final text?) ...[
                                  const SizedBox(height: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 320,
                                    ),
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        text,
                                        key: const Key('gzip-decompress-text'),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (output.text != null) ...[
                      const SizedBox(height: 8),
                      _ordered(
                        5,
                        OutlinedButton.icon(
                          key: const Key('gzip-decompress-copy'),
                          onPressed: _busy ? null : _copy,
                          icon: const Icon(Icons.copy),
                          label: Text(_label('copyAction')),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _ordered(
                      6,
                      OutlinedButton.icon(
                        key: const Key('gzip-decompress-save'),
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
