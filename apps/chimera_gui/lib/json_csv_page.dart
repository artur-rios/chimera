import 'dart:convert';
import 'dart:typed_data';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

typedef JsonCsvFilePicker = Future<String?> Function();
typedef JsonCsvFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);

Future<String?> pickJsonCsvFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['json', 'txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

Future<bool> saveJsonCsvFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'text/csv',
    type: FileType.custom,
    allowedExtensions: const <String>['csv'],
  );
  return uri != null;
}

final class JsonCsvPage extends StatefulWidget {
  const JsonCsvPage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.fileSaver,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final JsonCsvService service;
  final JsonCsvFilePicker filePicker;
  final JsonCsvFileSaver fileSaver;

  @override
  State<JsonCsvPage> createState() => _JsonCsvPageState();
}

final class _JsonCsvPageState extends State<JsonCsvPage> {
  late final TextEditingController _inputController;
  JsonCsvOutput? _output;
  String? _error;
  String? _notice;
  String _delimiter = 'comma';
  bool _includeHeaders = true;
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: '[]');
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
      JsonCsvOperationRequest(
        source: _inputController.text,
        delimiter: _delimiter,
        includeHeaders: _includeHeaders,
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
          final location = failure.details['path'] ?? failure.details['offset'];
          _error = location == null
              ? _message(failure.messageKey)
              : '${_message(failure.messageKey)} '
                    '${_message('jsonCsv.locationLabel')}: $location';
          return null;
        },
      );
    });
  }

  Future<void> _loadFile() async {
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      final source = await widget.filePicker();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (source != null) _inputController.text = source;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _error = _message('error.jsonCsv.fileAccess');
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
        'chimera.csv',
        utf8.encode(output.csv),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('jsonCsv.savedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _error = _message('error.jsonCsv.outputAccess');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('jsonCsv.pageTitle'))),
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
                    key: const Key('json-csv-input'),
                    controller: _inputController,
                    minLines: 5,
                    maxLines: 14,
                    decoration: InputDecoration(
                      labelText: _message('jsonCsv.inputLabel'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('json-csv-file'),
                    onPressed: _isRunning ? null : _loadFile,
                    icon: const Icon(Icons.file_open),
                    label: Text(_message('jsonCsv.fileAction')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: const Key('json-csv-delimiter'),
                    initialValue: _delimiter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _message('jsonCsv.delimiterLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: <String>['comma', 'semicolon', 'tab', 'pipe']
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              _message('jsonCsv.delimiter.$value'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isRunning
                        ? null
                        : (value) => setState(() {
                            if (value != null) _delimiter = value;
                          }),
                  ),
                  CheckboxListTile(
                    key: const Key('json-csv-headers'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(_message('jsonCsv.headersLabel')),
                    value: _includeHeaders,
                    onChanged: _isRunning
                        ? null
                        : (value) =>
                              setState(() => _includeHeaders = value ?? true),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('json-csv-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('jsonCsv.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('json-csv-error'),
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
                      key: const Key('json-csv-result-semantics'),
                      liveRegion: true,
                      label: _message('jsonCsv.resultLabel'),
                      value: output.csv,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          output.csv.isEmpty
                              ? _message('jsonCsv.emptyResult')
                              : output.csv,
                          key: const Key('json-csv-result'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('json-csv-save'),
                      onPressed: _isRunning ? null : _save,
                      icon: const Icon(Icons.save_alt),
                      label: Text(_message('jsonCsv.saveAction')),
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
