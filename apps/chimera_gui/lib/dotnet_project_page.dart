import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';

import 'dotnet_project_runtime.dart';

final class DotnetProjectPage extends StatefulWidget {
  const DotnetProjectPage({super.key, this.localeTag = 'en', this.service});
  final String localeTag;
  final DotnetProjectOperationService? service;
  @override
  State<DotnetProjectPage> createState() => _DotnetProjectPageState();
}

final class _DotnetProjectPageState extends State<DotnetProjectPage> {
  final _name = TextEditingController();
  final _parent = TextEditingController(text: '.');
  late final _service = widget.service ?? createDotnetProjectService();
  bool _nuget = false, _busy = false;
  String? _result;
  String _message(String key) =>
      const MessageCatalog().lookup(widget.localeTag, key);

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await _service.execute(
      DotnetProjectRequest(
        name: _name.text,
        parentDirectory: _parent.text,
        nuget: _nuget,
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result.fold<String>(
        onSuccess: (value) =>
            '${_message('scaffold.created')}: ${value.scaffold.createdPaths.single}\n${value.mode}',
        onFailure: (failure) => _message(failure.messageKey),
      );
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _parent.dispose();
    _result = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_message('dotnetProject.title'))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_message('scaffold.description')),
              TextField(
                key: const Key('dotnet-project-name'),
                controller: _name,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: _message('dotnetProject.name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('dotnet-project-parent'),
                controller: _parent,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: _message('dotnetProject.parent'),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const Key('dotnet-project-nuget'),
                value: _nuget,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _nuget = value;
                        _result = null;
                      }),
                title: Text(_message('dotnetProject.nuget')),
                subtitle: Text(_message('dotnetProject.minimal')),
              ),
              FilledButton(
                key: const Key('dotnet-project-create'),
                onPressed: _busy ? null : _create,
                child: Text(
                  _message(_busy ? 'scaffold.working' : 'dotnetProject.create'),
                ),
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
