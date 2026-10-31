import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef TextTransformFilePicker = Future<String?> Function();
typedef TextTransformFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef TextTransformClipboardReader = Future<String?> Function();
typedef TextTransformClipboardWriter = Future<void> Function(String value);

Future<String?> pickTextTransformFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

Future<bool> saveTextTransformFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'text/plain',
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return uri != null;
}

Future<String?> readTextTransformClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeTextTransformClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class TextTransformPage extends StatefulWidget {
  const TextTransformPage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.fileSaver,
    required this.clipboardReader,
    required this.clipboardWriter,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final TextTransformService service;
  final TextTransformFilePicker filePicker;
  final TextTransformFileSaver fileSaver;
  final TextTransformClipboardReader clipboardReader;
  final TextTransformClipboardWriter clipboardWriter;

  @override
  State<TextTransformPage> createState() => _TextTransformPageState();
}

final class _TextTransformPageState extends State<TextTransformPage> {
  late final TextEditingController _inputController;
  TextTransformOutput? _output;
  String? _error;
  String? _notice;
  String _mode = TextTransformMode.lowercase.slug;
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: 'Hello, Chimera!');
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearFeedback();
    });
    final result = await widget.service.execute(
      TextTransformOperationRequest(input: _inputController.text, mode: _mode),
    );
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

  Future<void> _loadFile() =>
      _loadInput(widget.filePicker, errorKey: 'error.textTransform.fileAccess');

  Future<void> _paste() => _loadInput(
    widget.clipboardReader,
    errorKey: 'error.textTransform.clipboardRead',
  );

  Future<void> _loadInput(
    Future<String?> Function() loader, {
    required String errorKey,
  }) async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearFeedback();
    });
    try {
      final value = await loader();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (value != null) _inputController.text = value;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message(errorKey);
      });
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
      await widget.clipboardWriter(output.output);
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _notice = _message('textTransform.copiedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.textTransform.clipboardWrite');
      });
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
        'chimera-transformed-text.txt',
        utf8.encode(output.output),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('textTransform.savedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.textTransform.outputAccess');
      });
    }
  }

  void _selectMode(String? value) {
    if (_isRunning || value == null) return;
    setState(() {
      _mode = value;
      _clearFeedback();
    });
  }

  void _clearFeedback() {
    _output = null;
    _error = null;
    _notice = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('textTransform.pageTitle'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    key: const Key('text-transform-input'),
                    controller: _inputController,
                    autofocus: true,
                    enabled: !_isRunning,
                    minLines: 5,
                    maxLines: 10,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) {
                      if (!_isRunning) setState(_clearFeedback);
                    },
                    decoration: InputDecoration(
                      labelText: _message('textTransform.inputLabel'),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const Key('text-transform-file'),
                        onPressed: _isRunning ? null : _loadFile,
                        icon: const Icon(Icons.file_open),
                        label: Text(_message('textTransform.fileAction')),
                      ),
                      OutlinedButton.icon(
                        key: const Key('text-transform-paste'),
                        onPressed: _isRunning ? null : _paste,
                        icon: const Icon(Icons.content_paste),
                        label: Text(_message('textTransform.pasteAction')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: const Key('text-transform-mode'),
                    initialValue: _mode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _message('textTransform.modeLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: TextTransformMode.values
                        .map(
                          (mode) => DropdownMenuItem<String>(
                            value: mode.slug,
                            child: Text(
                              _message('textTransform.mode.${mode.slug}'),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isRunning ? null : _selectMode,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('text-transform-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('textTransform.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('text-transform-error'),
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
                    Semantics(
                      key: const Key('text-transform-result-semantics'),
                      liveRegion: true,
                      label: _message('textTransform.outputLabel'),
                      value: output.output,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          output.output,
                          key: const Key('text-transform-result'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          key: const Key('text-transform-copy'),
                          onPressed: _isRunning ? null : _copy,
                          icon: const Icon(Icons.copy),
                          label: Text(_message('textTransform.copyAction')),
                        ),
                        OutlinedButton.icon(
                          key: const Key('text-transform-save'),
                          onPressed: _isRunning ? null : _save,
                          icon: const Icon(Icons.save_alt),
                          label: Text(_message('textTransform.saveAction')),
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
    );
  }
}
