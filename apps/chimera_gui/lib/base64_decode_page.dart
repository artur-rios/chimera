import 'dart:ui' as ui;
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef Base64DecodeFilePicker = Future<List<int>?> Function();
typedef Base64DecodeFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef Base64DecodeClipboardReader = Future<String?> Function();
typedef Base64DecodeClipboardWriter = Future<void> Function(String value);
typedef Base64DecodePreviewDecoder = Future<Base64DecodePreview?> Function(
  Uint8List bytes,
);

abstract interface class Base64DecodePreview {
  ui.Image get image;
  String get mediaType;
  void dispose();
}

final class _UiBase64DecodePreview implements Base64DecodePreview {
  _UiBase64DecodePreview(this.image, this.mediaType);

  @override
  final ui.Image image;

  @override
  final String mediaType;

  @override
  void dispose() => image.dispose();
}

Future<List<int>?> pickBase64DecodeFile() async {
  final file = await FilePicker.pickFile();
  return await file?.readAsBytes();
}

Future<bool> saveBase64DecodeFile(String fileName, List<int> bytes) async {
  final extension = fileName.split('.').last;
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    type: FileType.custom,
    allowedExtensions: <String>[extension],
  );
  return uri != null;
}

Future<String?> readBase64DecodeClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeBase64DecodeClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

Future<Base64DecodePreview?> decodeBase64Preview(Uint8List bytes) async {
  final mediaType = _candidateMediaType(bytes);
  if (mediaType == null) return null;

  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    return _UiBase64DecodePreview(frame.image, mediaType);
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

String? _candidateMediaType(Uint8List bytes) {
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  if (startsWith(const <int>[137, 80, 78, 71, 13, 10, 26, 10])) {
    return 'image/png';
  }
  if (startsWith(const <int>[255, 216, 255])) return 'image/jpeg';
  if (startsWith(const <int>[71, 73, 70, 56, 55, 97]) ||
      startsWith(const <int>[71, 73, 70, 56, 57, 97])) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      startsWith(const <int>[82, 73, 70, 70]) &&
      bytes[8] == 87 &&
      bytes[9] == 69 &&
      bytes[10] == 66 &&
      bytes[11] == 80) {
    return 'image/webp';
  }
  return null;
}

final class Base64DecodePage extends StatefulWidget {
  const Base64DecodePage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.fileSaver,
    required this.clipboardReader,
    required this.clipboardWriter,
    required this.previewDecoder,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final Base64DecodeService service;
  final Base64DecodeFilePicker filePicker;
  final Base64DecodeFileSaver fileSaver;
  final Base64DecodeClipboardReader clipboardReader;
  final Base64DecodeClipboardWriter clipboardWriter;
  final Base64DecodePreviewDecoder previewDecoder;

  @override
  State<Base64DecodePage> createState() => _Base64DecodePageState();
}

final class _Base64DecodePageState extends State<Base64DecodePage> {
  late final TextEditingController _inputController;
  late final FocusNode _resultFocusNode;
  List<int>? _fileBytes;
  Base64DecodeMode _mode = Base64DecodeMode.text;
  Base64DecodeOutput? _output;
  Base64DecodePreview? _preview;
  String? _error;
  String? _notice;
  bool _isRunning = false;
  int _generation = 0;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _resultFocusNode = FocusNode(debugLabel: 'Base64 decoded result');
  }

  @override
  void dispose() {
    _generation++;
    _disposePreview();
    _fileBytes = null;
    _inputController.dispose();
    _resultFocusNode.dispose();
    super.dispose();
  }

  void _disposePreview() {
    _preview?.dispose();
    _preview = null;
  }

  void _clearResult() {
    _generation++;
    _disposePreview();
    _output = null;
    _error = null;
    _notice = null;
  }

  Future<void> _submit() async {
    if (_isRunning) return;
    final generation = ++_generation;
    _disposePreview();
    setState(() {
      _isRunning = true;
      _output = null;
      _error = null;
      _notice = null;
    });

    final fileBytes = _fileBytes;
    final request = fileBytes == null
        ? Base64DecodeOperationRequest.text(_inputController.text, mode: _mode)
        : Base64DecodeOperationRequest.utf8Bytes(fileBytes, mode: _mode);
    final result = await widget.service.execute(request);
    if (!mounted || generation != _generation) return;

    Base64DecodeOutput? decoded;
    ChimeraFailure<Base64DecodeOutput>? failure;
    result.fold(
      onSuccess: (value) => decoded = value,
      onFailure: (value) => failure = value,
    );
    if (failure case final failed?) {
      setState(() {
        _isRunning = false;
        _error = _message(failed.messageKey);
      });
      return;
    }

    final output = decoded!;
    Base64DecodePreview? preview;
    var previewUnavailable = false;
    if (_mode == Base64DecodeMode.binary &&
        output.imageCandidateMediaType != null) {
      try {
        preview = await widget.previewDecoder(output.bytes);
        previewUnavailable = preview == null;
      } on Object {
        previewUnavailable = true;
      }
    }
    if (!mounted || generation != _generation) {
      preview?.dispose();
      return;
    }

    setState(() {
      _isRunning = false;
      _output = output;
      _preview = preview;
      if (preview != null) {
        _notice = _message('base64Decode.imageAvailable');
      } else if (previewUnavailable) {
        _notice = _message('base64Decode.imageUnavailable');
      }
    });
    _resultFocusNode.requestFocus();
  }

  Future<void> _loadFile() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearResult();
    });
    try {
      final value = await widget.filePicker();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (value != null) {
          _fileBytes = value;
          _inputController.clear();
        }
      });
    } on OutOfMemoryError {
      _adapterFailure('error.base64Decode.resource');
    } on Object {
      _adapterFailure('error.base64Decode.fileAccess');
    }
  }

  Future<void> _paste() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearResult();
    });
    try {
      final value = await widget.clipboardReader();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (value != null) {
          _fileBytes = null;
          _inputController.text = value;
        }
      });
    } on OutOfMemoryError {
      _adapterFailure('error.base64Decode.resource');
    } on Object {
      _adapterFailure('error.base64Decode.clipboardRead');
    }
  }

  Future<void> _copy() async {
    final text = _output?.text;
    if (_isRunning || text == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.clipboardWriter(text);
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _notice = _message('base64Decode.copiedResult');
      });
    } on OutOfMemoryError {
      _adapterFailure('error.base64Decode.resource');
    } on Object {
      _adapterFailure('error.base64Decode.clipboardWrite');
    }
  }

  Future<void> _save() async {
    final output = _output;
    if (_isRunning || output == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    final name = _mode == Base64DecodeMode.text
        ? 'chimera-decoded.txt'
        : 'chimera-decoded.${_previewExtension() ?? 'bin'}';
    try {
      final saved = await widget.fileSaver(name, output.bytes);
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('base64Decode.savedResult');
      });
    } on OutOfMemoryError {
      _adapterFailure('error.base64Decode.resource');
    } on Object {
      _adapterFailure('error.base64Decode.outputAccess');
    }
  }

  String? _previewExtension() => switch (_preview?.mediaType) {
    'image/png' => 'png',
    'image/jpeg' => 'jpg',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    _ => null,
  };

  void _adapterFailure(String key) {
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _generation++;
      _disposePreview();
      _output = null;
      _notice = null;
      _error = _message(key);
    });
  }

  void _textChanged(String _) {
    if (_isRunning) return;
    setState(() {
      _fileBytes = null;
      _clearResult();
    });
  }

  void _modeChanged(Base64DecodeMode mode) {
    if (_isRunning || mode == _mode) return;
    setState(() {
      _mode = mode;
      _clearResult();
    });
  }

  Widget _ordered(double order, Widget child) =>
      FocusTraversalOrder(order: NumericFocusOrder(order), child: child);

  Widget _result(Base64DecodeOutput output) {
    final imageNotice = _preview != null
        ? _message('base64Decode.imageAvailable')
        : null;
    return _ordered(
      6,
      Focus(
        focusNode: _resultFocusNode,
        child: Semantics(
          key: const Key('base64-decode-result-semantics'),
          container: true,
          focusable: true,
          liveRegion: true,
          excludeSemantics: true,
          role: SemanticsRole.region,
          label: _message('base64Decode.outputLabel'),
          value:
              '${_message('base64Decode.resultSuccess')}\n'
              '${_message('base64Decode.modeLabel')}: '
              '${_message('base64Decode.mode.${_mode.name}')}\n'
              '${_message('base64Decode.inputCharacterCountLabel')}: '
              '${output.inputCharacterCount}\n'
              '${_message('base64Decode.outputByteCountLabel')}: '
              '${output.outputByteCount}'
              '${imageNotice == null ? '' : '\n$imageNotice'}',
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _message('base64Decode.outputLabel'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_mode == Base64DecodeMode.text)
                  ExcludeSemantics(
                    child: SelectableText(
                      output.text!,
                      key: const Key('base64-decode-result'),
                    ),
                  )
                else
                  Text(
                    '${_message('base64Decode.outputByteCountLabel')}: '
                    '${output.outputByteCount}',
                    key: const Key('base64-decode-result'),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${_message('base64Decode.inputCharacterCountLabel')}: '
                  '${output.inputCharacterCount}',
                ),
                if (_mode == Base64DecodeMode.text)
                  Text(
                    '${_message('base64Decode.outputByteCountLabel')}: '
                    '${output.outputByteCount}',
                  ),
                if (_preview case final preview?) ...<Widget>[
                  const SizedBox(height: 12),
                  ExcludeSemantics(
                    child: RawImage(
                      key: const Key('base64-decode-preview'),
                      image: preview.image,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileBytes = _fileBytes;
    return Scaffold(
      appBar: AppBar(title: Text(_message('base64Decode.pageTitle'))),
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
                  children: <Widget>[
                    _ordered(
                      1,
                      TextField(
                        key: const Key('base64-decode-input'),
                        controller: _inputController,
                        autofocus: true,
                        enabled: !_isRunning,
                        minLines: 3,
                        maxLines: 8,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onChanged: _textChanged,
                        decoration: InputDecoration(
                          labelText: _message('base64Decode.inputLabel'),
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _ordered(
                          2,
                          OutlinedButton.icon(
                            key: const Key('base64-decode-file'),
                            onPressed: _isRunning ? null : _loadFile,
                            icon: const Icon(Icons.file_open),
                            label: Text(_message('base64Decode.fileAction')),
                          ),
                        ),
                        _ordered(
                          3,
                          OutlinedButton.icon(
                            key: const Key('base64-decode-paste'),
                            onPressed: _isRunning ? null : _paste,
                            icon: const Icon(Icons.content_paste),
                            label: Text(_message('base64Decode.pasteAction')),
                          ),
                        ),
                      ],
                    ),
                    if (fileBytes != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${_message('base64Decode.inputCharacterCountLabel')}: '
                          '${fileBytes.length}',
                          key: const Key('base64-decode-file-summary'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(_message('base64Decode.modeLabel')),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _ordered(
                          4,
                          ChoiceChip(
                            key: const Key('base64-decode-mode-text'),
                            label: Text(_message('base64Decode.mode.text')),
                            selected: _mode == Base64DecodeMode.text,
                            onSelected: _isRunning
                                ? null
                                : (_) => _modeChanged(Base64DecodeMode.text),
                          ),
                        ),
                        _ordered(
                          4.1,
                          ChoiceChip(
                            key: const Key('base64-decode-mode-binary'),
                            label: Text(_message('base64Decode.mode.binary')),
                            selected: _mode == Base64DecodeMode.binary,
                            onSelected: _isRunning
                                ? null
                                : (_) => _modeChanged(Base64DecodeMode.binary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ordered(
                      5,
                      ElevatedButton(
                        key: const Key('base64-decode-submit'),
                        onPressed: _isRunning ? null : _submit,
                        child: Text(_message('base64Decode.submitAction')),
                      ),
                    ),
                    if (_error case final error?) ...<Widget>[
                      const SizedBox(height: 24),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          key: const Key('base64-decode-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (_notice case final notice?) ...<Widget>[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          notice,
                          key: const Key('base64-decode-notice'),
                        ),
                      ),
                    ],
                    if (_output case final output?) ...<Widget>[
                      const SizedBox(height: 24),
                      _result(output),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (_mode == Base64DecodeMode.text)
                            _ordered(
                              7,
                              OutlinedButton.icon(
                                key: const Key('base64-decode-copy'),
                                onPressed: _isRunning ? null : _copy,
                                icon: const Icon(Icons.copy),
                                label: Text(
                                  _message('base64Decode.copyAction'),
                                ),
                              ),
                            ),
                          _ordered(
                            8,
                            OutlinedButton.icon(
                              key: const Key('base64-decode-save'),
                              onPressed: _isRunning ? null : _save,
                              icon: const Icon(Icons.save_alt),
                              label: Text(_message('base64Decode.saveAction')),
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
}
