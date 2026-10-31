import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';

import 'dotnet_runtime.dart';

typedef DotnetBuilder = Future<ChimeraResult<DotnetBuildOutput>> Function(
  DotnetBuildRequest request, {
  OperationCancellation? cancellation,
  void Function(String)? onDiagnostic,
});

class DotnetBuildPage extends StatefulWidget {
  const DotnetBuildPage({
    super.key,
    required this.catalog,
    required this.localeTag,
    this.builder,
    this.supported,
  });
  final MessageCatalog catalog;
  final String localeTag;
  final DotnetBuilder? builder;
  final bool? supported;
  @override
  State<DotnetBuildPage> createState() => _DotnetBuildPageState();
}

class _DotnetBuildPageState extends State<DotnetBuildPage> {
  final _source = TextEditingController(text: './src');
  final _solution = TextEditingController();
  String? _configuration;
  bool _noRestore = false;
  OperationCancellation? _cancellation;
  String _diagnostics = '';
  String? _status;
  String text(String key) => widget.catalog.lookup(widget.localeTag, key);
  @override
  void dispose() {
    _cancellation?.cancel();
    _source.dispose();
    _solution.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    final token = OperationCancellation();
    setState(() {
      _cancellation = token;
      _diagnostics = '';
      _status = 'dotnet.running';
    });
    final result = await (widget.builder ?? createDotnetBuildService().build)(
      DotnetBuildRequest(
        sourceDirectory: _source.text,
        solution: _solution.text.trim().isEmpty ? null : _solution.text.trim(),
        configuration: _configuration,
        noRestore: _noRestore,
      ),
      cancellation: token,
      onDiagnostic: (line) {
        if (mounted) {
          setState(() {
            _diagnostics += line;
          });
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _cancellation = null;
      _status = result is ChimeraSuccess<DotnetBuildOutput>
          ? 'dotnet.succeeded'
          : (result as ChimeraFailure<DotnetBuildOutput>).messageKey;
      if (result is ChimeraFailure<DotnetBuildOutput>) {
        final exitCode = result.details['exitCode'];
        if (exitCode is int) {
          _diagnostics +=
              '\n${text('dotnet.exitStatus').replaceAll('{code}', '$exitCode')}\n';
        }
        final choices = result.details['choices'];
        if (choices is List && choices.isNotEmpty) {
          _diagnostics += choices.join('\n');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final supported = widget.supported ?? dotnetBuildSupported;
    final running = _cancellation != null;
    return Scaffold(
      appBar: AppBar(title: Text(text('dotnet.title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!supported) Text(text('error.dotnet.unsupported')),
            TextField(
              key: const Key('dotnet-source'),
              controller: _source,
              enabled: supported && !running,
              decoration: InputDecoration(labelText: text('dotnet.source')),
            ),
            TextField(
              key: const Key('dotnet-solution'),
              controller: _solution,
              enabled: supported && !running,
              decoration: InputDecoration(labelText: text('dotnet.solution')),
            ),
            DropdownButtonFormField<String>(
              key: const Key('dotnet-configuration'),
              initialValue: 'both',
              decoration: InputDecoration(
                labelText: text('dotnet.configuration'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'both',
                  child: Text(text('dotnet.both')),
                ),
                const DropdownMenuItem(value: 'Debug', child: Text('Debug')),
                const DropdownMenuItem(
                  value: 'Release',
                  child: Text('Release'),
                ),
              ],
              onChanged: !supported || running
                  ? null
                  : (value) {
                      _configuration = value == 'both' ? null : value;
                    },
            ),
            CheckboxListTile(
              title: Text(text('dotnet.noRestore')),
              value: _noRestore,
              onChanged: !supported || running
                  ? null
                  : (value) {
                      setState(() {
                        _noRestore = value!;
                      });
                    },
            ),
            ElevatedButton(
              key: const Key('dotnet-build'),
              onPressed: !supported || running ? null : _build,
              child: Text(text('dotnet.build')),
            ),
            if (running)
              OutlinedButton(
                key: const Key('dotnet-cancel'),
                onPressed: _cancellation!.cancel,
                child: Text(text('dotnet.cancel')),
              ),
            if (_status != null)
              Semantics(
                liveRegion: true,
                child: Text(text(_status!), key: const Key('dotnet-status')),
              ),
            SelectionArea(
              child: Text(_diagnostics, key: const Key('dotnet-diagnostics')),
            ),
          ],
        ),
      ),
    );
  }
}
