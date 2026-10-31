import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef SqlFormatFilePicker = Future<String?> Function();
typedef SqlFormatFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef SqlFormatClipboardReader = Future<String?> Function();
typedef SqlFormatClipboardWriter = Future<void> Function(String value);

Future<String?> pickSqlFormatFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['sql', 'txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

Future<bool> saveSqlFormatFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'application/sql',
    type: FileType.custom,
    allowedExtensions: const <String>['sql'],
  );
  return uri != null;
}

Future<String?> readSqlFormatClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeSqlFormatClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class SqlFormatPage extends StatefulWidget {
  const SqlFormatPage({
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
  final SqlFormatService service;
  final SqlFormatFilePicker filePicker;
  final SqlFormatFileSaver fileSaver;
  final SqlFormatClipboardReader clipboardReader;
  final SqlFormatClipboardWriter clipboardWriter;

  @override
  State<SqlFormatPage> createState() => _SqlFormatPageState();
}

final class _SqlFormatPageState extends State<SqlFormatPage> {
  late final TextEditingController _inputController;
  SqlFormatOutput? _output;
  String? _error;
  String? _notice;
  SqlDialect _dialect = SqlDialect.postgresql;
  SqlKeywordCase _keywordCase = SqlKeywordCase.upper;
  int _indent = 2;
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(
      text: 'select id,name from users where active=true;',
    );
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
      SqlFormatOperationRequest(
        source: _inputController.text,
        dialect: _dialect,
        indent: _indent,
        keywordCase: _keywordCase,
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
            parts.add('${_message('sqlFormat.locationLabel')}: $offset');
          }
          if (failure.details['reason'] case final String reason) {
            parts.add(
              '${_message('sqlFormat.reasonLabel')}: '
              '${_message('sqlFormat.reason.$reason')}',
            );
          }
          _error = parts.join(' ');
          return null;
        },
      );
    });
  }

  Future<void> _loadFile() async {
    await _loadInput(widget.filePicker, errorKey: 'error.sqlFormat.fileAccess');
  }

  Future<void> _paste() async {
    await _loadInput(
      widget.clipboardReader,
      errorKey: 'error.sqlFormat.clipboardRead',
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
        _notice = _message('sqlFormat.copiedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.sqlFormat.clipboardWrite');
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
        'chimera-formatted.sql',
        utf8.encode(output.formatted),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('sqlFormat.savedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.sqlFormat.outputAccess');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('sqlFormat.pageTitle'))),
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
                    key: const Key('sql-format-input'),
                    controller: _inputController,
                    minLines: 5,
                    maxLines: 14,
                    decoration: InputDecoration(
                      labelText: _message('sqlFormat.inputLabel'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('sql-format-file'),
                    onPressed: _isRunning ? null : _loadFile,
                    icon: const Icon(Icons.file_open),
                    label: Text(_message('sqlFormat.fileAction')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('sql-format-paste'),
                    onPressed: _isRunning ? null : _paste,
                    icon: const Icon(Icons.content_paste),
                    label: Text(_message('sqlFormat.pasteAction')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<SqlDialect>(
                    key: const Key('sql-format-dialect'),
                    initialValue: _dialect,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _message('sqlFormat.dialectLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: SqlDialect.values
                        .map(
                          (value) => DropdownMenuItem<SqlDialect>(
                            value: value,
                            child: Text(
                              _message('sqlFormat.dialect.${value.value}'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isRunning
                        ? null
                        : (value) => setState(() {
                            if (value != null) _dialect = value;
                          }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: const Key('sql-format-indent'),
                    initialValue: _indent,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _message('sqlFormat.indentLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: <int>[2, 4]
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text(
                              _message('sqlFormat.indent.$value'),
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
                  DropdownButtonFormField<SqlKeywordCase>(
                    key: const Key('sql-format-keyword-case'),
                    initialValue: _keywordCase,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _message('sqlFormat.keywordCaseLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: SqlKeywordCase.values
                        .map(
                          (value) => DropdownMenuItem<SqlKeywordCase>(
                            value: value,
                            child: Text(
                              _message('sqlFormat.keywordCase.${value.value}'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isRunning
                        ? null
                        : (value) => setState(() {
                            if (value != null) _keywordCase = value;
                          }),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('sql-format-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('sqlFormat.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('sql-format-error'),
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
                      key: const Key('sql-format-result-semantics'),
                      liveRegion: true,
                      label: _message('sqlFormat.resultLabel'),
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
                          key: const Key('sql-format-result'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('sql-format-copy'),
                      onPressed: _isRunning ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: Text(_message('sqlFormat.copyAction')),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('sql-format-save'),
                      onPressed: _isRunning ? null : _save,
                      icon: const Icon(Icons.save_alt),
                      label: Text(_message('sqlFormat.saveAction')),
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
