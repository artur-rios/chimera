import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
// The public web library imports browser-only SDKs into native builds.
// ignore: implementation_imports
import 'package:file_picker_web/src/file_picker_web_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'empty_file_save.dart';

typedef QrDecodeFilePicker = Future<List<int>?> Function();
typedef QrDecodeClipboardWriter = Future<void> Function(String value);
typedef QrDecodeFileSaver = Future<bool> Function(
  String name,
  Uint8List bytes,
  String mimeType,
);

final class _QrDecodeInputLimit implements Exception {
  const _QrDecodeInputLimit();
}

void _clearBytes(List<int>? bytes) {
  if (bytes == null) return;
  try {
    bytes.fillRange(0, bytes.length, 0);
  } on Object {
    // Immutable collaborator bytes are released by dropping their references.
  }
}

Future<List<int>?> pickQrDecodeFile({
  Future<PlatformFile?> Function(FilePickerWebOptions options)?
  pickPlatformFile,
}) async {
  final file = await (pickPlatformFile ?? _pickPlatformFile)(
    // Pinned file_picker_web otherwise eagerly reads the full selected file.
    // ignore: deprecated_member_use
    const FilePickerWebOptions(withData: false, withReadStream: true),
  );
  if (file == null) return null;
  final length = file.lengthSync();
  if (length != null && length > QrDecoder.defaultMaxInputBytes) {
    throw const _QrDecodeInputLimit();
  }
  final bytes = <int>[];
  try {
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > QrDecoder.defaultMaxInputBytes) {
        throw const _QrDecodeInputLimit();
      }
      bytes.addAll(chunk);
    }
    return bytes;
  } on Object {
    _clearBytes(bytes);
    rethrow;
  }
}

Future<PlatformFile?> _pickPlatformFile(FilePickerWebOptions options) =>
    FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp'],
      webOptions: options,
    );

Future<void> writeQrDecodeClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

Future<bool> saveQrDecodeFile(
  String name,
  Uint8List bytes,
  String mimeType,
) async {
  final emptyWebSave = await trySaveEmptyFile(name, bytes, mimeType);
  if (emptyWebSave != null) return emptyWebSave;
  final path = await FilePicker.saveFile(
    fileName: name,
    bytes: bytes,
    mimeType: mimeType,
    type: FileType.custom,
    allowedExtensions: const ['txt'],
  );
  return kIsWeb || path != null;
}

final class QrDecodePage extends StatefulWidget {
  const QrDecodePage({
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
  final QrDecodeOperationService service;
  final QrDecodeFilePicker filePicker;
  final QrDecodeClipboardWriter clipboardWriter;
  final QrDecodeFileSaver fileSaver;
  @override
  State<QrDecodePage> createState() => _QrDecodePageState();
}

final class _QrDecodePageState extends State<QrDecodePage> {
  final _fileFocus = FocusNode(debugLabel: 'QR decode file');
  final _resultFocus = FocusNode(debugLabel: 'QR decode result');
  List<int>? _source;
  List<int>? _activeBytes;
  QrDecodeOutput? _output;
  String? _error;
  String? _notice;
  var _busy = false;
  var _generation = 0;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'qrDecode.$key');
  bool _current(int generation) => mounted && generation == _generation;

  @override
  void dispose() {
    _generation++;
    _discardSource();
    _clearBytes(_activeBytes);
    _activeBytes = null;
    _output = null;
    _fileFocus.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  void _discardSource() {
    _clearBytes(_source);
    _source = null;
  }

  void _clearFeedback() {
    _output = null;
    _notice = null;
    _error = null;
  }

  int _begin({bool preserveFeedback = false}) {
    setState(() {
      _generation++;
      _busy = true;
      if (!preserveFeedback) _clearFeedback();
    });
    return _generation;
  }

  void _fail(int generation, String key) {
    if (!_current(generation)) return;
    setState(() {
      _discardSource();
      _clearFeedback();
      _busy = false;
      _error = widget.catalog.lookup(widget.localeTag, 'error.qrDecode.$key');
    });
  }

  Future<void> _loadFile() async {
    if (_busy) return;
    final generation = _begin(preserveFeedback: true);
    List<int>? bytes;
    try {
      bytes = await widget.filePicker();
      if (!_current(generation)) return;
      if (bytes != null && bytes.length > QrDecoder.defaultMaxInputBytes) {
        _fail(generation, 'resource');
        return;
      }
      setState(() {
        if (bytes != null) {
          _discardSource();
          _clearFeedback();
          _source = bytes;
          bytes = null;
        }
        _busy = false;
      });
      _fileFocus.requestFocus();
    } on _QrDecodeInputLimit {
      _fail(generation, 'resource');
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'fileAccess');
    } finally {
      _clearBytes(bytes);
    }
  }

  Future<void> _decode() async {
    if (_busy || _source == null) return;
    final generation = _begin();
    final bytes = _source!;
    _source = null;
    _activeBytes = bytes;
    try {
      final result = await widget.service.execute(
        QrDecodeOperationRequest(bytes: bytes),
      );
      if (!_current(generation)) return;
      result.fold(
        onSuccess: (output) {
          setState(() {
            _output = output;
            _busy = false;
          });
          _resultFocus.requestFocus();
        },
        onFailure: (failure) => _fail(generation, switch (failure.code) {
          'qr-decode.validation' => 'validation',
          'qr-decode.resource' => 'resource',
          _ => 'decoding',
        }),
      );
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'decoding');
    } finally {
      _clearBytes(bytes);
      if (identical(_activeBytes, bytes)) _activeBytes = null;
    }
  }

  Future<void> _copy() async {
    final output = _output;
    if (_busy || output == null) return;
    final generation = _begin(preserveFeedback: true);
    try {
      await widget.clipboardWriter(output.text);
      if (!_current(generation)) return;
      setState(() {
        _busy = false;
        _notice = _label('copied');
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
    final generation = _begin(preserveFeedback: true);
    Uint8List? bytes;
    try {
      bytes = Uint8List.fromList(utf8.encode(output.text));
      final saved = await widget.fileSaver(
        'chimera-qr-decoded.txt',
        bytes,
        'text/plain',
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
    } finally {
      _clearBytes(bytes);
    }
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
                    OutlinedButton.icon(
                      key: const Key('qr-decode-file'),
                      focusNode: _fileFocus,
                      autofocus: true,
                      onPressed: _busy ? null : _loadFile,
                      icon: const Icon(Icons.file_open),
                      label: Text(_label('fileAction')),
                    ),
                  ),
                  if (_source != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _label('inputReady'),
                        key: const Key('qr-decode-input-ready'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ordered(
                    2,
                    ElevatedButton(
                      key: const Key('qr-decode-submit'),
                      onPressed: _busy || _source == null ? null : _decode,
                      child: Text(_label('submitAction')),
                    ),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('qr-decode-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  if (_notice case final notice?) ...[
                    const SizedBox(height: 16),
                    Semantics(liveRegion: true, child: Text(notice)),
                  ],
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    _ordered(
                      3,
                      Focus(
                        focusNode: _resultFocus,
                        child: Semantics(
                          key: const Key('qr-decode-result-semantics'),
                          container: true,
                          explicitChildNodes: true,
                          focusable: true,
                          liveRegion: true,
                          role: SemanticsRole.region,
                          label:
                              '${_label('resultLabel')} ${_label('resultSuccess')}',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 240,
                                ),
                                child: SingleChildScrollView(
                                  child: ExcludeFocus(
                                    child: SelectableText(
                                      output.text,
                                      key: const Key('qr-decode-result'),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${_label('formatLabel')}: ${output.format}',
                              ),
                              Text(
                                '${_label('dimensionsLabel')}: ${output.width} x ${output.height}',
                              ),
                              Text(
                                '${_label('inputByteCountLabel')}: ${output.inputByteCount}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ordered(
                          4,
                          OutlinedButton.icon(
                            key: const Key('qr-decode-copy'),
                            onPressed: _busy ? null : _copy,
                            icon: const Icon(Icons.copy),
                            label: Text(_label('copyAction')),
                          ),
                        ),
                        _ordered(
                          5,
                          OutlinedButton.icon(
                            key: const Key('qr-decode-save'),
                            onPressed: _busy ? null : _save,
                            icon: const Icon(Icons.save_alt),
                            label: Text(_label('saveAction')),
                          ),
                        ),
                      ],
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
