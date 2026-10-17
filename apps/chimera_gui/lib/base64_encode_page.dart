import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef Base64EncodeFilePicker = Future<List<int>?> Function();
typedef Base64EncodeFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef Base64EncodeClipboardReader = Future<String?> Function();
typedef Base64EncodeClipboardWriter = Future<void> Function(String value);
typedef Base64EncodeOutputEncoder = List<int> Function(String value);

Future<List<int>?> pickBase64EncodeFile() async {
  final file = await FilePicker.pickFile();
  return await file?.readAsBytes();
}

Future<bool> saveBase64EncodeFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'text/plain',
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return uri != null;
}

Future<String?> readBase64EncodeClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeBase64EncodeClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

List<int> encodeBase64Output(String value) => utf8.encode(value);

final class Base64EncodePage extends StatefulWidget {
  const Base64EncodePage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.fileSaver,
    required this.clipboardReader,
    required this.clipboardWriter,
    required this.outputEncoder,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final Base64EncodeService service;
  final Base64EncodeFilePicker filePicker;
  final Base64EncodeFileSaver fileSaver;
  final Base64EncodeClipboardReader clipboardReader;
  final Base64EncodeClipboardWriter clipboardWriter;
  final Base64EncodeOutputEncoder outputEncoder;

  @override
  State<Base64EncodePage> createState() => _Base64EncodePageState();
}

final class _Base64EncodePageState extends State<Base64EncodePage> {
  late final TextEditingController _inputController;
  late final FocusNode _resultFocusNode;
  List<int>? _fileBytes;
  Base64EncodeOutput? _output;
  String? _error;
  String? _notice;
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _resultFocusNode = FocusNode(debugLabel: 'Base64 result');
  }

  @override
  void dispose() {
    _fileBytes = null;
    _inputController.dispose();
    _resultFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearFeedback();
    });
    final bytes = _fileBytes;
    final request = bytes == null
        ? Base64EncodeOperationRequest.text(_inputController.text)
        : Base64EncodeOperationRequest.bytes(bytes);
    final result = await widget.service.execute(request);
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      result.fold(
        onSuccess: (value) {
          _output = value;
          return null;
        },
        onFailure: (failure) {
          _error = _message(failure.messageKey);
          return null;
        },
      );
    });
  }

  Future<void> _loadFile() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearFeedback();
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
      _adapterFailure('error.base64Encode.resource');
    } on Object {
      _adapterFailure('error.base64Encode.fileAccess');
    }
  }

  Future<void> _paste() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearFeedback();
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
      _adapterFailure('error.base64Encode.resource');
    } on Object {
      _adapterFailure('error.base64Encode.clipboardRead');
    }
  }

  Future<void> _copy() async {
    final output = _output;
    if (_isRunning || output == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.clipboardWriter(output.encoded);
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _notice = _message('base64Encode.copiedResult');
      });
    } on OutOfMemoryError {
      _adapterFailure('error.base64Encode.resource');
    } on Object {
      _adapterFailure('error.base64Encode.clipboardWrite');
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
    try {
      final saved = await widget.fileSaver(
        'chimera-base64.txt',
        widget.outputEncoder(output.encoded),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('base64Encode.savedResult');
      });
    } on OutOfMemoryError {
      _adapterFailure('error.base64Encode.resource');
    } on Object {
      _adapterFailure('error.base64Encode.outputAccess');
    }
  }

  void _adapterFailure(String key) {
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _output = null;
      _notice = null;
      _error = _message(key);
    });
  }

  void _textChanged(String _) {
    if (_isRunning) return;
    setState(() {
      _fileBytes = null;
      _clearFeedback();
    });
  }

  void _clearFeedback() {
    _output = null;
    _error = null;
    _notice = null;
  }

  Widget _ordered(double order, Widget child) =>
      FocusTraversalOrder(order: NumericFocusOrder(order), child: child);

  Widget _result(Base64EncodeOutput output) => _ordered(
    5,
    Focus(
      focusNode: _resultFocusNode,
      child: Semantics(
        key: const Key('base64-encode-result-semantics'),
        container: true,
        focusable: true,
        liveRegion: true,
        excludeSemantics: true,
        role: SemanticsRole.region,
        label: _message('base64Encode.outputLabel'),
        value:
            '${_message('base64Encode.resultSuccess')}\n'
            '${_message('base64Encode.inputByteCountLabel')}: '
            '${output.inputByteCount}\n'
            '${_message('base64Encode.outputCharacterCountLabel')}: '
            '${output.outputCharacterCount}',
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
                _message('base64Encode.outputLabel'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: SelectableText(
                  output.encoded,
                  key: const Key('base64-encode-result'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_message('base64Encode.inputByteCountLabel')}: '
                '${output.inputByteCount}',
              ),
              Text(
                '${_message('base64Encode.outputCharacterCountLabel')}: '
                '${output.outputCharacterCount}',
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fileBytes = _fileBytes;
    return Scaffold(
      appBar: AppBar(title: Text(_message('base64Encode.pageTitle'))),
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
                        key: const Key('base64-encode-input'),
                        controller: _inputController,
                        autofocus: true,
                        enabled: !_isRunning,
                        minLines: 3,
                        maxLines: 8,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onChanged: _textChanged,
                        decoration: InputDecoration(
                          labelText: _message('base64Encode.inputLabel'),
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
                            key: const Key('base64-encode-file'),
                            onPressed: _isRunning ? null : _loadFile,
                            icon: const Icon(Icons.file_open),
                            label: Text(_message('base64Encode.fileAction')),
                          ),
                        ),
                        _ordered(
                          3,
                          OutlinedButton.icon(
                            key: const Key('base64-encode-paste'),
                            onPressed: _isRunning ? null : _paste,
                            icon: const Icon(Icons.content_paste),
                            label: Text(_message('base64Encode.pasteAction')),
                          ),
                        ),
                      ],
                    ),
                    if (fileBytes != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${_message('base64Encode.inputByteCountLabel')}: '
                          '${fileBytes.length}',
                          key: const Key('base64-encode-file-summary'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _ordered(
                      4,
                      ElevatedButton(
                        key: const Key('base64-encode-submit'),
                        onPressed: _isRunning ? null : _submit,
                        child: Text(_message('base64Encode.submitAction')),
                      ),
                    ),
                    if (_error case final error?) ...<Widget>[
                      const SizedBox(height: 24),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          key: const Key('base64-encode-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (_notice case final notice?) ...<Widget>[
                      const SizedBox(height: 16),
                      Semantics(liveRegion: true, child: Text(notice)),
                    ],
                    if (_output case final output?) ...<Widget>[
                      const SizedBox(height: 24),
                      _result(output),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _ordered(
                            6,
                            OutlinedButton.icon(
                              key: const Key('base64-encode-copy'),
                              onPressed: _isRunning ? null : _copy,
                              icon: const Icon(Icons.copy),
                              label: Text(_message('base64Encode.copyAction')),
                            ),
                          ),
                          _ordered(
                            7,
                            OutlinedButton.icon(
                              key: const Key('base64-encode-save'),
                              onPressed: _isRunning ? null : _save,
                              icon: const Icon(Icons.save_alt),
                              label: Text(_message('base64Encode.saveAction')),
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
