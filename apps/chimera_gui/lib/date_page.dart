import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

typedef DateFilePicker = Future<String?> Function();

Future<String?> pickDateValueFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

final class DatePage extends StatefulWidget {
  const DatePage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final DateService service;
  final DateFilePicker filePicker;

  @override
  State<DatePage> createState() => _DatePageState();
}

final class _DatePageState extends State<DatePage> {
  late final TextEditingController _valueController;
  late final TextEditingController _sourceZoneController;
  late final TextEditingController _targetZoneController;
  late final TextEditingController _sourcePatternController;
  late final TextEditingController _targetPatternController;
  DateRepresentation _source = DateRepresentation.iso8601;
  DateRepresentation _target = DateRepresentation.iso8601;
  DateOutput? _output;
  String? _error;
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: '2026-01-15T12:30:45Z');
    _sourceZoneController = TextEditingController(text: 'UTC');
    _targetZoneController = TextEditingController(text: 'UTC');
    _sourcePatternController = TextEditingController(
      text: 'yyyy-MM-dd HH:mm:ss',
    );
    _targetPatternController = TextEditingController(
      text: 'yyyy-MM-dd HH:mm:ss',
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _sourceZoneController.dispose();
    _targetZoneController.dispose();
    _sourcePatternController.dispose();
    _targetPatternController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isRunning = true;
      _output = null;
      _error = null;
    });
    final result = await widget.service.execute(
      DateRequest(
        value: _valueController.text,
        sourceRepresentation: _source,
        targetRepresentation: _target,
        sourceTimeZone: _sourceZoneController.text,
        targetTimeZone: _targetZoneController.text,
        sourcePattern: _sourcePatternController.text,
        targetPattern: _targetPatternController.text,
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
          _error = _message(failure.messageKey);
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
      final value = await widget.filePicker();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (value != null) _valueController.text = value;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _error = _message('error.date.fileAccess');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('date.pageTitle'))),
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
                    key: const Key('date-value'),
                    controller: _valueController,
                    decoration: InputDecoration(
                      labelText: _message('date.valueLabel'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('date-file'),
                    onPressed: _isRunning ? null : _loadFile,
                    icon: const Icon(Icons.file_open),
                    label: Text(_message('date.fileAction')),
                  ),
                  const SizedBox(height: 16),
                  _representationField(
                    key: const Key('date-source-representation'),
                    value: _source,
                    label: _message('date.sourceRepresentationLabel'),
                    onChanged: (value) => setState(() => _source = value),
                  ),
                  if (_source == DateRepresentation.customPattern) ...<Widget>[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('date-source-pattern'),
                      controller: _sourcePatternController,
                      decoration: InputDecoration(
                        labelText: _message('date.sourcePatternLabel'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('date-source-time-zone'),
                    controller: _sourceZoneController,
                    decoration: InputDecoration(
                      labelText: _message('date.sourceTimeZoneLabel'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _representationField(
                    key: const Key('date-target-representation'),
                    value: _target,
                    label: _message('date.targetRepresentationLabel'),
                    onChanged: (value) => setState(() => _target = value),
                  ),
                  if (_target == DateRepresentation.customPattern) ...<Widget>[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('date-target-pattern'),
                      controller: _targetPatternController,
                      decoration: InputDecoration(
                        labelText: _message('date.targetPatternLabel'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('date-target-time-zone'),
                    controller: _targetZoneController,
                    decoration: InputDecoration(
                      labelText: _message('date.targetTimeZoneLabel'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const Key('date-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('date.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('date-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  if (_output case final output?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Column(
                        key: const Key('date-result'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            '${_message('date.resultLabel')}: ${output.conversion.convertedValue}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_message('date.utcLabel')}: ${output.conversion.utcIso8601}',
                          ),
                        ],
                      ),
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

  Widget _representationField({
    required Key key,
    required DateRepresentation value,
    required String label,
    required ValueChanged<DateRepresentation> onChanged,
  }) => DropdownButtonFormField<DateRepresentation>(
    key: key,
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: <DropdownMenuItem<DateRepresentation>>[
      for (final representation in DateRepresentation.values)
        DropdownMenuItem<DateRepresentation>(
          value: representation,
          child: Text(
            _message('date.representation.${representation.identifier}'),
          ),
        ),
    ],
    onChanged: _isRunning ? null : (selected) => onChanged(selected!),
  );
}
