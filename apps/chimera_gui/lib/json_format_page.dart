import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef JsonFormatFilePicker = Future<String?> Function();
typedef JsonFormatFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef JsonFormatClipboardReader = Future<String?> Function();
typedef JsonFormatClipboardWriter = Future<void> Function(String value);

Future<String?> pickJsonFormatFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['json', 'txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

Future<bool> saveJsonFormatFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'application/json',
    type: FileType.custom,
    allowedExtensions: const <String>['json'],
  );
  return uri != null;
}

Future<String?> readJsonFormatClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeJsonFormatClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class JsonFormatPage extends StatefulWidget {
  const JsonFormatPage({
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
  final JsonFormatService service;
  final JsonFormatFilePicker filePicker;
  final JsonFormatFileSaver fileSaver;
  final JsonFormatClipboardReader clipboardReader;
  final JsonFormatClipboardWriter clipboardWriter;

  @override
  State<JsonFormatPage> createState() => _JsonFormatPageState();
}

final class _JsonFormatPageState extends State<JsonFormatPage> {
  late final TextEditingController _inputController;
  JsonFormatOutput? _output;
  String? _error;
  String? _notice;
  int _indent = 2;
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: '{}');
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isRunning = true;
      _output = null;
      _error = null;
      _notice = null;
    });
    final result = await widget.service.execute(
      JsonFormatOperationRequest(
        source: _inputController.text,
        indent: _indent,
      ),
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
          final parts = <String>[_message(failure.messageKey)];
          if (failure.details['offset'] case final offset?) {
            parts.add('${_message('jsonFormat.locationLabel')}: $offset');
          }
          if (failure.details['reason'] case final String reason) {
            parts.add(
              '${_message('jsonFormat.reasonLabel')}: '
              '${_message('jsonFormat.reason.$reason')}',
            );
          }
          _error = parts.join(' ');
          return null;
        },
      );
    });
  }

  Future<void> _loadFile() async {
    await _loadInput(
      widget.filePicker,
      errorKey: 'error.jsonFormat.fileAccess',
    );
  }

  Future<void> _paste() async {
    await _loadInput(
      widget.clipboardReader,
      errorKey: 'error.jsonFormat.clipboardRead',
    );
  }

  Future<void> _loadInput(
    Future<String?> Function() loader, {
    required String errorKey,
  }) async {
    setState(() {
      _isRunning = true;
      _output = null;
      _error = null;
      _notice = null;
    });
    try {
      final source = await loader();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (source != null) _inputController.text = source;
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
      await widget.clipboardWriter(output.formatted);
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _notice = _message('jsonFormat.copiedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.jsonFormat.clipboardWrite');
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
        'chimera-formatted.json',
        utf8.encode(output.formatted),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('jsonFormat.savedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.jsonFormat.outputAccess');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('jsonFormat.pageTitle'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    key: const Key('json-format-input'),
                    controller: _inputController,
                    minLines: 5,
                    maxLines: 14,
                    decoration: InputDecoration(
                      labelText: _message('jsonFormat.inputLabel'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('json-format-file'),
                    onPressed: _isRunning ? null : _loadFile,
                    icon: const Icon(Icons.file_open),
                    label: Text(_message('jsonFormat.fileAction')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('json-format-paste'),
                    onPressed: _isRunning ? null : _paste,
                    icon: const Icon(Icons.content_paste),
                    label: Text(_message('jsonFormat.pasteAction')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: const Key('json-format-indent'),
                    initialValue: _indent,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _message('jsonFormat.indentLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: <int>[2, 4]
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text(
                              _message('jsonFormat.indent.$value'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isRunning
                        ? null
                        : (value) => setState(() {
                            if (value != null) _indent = value;
                          }),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('json-format-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('jsonFormat.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('json-format-error'),
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
                      key: const Key('json-format-result-semantics'),
                      liveRegion: true,
                      label: _message('jsonFormat.resultLabel'),
                      value: output.formatted,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          output.formatted,
                          key: const Key('json-format-result'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('json-format-copy'),
                      onPressed: _isRunning ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: Text(_message('jsonFormat.copyAction')),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('json-format-save'),
                      onPressed: _isRunning ? null : _save,
                      icon: const Icon(Icons.save_alt),
                      label: Text(_message('jsonFormat.saveAction')),
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
