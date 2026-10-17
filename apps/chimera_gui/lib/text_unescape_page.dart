import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef TextUnescapeFilePicker = Future<String?> Function();
typedef TextUnescapeFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef TextUnescapeClipboardReader = Future<String?> Function();
typedef TextUnescapeClipboardWriter = Future<void> Function(String value);

Future<String?> pickTextUnescapeFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

Future<bool> saveTextUnescapeFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'text/plain',
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return uri != null;
}

Future<String?> readTextUnescapeClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeTextUnescapeClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class TextUnescapePage extends StatefulWidget {
  const TextUnescapePage({
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
  final TextUnescapeService service;
  final TextUnescapeFilePicker filePicker;
  final TextUnescapeFileSaver fileSaver;
  final TextUnescapeClipboardReader clipboardReader;
  final TextUnescapeClipboardWriter clipboardWriter;

  @override
  State<TextUnescapePage> createState() => _TextUnescapePageState();
}

final class _TextUnescapePageState extends State<TextUnescapePage> {
  late final TextEditingController _inputController;
  TextUnescapeOutput? _output;
  String? _error;
  String? _notice;
  String _mode = 'json';
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: r'Hello, \"Chimera\"!');
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
      TextUnescapeOperationRequest(input: _inputController.text, mode: _mode),
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
      _loadInput(widget.filePicker, errorKey: 'error.textUnescape.fileAccess');

  Future<void> _paste() => _loadInput(
    widget.clipboardReader,
    errorKey: 'error.textUnescape.clipboardRead',
  );

  Future<void> _loadInput(
    Future<String?> Function() loader, {
    required String errorKey,
  }) async {
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
    if (output == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.clipboardWriter(output.unescaped);
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _notice = _message('textUnescape.copiedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.textUnescape.clipboardWrite');
      });
    }
  }

  Future<void> _save() async {
    final output = _output;
    if (output == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      final saved = await widget.fileSaver(
        'chimera-unescaped-text.txt',
        utf8.encode(output.unescaped),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('textUnescape.savedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.textUnescape.outputAccess');
      });
    }
  }

  void _selectMode(String? value) {
    if (value == null) return;
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
      appBar: AppBar(title: Text(_message('textUnescape.pageTitle'))),
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
                    key: const Key('text-unescape-input'),
                    controller: _inputController,
                    autofocus: true,
                    enabled: !_isRunning,
                    minLines: 3,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) {
                      if (!_isRunning) setState(_clearFeedback);
                    },
                    decoration: InputDecoration(
                      labelText: _message('textUnescape.inputLabel'),
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
                        key: const Key('text-unescape-file'),
                        onPressed: _isRunning ? null : _loadFile,
                        icon: const Icon(Icons.file_open),
                        label: Text(_message('textUnescape.fileAction')),
                      ),
                      OutlinedButton.icon(
                        key: const Key('text-unescape-paste'),
                        onPressed: _isRunning ? null : _paste,
                        icon: const Icon(Icons.content_paste),
                        label: Text(_message('textUnescape.pasteAction')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: const Key('text-unescape-mode'),
                    initialValue: _mode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _message('textUnescape.modeLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: TextUnescaper.supportedModes
                        .map(
                          (mode) => DropdownMenuItem<String>(
                            value: mode,
                            child: Text(_message('textUnescape.mode.$mode')),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isRunning ? null : _selectMode,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('text-unescape-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('textUnescape.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('text-unescape-error'),
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
                      key: const Key('text-unescape-result-semantics'),
                      liveRegion: true,
                      label: _message('textUnescape.resultLabel'),
                      value: output.unescaped,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          output.unescaped,
                          key: const Key('text-unescape-result'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          key: const Key('text-unescape-copy'),
                          onPressed: _isRunning ? null : _copy,
                          icon: const Icon(Icons.copy),
                          label: Text(_message('textUnescape.copyAction')),
                        ),
                        OutlinedButton.icon(
                          key: const Key('text-unescape-save'),
                          onPressed: _isRunning ? null : _save,
                          icon: const Icon(Icons.save_alt),
                          label: Text(_message('textUnescape.saveAction')),
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
