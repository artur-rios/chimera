import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';

import 'dotnet_tag_runtime.dart';

final class DotnetTagPage extends StatefulWidget {
  const DotnetTagPage({super.key, this.localeTag = 'en', this.service});
  final String localeTag;
  final DotnetTagOperationService? service;
  @override
  State<DotnetTagPage> createState() => _DotnetTagPageState();
}

final class _DotnetTagPageState extends State<DotnetTagPage> {
  final _project = TextEditingController(text: './src');
  final _remote = TextEditingController(text: 'origin');
  late final _service = widget.service ?? createDotnetTagService();
  OperationCancellation? _cancellation;
  bool _push = false, _busy = false;
  String? _result;
  String _message(String key) =>
      const MessageCatalog().lookup(widget.localeTag, key);
  Future<void> _create() async {
    final cancellation = OperationCancellation();
    _cancellation = cancellation;
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await _service.execute(
      DotnetTagRequest(
        project: _project.text,
        push: _push,
        remote: _remote.text,
      ),
      cancellation: cancellation,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _cancellation = null;
      _result = result.fold<String>(
        onSuccess: (value) =>
            '${_message(value.pushed ? 'dotnetTag.pushed' : 'dotnetTag.created')}: ${value.tag}',
        onFailure: (failure) =>
            '${_message(failure.messageKey)}${failure.details['tag'] is String ? '\n${failure.details['tag']}' : ''}',
      );
    });
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    _project.dispose();
    _remote.dispose();
    _result = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_message('dotnetTag.title'))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('dotnet-tag-project'),
                controller: _project,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: _message('dotnetTag.project'),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const Key('dotnet-tag-push'),
                value: _push,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _push = value),
                title: Text(_message('dotnetTag.push')),
              ),
              TextField(
                key: const Key('dotnet-tag-remote'),
                controller: _remote,
                enabled: !_busy && _push,
                decoration: InputDecoration(
                  labelText: _message('dotnetTag.remote'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('dotnet-tag-create'),
                onPressed: _busy ? null : _create,
                child: Text(
                  _message(_busy ? 'dotnetTag.busy' : 'dotnetTag.create'),
                ),
              ),
              if (_busy)
                TextButton(
                  key: const Key('dotnet-tag-cancel'),
                  onPressed: () => _cancellation?.cancel(),
                  child: Text(_message('dotnetTag.cancel')),
                ),
              if (_result != null) ...[
                const SizedBox(height: 16),
                Semantics(liveRegion: true, child: SelectableText(_result!)),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
