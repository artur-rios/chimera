import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'dotnet_scaffold_runtime.dart';

typedef DotnetParameterPicker = Future<String?> Function();
Future<String?> pickDotnetParameters() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (file == null) return null;
  final length = await file.length();
  if (length != null && length > 65536) throw const FormatException();
  return utf8.decode(await file.readAsBytes());
}

final class DotnetLibraryPage extends StatefulWidget {
  const DotnetLibraryPage({
    this.localeTag = 'en',
    this.service,
    this.parameterPicker,
    super.key,
  });
  final String localeTag;
  final DotnetScaffoldOperationService? service;
  final DotnetParameterPicker? parameterPicker;
  @override
  State<DotnetLibraryPage> createState() => _DotnetLibraryPageState();
}

final class _DotnetLibraryPageState extends State<DotnetLibraryPage> {
  final _fields = <String, TextEditingController>{
    for (final key in [
      'RootFolder',
      'SolutionName',
      'ProjectName',
      'Author',
      'Company',
      'Description',
      'Version',
      'PackageId',
      'RepositoryUrl',
    ])
      key: TextEditingController(text: key == 'Version' ? '0.1.0' : ''),
  };
  late final _service = widget.service ?? createNugetLibraryScaffoldService();
  bool _jsonMode = false;
  bool _busy = false;
  String? _parameters;
  String? _result;
  Set<String> _invalidFields = {};
  String _message(String key) =>
      const MessageCatalog().lookup(widget.localeTag, key);
  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final parameters =
          await (widget.parameterPicker ?? pickDotnetParameters)();
      if (!mounted) return;
      if (parameters != null) {
        setState(() {
          _parameters = parameters;
          _result = _message('dotnetScaffold.jsonLoaded');
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _parameters = null;
          _result = _message('error.dotnetScaffold.inputAccess');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _create() async {
    if (_jsonMode && _parameters == null) {
      setState(() {
        _result = _message('error.dotnetScaffold.jsonRequired');
      });
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
      _invalidFields = {};
    });
    final result = await _service.execute(
      DotnetScaffoldRequest(
        fields: _jsonMode
            ? const {}
            : {
                for (final entry in _fields.entries)
                  entry.key: entry.value.text,
              },
        parametersJson: _jsonMode ? _parameters : null,
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result.fold(
        onSuccess: (output) =>
            '${_message('dotnetScaffold.created')}: ${output.destination}\n${output.templateVersion}\n${output.createdPaths.join('\n')}',
        onFailure: (failure) {
          final fields = failure.details['fields'];
          if (fields is List) {
            _invalidFields = fields.whereType<String>().toSet();
          }
          return '${_message(failure.messageKey)}${_jsonMode && _invalidFields.isNotEmpty ? '\n${_invalidFields.map((field) => _message('dotnetScaffold.field.$field')).join('\n')}' : ''}';
        },
      );
    });
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _parameters = null;
    _result = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_message('dotnetScaffold.title'))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_message('dotnetScaffold.description')),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(_message('dotnetScaffold.fieldsMode')),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(_message('dotnetScaffold.jsonMode')),
                  ),
                ],
                selected: {_jsonMode},
                onSelectionChanged: _busy
                    ? null
                    : (selection) => setState(() {
                        _jsonMode = selection.single;
                        _result = null;
                        _invalidFields = {};
                      }),
              ),
              const SizedBox(height: 16),
              if (_jsonMode)
                OutlinedButton(
                  key: const Key('dotnet-library-pick-json'),
                  onPressed: _busy ? null : _pick,
                  child: Text(_message('dotnetScaffold.pickJson')),
                )
              else
                for (final entry in _fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      key: Key('dotnet-library-${entry.key}'),
                      controller: entry.value,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: _message(
                          'dotnetScaffold.field.${entry.key}',
                        ),
                        errorText: _invalidFields.contains(entry.key)
                            ? _message('dotnetScaffold.invalidField')
                            : null,
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('dotnet-library-create'),
                onPressed: _busy ? null : _create,
                child: Text(
                  _message(
                    _busy ? 'dotnetScaffold.working' : 'dotnetScaffold.create',
                  ),
                ),
              ),
              if (_result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: SelectableText(_result!),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
