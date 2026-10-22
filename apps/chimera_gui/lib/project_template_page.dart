import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';

import 'scaffold_runtime.dart';

final class ProjectTemplatePage extends StatefulWidget {
  const ProjectTemplatePage({super.key, this.localeTag = 'en', this.service});
  final String localeTag;
  final ScaffoldOperationService? service;
  @override
  State<ProjectTemplatePage> createState() => _ProjectTemplatePageState();
}

final class _ProjectTemplatePageState extends State<ProjectTemplatePage> {
  final _destination = TextEditingController();
  late final _service = widget.service ?? createScaffoldService();
  String? _result;
  bool _busy = false;
  String _message(String key) =>
      const MessageCatalog().lookup(widget.localeTag, key);

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await _service.execute(
      ScaffoldRequest(destination: _destination.text),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result.fold(
        onSuccess: (value) =>
            '${_message('scaffold.created')}: ${value.destination}\n${value.templateVersion}\n${value.createdPaths.join('\n')}',
        onFailure: (failure) => _message(failure.messageKey),
      );
    });
  }

  @override
  void dispose() {
    _destination.dispose();
    _result = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_message('scaffold.title'))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_message('scaffold.description')),
              const SizedBox(height: 16),
              TextField(
                key: const Key('scaffold-destination'),
                controller: _destination,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: _message('scaffold.destination'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('scaffold-create'),
                onPressed: _busy ? null : _create,
                child: Text(
                  _message(_busy ? 'scaffold.working' : 'scaffold.create'),
                ),
              ),
              if (_result != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: SelectionArea(child: Text(_result!)),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
