import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';

import 'dotnet_clean_runtime.dart';

final class DotnetCleanPage extends StatefulWidget {
  const DotnetCleanPage({
    required this.catalog,
    required this.localeTag,
    this.service,
    this.supported = true,
    super.key,
  });
  final MessageCatalog catalog;
  final String localeTag;
  final DotnetCleanService? service;
  final bool supported;
  @override
  State<DotnetCleanPage> createState() => _DotnetCleanPageState();
}

final class _DotnetCleanPageState extends State<DotnetCleanPage> {
  final _root = TextEditingController();
  late final DotnetCleanService? _service = widget.supported
      ? widget.service ?? createDotnetCleaner()
      : null;
  DotnetCleanPreview? _preview;
  String? _status;
  bool _busy = false;
  String _message(String key) =>
      widget.catalog.lookup(widget.localeTag, 'dotnetClean.$key');
  @override
  void dispose() {
    _root.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final service = _service;
    if (service == null) return;
    setState(() {
      _busy = true;
      _status = null;
      _preview = null;
    });
    final result = await service.preview(
      root: _root.text.isEmpty ? null : _root.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result case ChimeraSuccess<DotnetCleanPreview>(:final value)) {
        _preview = value;
        if (value.paths.isEmpty) {
          _status = _message('removed').replaceAll('{count}', '0');
        }
      } else {
        _status = widget.catalog.lookup(
          widget.localeTag,
          (result as ChimeraFailure<DotnetCleanPreview>).messageKey,
        );
      }
    });
  }

  Future<void> _confirm() async {
    final preview = _preview;
    final service = _service;
    if (preview == null || service == null || _busy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_message('confirm')),
        content: SingleChildScrollView(
          child: SelectableText(
            '${_message('scope')}: ${preview.root}\n${preview.paths.join('\n')}',
          ),
        ),
        actions: [
          TextButton(
            key: const Key('dotnet-clean-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(_message('cancel')),
          ),
          FilledButton(
            key: const Key('dotnet-clean-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_message('confirm')),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || !identical(preview, _preview)) return;
    setState(() {
      _busy = true;
      _preview = null;
    });
    final result = await service.clean(preview, confirmed: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result case ChimeraSuccess<DotnetCleanReport>(:final value)) {
        _status = _message('removed')
            .replaceAll('{count}', '${value.removed.length}');
        for (final path in value.retained.keys) {
          _status = '$_status\n${_message('retained')}: $path';
        }
      } else {
        _status = widget.catalog.lookup(
          widget.localeTag,
          (result as ChimeraFailure<DotnetCleanReport>).messageKey,
        );
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
                  key: const Key('dotnet-clean-root'),
                  controller: _root,
                  enabled: !_busy,
                  decoration: InputDecoration(labelText: _message('root')),
                  onChanged: (_) => setState(() {
                    _preview = null;
                    _status = null;
                  }),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('dotnet-clean-preview'),
                  onPressed: _busy ? null : _scan,
                  child: Text(_message('preview')),
                ),
                if (_preview case final preview?) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    '${_message('scope')}: ${preview.root}\n${preview.paths.join('\n')}',
                  ),
                  if (preview.paths.isNotEmpty)
                    FilledButton(
                      key: const Key('dotnet-clean-delete'),
                      onPressed: _busy ? null : _confirm,
                      child: Text(_message('confirm')),
                    ),
                ],
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
