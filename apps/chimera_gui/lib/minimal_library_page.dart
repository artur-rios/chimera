import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'minimal_library_runtime.dart';

typedef MinimalParametersPicker = Future<String?> Function();
const _fields = [
  'RootFolder',
  'SolutionName',
  'ProjectName',
  'Author',
  'Description',
];

class MinimalLibraryPage extends StatefulWidget {
  const MinimalLibraryPage({
    super.key,
    this.localeTag = 'en',
    this.service,
    this.parametersPicker,
    this.supported,
  });
  final String localeTag;
  final DotnetScaffoldOperationService? service;
  final MinimalParametersPicker? parametersPicker;
  final bool? supported;
  @override
  State<MinimalLibraryPage> createState() => _MinimalLibraryPageState();
}

class _MinimalLibraryPageState extends State<MinimalLibraryPage> {
  final _controllers = {
    for (final field in _fields) field: TextEditingController(),
  };
  late final _service = widget.service ?? createMinimalLibraryService();
  bool _jsonMode = false;
  bool _busy = false;
  bool _loadingParameters = false;
  String? _parametersJson;
  String? _result;
  String message(String key) =>
      const MessageCatalog().lookup(widget.localeTag, key);
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _parametersJson = null;
    _result = null;
    super.dispose();
  }

  Future<void> _loadParameters() async {
    setState(() {
      _loadingParameters = true;
      _parametersJson = null;
      _result = null;
    });
    try {
      final picker = widget.parametersPicker;
      String? content;
      if (picker != null) {
        content = await picker();
      } else {
        final file = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'JSON',
              extensions: ['json'],
              mimeTypes: ['application/json'],
            ),
          ],
        );
        if (file != null) {
          if (await file.length() > 262144) {
            throw const FormatException();
          }
          content = await file.readAsString();
        }
      }
      if (!mounted || content == null) {
        return;
      }
      setState(() {
        _parametersJson = content;
        _result = message('dotnetMinimal.parametersLoaded');
      });
    } on Object {
      if (mounted) {
        setState(() {
          _result = message('error.dotnetMinimal.parametersRead');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingParameters = false;
        });
      }
    }
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await _service.execute(
      DotnetScaffoldRequest(
        fields: _jsonMode
            ? const {}
            : {
                for (final entry in _controllers.entries)
                  entry.key: entry.value.text,
              },
        parametersJson: _jsonMode ? (_parametersJson ?? '') : null,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _result = result.fold(
        onSuccess: (value) =>
            '${message('dotnetMinimal.created')}: ${value.destination}\n${value.templateVersion}\n${value.createdPaths.join('\n')}',
        onFailure: (failure) =>
            '${message(failure.messageKey)}${failure.details['fields'] is List ? '\n${(failure.details['fields'] as List).join(', ')}' : ''}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final supported = widget.supported ?? minimalLibrarySupported;
    final enabled = supported && !_busy && !_loadingParameters;
    return Scaffold(
      appBar: AppBar(title: Text(message('dotnetMinimal.title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message('dotnetMinimal.description')),
                if (!supported) Text(message('dotnetMinimal.unsupported')),
                SwitchListTile(
                  key: const Key('dotnet-minimal-json-mode'),
                  title: Text(message('dotnetMinimal.jsonMode')),
                  value: _jsonMode,
                  onChanged: !enabled
                      ? null
                      : (value) {
                          setState(() {
                            _jsonMode = value;
                            _result = null;
                          });
                        },
                ),
                if (_jsonMode)
                  OutlinedButton(
                    key: const Key('dotnet-minimal-load-parameters'),
                    onPressed: enabled ? _loadParameters : null,
                    child: Text(message('dotnetMinimal.loadParameters')),
                  )
                else
                  for (final field in _fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        key: Key('dotnet-minimal-$field'),
                        controller: _controllers[field],
                        enabled: enabled,
                        decoration: InputDecoration(
                          labelText: message('dotnetMinimal.field.$field'),
                        ),
                      ),
                    ),
                FilledButton(
                  key: const Key('dotnet-minimal-create'),
                  onPressed: !enabled || (_jsonMode && _parametersJson == null)
                      ? null
                      : _create,
                  child: Text(
                    message(
                      _busy ? 'scaffold.working' : 'dotnetMinimal.create',
                    ),
                  ),
                ),
                if (_result != null)
                  Semantics(liveRegion: true, child: SelectableText(_result!)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
