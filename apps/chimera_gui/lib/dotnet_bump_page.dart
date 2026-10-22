import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';

import 'dotnet_bump_runtime.dart';

final class DotnetBumpPage extends StatefulWidget {
  const DotnetBumpPage({
    required this.catalog,
    required this.localeTag,
    this.service,
    this.supported = true,
    super.key,
  });
  final MessageCatalog catalog;
  final String localeTag;
  final OperationService<DotnetBumpRequest, DotnetBumpOutput>? service;
  final bool supported;
  @override
  State<DotnetBumpPage> createState() => _DotnetBumpPageState();
}

final class _DotnetBumpPageState extends State<DotnetBumpPage> {
  final _project = TextEditingController();
  final _version = TextEditingController();
  late final _service = widget.supported
      ? widget.service ?? createDotnetBumper()
      : null;
  String _mode = 'explicit';
  bool _busy = false;
  String? _status;
  String _message(String key) =>
      widget.catalog.lookup(widget.localeTag, 'dotnetBump.$key');
  @override
  void dispose() {
    _project.dispose();
    _version.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final service = _service;
    if (service == null || _busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    final ChimeraResult<DotnetBumpOutput> result;
    try {
      result = await service.execute(
        DotnetBumpRequest(
          project: _project.text.isEmpty ? null : _project.text,
          version: _mode == 'explicit' ? _version.text : null,
          increment: _mode == 'explicit' ? null : _mode,
        ),
      );
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = _message('access');
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result case ChimeraSuccess<DotnetBumpOutput>(:final value)) {
        _status = _message('success')
            .replaceAll('{project}', value.project)
            .replaceAll(
              '{previous}',
              value.previousVersion ?? _message('missing'),
            )
            .replaceAll('{version}', value.version);
        if (value.backupPath case final backup?) {
          _status = '$_status\n${_message('backupRetained')}: $backup';
        }
      } else {
        final failure = result as ChimeraFailure<DotnetBumpOutput>;
        _status = widget.catalog.lookup(widget.localeTag, failure.messageKey);
        if (failure.details['candidates'] case final List<Object?> candidates) {
          for (final candidate in candidates) {
            _status = '$_status\n$candidate';
          }
        }
        if (failure.details['backupPath'] case final String backup) {
          _status = '$_status\n${_message('backupRetained')}: $backup';
        }
        if (failure.details['restored'] case final bool restored) {
          _status =
              '$_status\n${_message(restored ? 'restored' : 'notRestored')}';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_message('title'))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_service == null)
                Text(_message('unsupported'))
              else ...[
                TextField(
                  key: const Key('dotnet-bump-project'),
                  controller: _project,
                  enabled: !_busy,
                  decoration: InputDecoration(labelText: _message('project')),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('dotnet-bump-mode'),
                  initialValue: _mode,
                  decoration: InputDecoration(labelText: _message('mode')),
                  items: [
                    for (final mode in ['explicit', 'major', 'minor', 'patch'])
                      DropdownMenuItem(
                        value: mode,
                        child: Text(_message(mode)),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (mode) => setState(() {
                          _mode = mode!;
                          _status = null;
                        }),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('dotnet-bump-version'),
                  controller: _version,
                  enabled: !_busy && _mode == 'explicit',
                  decoration: InputDecoration(labelText: _message('version')),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('dotnet-bump-apply'),
                  onPressed: _busy ? null : _apply,
                  child: Text(_message('apply')),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_status != null)
                  Semantics(liveRegion: true, child: SelectableText(_status!)),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
