import 'dart:convert';
import 'dart:typed_data';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

typedef JsonYamlFilePicker = Future<String?> Function();
typedef JsonYamlFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);

Future<String?> pickJsonYamlFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['json', 'txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

Future<bool> saveJsonYamlFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'application/yaml',
    type: FileType.custom,
    allowedExtensions: const <String>['yaml', 'yml'],
  );
  return uri != null;
}

final class JsonYamlPage extends StatefulWidget {
  const JsonYamlPage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.fileSaver,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final JsonYamlService service;
  final JsonYamlFilePicker filePicker;
  final JsonYamlFileSaver fileSaver;

  @override
  State<JsonYamlPage> createState() => _JsonYamlPageState();
}

final class _JsonYamlPageState extends State<JsonYamlPage> {
  late final TextEditingController _inputController;
  JsonYamlOutput? _output;
  String? _error;
  String? _notice;
  int _indent = 2;
  bool _quoteStrings = false;
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
      JsonYamlOperationRequest(
        source: _inputController.text,
        indent: _indent,
        quoteStrings: _quoteStrings,
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
          final location = failure.details['offset'];
          _error = location == null
              ? _message(failure.messageKey)
              : '${_message(failure.messageKey)} '
                    '${_message('jsonYaml.locationLabel')}: $location';
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
        _error = _message('error.jsonYaml.fileAccess');
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
        'chimera.yaml',
        utf8.encode(output.yaml),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('jsonYaml.savedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _error = _message('error.jsonYaml.outputAccess');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('jsonYaml.pageTitle'))),
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
                    key: const Key('json-yaml-input'),
                    controller: _inputController,
                    minLines: 5,
                    maxLines: 14,
                    decoration: InputDecoration(
                      labelText: _message('jsonYaml.inputLabel'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('json-yaml-file'),
                    onPressed: _isRunning ? null : _loadFile,
                    icon: const Icon(Icons.file_open),
                    label: Text(_message('jsonYaml.fileAction')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: const Key('json-yaml-indent'),
                    initialValue: _indent,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _message('jsonYaml.indentLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: <int>[2, 4]
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text(
                              _message('jsonYaml.indent.$value'),
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
                  CheckboxListTile(
                    key: const Key('json-yaml-quote-strings'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(_message('jsonYaml.quoteStringsLabel')),
                    value: _quoteStrings,
                    onChanged: _isRunning
                        ? null
                        : (value) =>
                              setState(() => _quoteStrings = value ?? false),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('json-yaml-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('jsonYaml.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('json-yaml-error'),
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
                      key: const Key('json-yaml-result-semantics'),
                      liveRegion: true,
                      label: _message('jsonYaml.resultLabel'),
                      value: output.yaml,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          output.yaml,
                          key: const Key('json-yaml-result'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('json-yaml-save'),
                      onPressed: _isRunning ? null : _save,
                      icon: const Icon(Icons.save_alt),
                      label: Text(_message('jsonYaml.saveAction')),
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
