import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

typedef JsonTableFilePicker = Future<String?> Function();

Future<String?> pickJsonTableFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['json', 'txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

final class JsonTablePage extends StatefulWidget {
  const JsonTablePage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final JsonTableService service;
  final JsonTableFilePicker filePicker;

  @override
  State<JsonTablePage> createState() => _JsonTablePageState();
}

final class _JsonTablePageState extends State<JsonTablePage> {
  late final TextEditingController _inputController;
  JsonTableOutput? _output;
  String? _error;
  bool _includeRowNumbers = false;
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
    });
    final result = await widget.service.execute(
      JsonTableOperationRequest(
        source: _inputController.text,
        includeRowNumbers: _includeRowNumbers,
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
                    '${_message('jsonTable.locationLabel')}: $location';
          return null;
        },
      );
    });
  }

  Future<void> _loadFile() async {
    setState(() {
      _isRunning = true;
      _error = null;
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
        _error = _message('error.jsonTable.fileAccess');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('jsonTable.pageTitle'))),
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
                    key: const Key('json-table-input'),
                    controller: _inputController,
                    minLines: 5,
                    maxLines: 14,
                    decoration: InputDecoration(
                      labelText: _message('jsonTable.inputLabel'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('json-table-file'),
                    onPressed: _isRunning ? null : _loadFile,
                    icon: const Icon(Icons.file_open),
                    label: Text(_message('jsonTable.fileAction')),
                  ),
                  CheckboxListTile(
                    key: const Key('json-table-row-numbers'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(_message('jsonTable.rowNumbersLabel')),
                    value: _includeRowNumbers,
                    onChanged: _isRunning
                        ? null
                        : (value) => setState(
                            () => _includeRowNumbers = value ?? false,
                          ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('json-table-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('jsonTable.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('json-table-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  if (_output case final output?) ...<Widget>[
                    const SizedBox(height: 24),
                    _JsonTableResult(
                      output: output,
                      rowNumberLabel: _message('jsonTable.rowNumberLabel'),
                      rowCountLabel: _message('jsonTable.rowCountLabel'),
                      emptyLabel: _message('jsonTable.emptyResult'),
                      noColumnsLabel: _message('jsonTable.noColumnsResult'),
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

final class _JsonTableResult extends StatelessWidget {
  const _JsonTableResult({
    required this.output,
    required this.rowNumberLabel,
    required this.rowCountLabel,
    required this.emptyLabel,
    required this.noColumnsLabel,
  });

  final JsonTableOutput output;
  final String rowNumberLabel;
  final String rowCountLabel;
  final String emptyLabel;
  final String noColumnsLabel;

  @override
  Widget build(BuildContext context) {
    final table = output.table;
    if (table.rows.isEmpty) {
      return Semantics(
        liveRegion: true,
        child: Text(emptyLabel, key: const Key('json-table-result')),
      );
    }
    if (table.columns.isEmpty && !table.includeRowNumbers) {
      return Semantics(
        liveRegion: true,
        child: Text(
          '$noColumnsLabel $rowCountLabel: ${table.rows.length}',
          key: const Key('json-table-result'),
        ),
      );
    }
    return Semantics(
      liveRegion: true,
      child: SingleChildScrollView(
        key: const Key('json-table-result'),
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: <DataColumn>[
            if (table.includeRowNumbers)
              DataColumn(label: Text(rowNumberLabel)),
            for (final column in table.columns) DataColumn(label: Text(column)),
          ],
          rows: <DataRow>[
            for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
              DataRow(
                cells: <DataCell>[
                  if (table.includeRowNumbers)
                    DataCell(Text('${rowIndex + 1}')),
                  for (final cell in table.rows[rowIndex]) DataCell(Text(cell)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
