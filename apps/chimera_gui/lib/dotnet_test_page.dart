import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';

import 'dotnet_runtime.dart';

typedef DotnetTester = Future<ChimeraResult<DotnetTestOutput>> Function(
  DotnetTestRequest request, {
  OperationCancellation? cancellation,
  void Function(String)? onDiagnostic,
});

class DotnetTestPage extends StatefulWidget {
  const DotnetTestPage({
    super.key,
    required this.catalog,
    required this.localeTag,
    this.tester,
    this.supported,
  });
  final MessageCatalog catalog;
  final String localeTag;
  final DotnetTester? tester;
  final bool? supported;
  @override
  State<DotnetTestPage> createState() => _DotnetTestPageState();
}

class _DotnetTestPageState extends State<DotnetTestPage> {
  final _base = TextEditingController();
  OperationCancellation? _cancellation;
  String _diagnostics = '';
  String? _status;
  String? _paths;
  String text(String key) => widget.catalog.lookup(widget.localeTag, key);
  @override
  void dispose() {
    _cancellation?.cancel();
    _base.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final token = OperationCancellation();
    setState(() {
      _cancellation = token;
      _diagnostics = '';
      _paths = null;
      _status = 'dotnet.testing';
    });
    final result = await (widget.tester ?? createDotnetTestService().test)(
      DotnetTestRequest(
        baseDirectory: _base.text.trim().isEmpty ? null : _base.text,
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
    if (!mounted) {
      return;
    }
    setState(() {
      _cancellation = null;
      if (result is ChimeraSuccess<DotnetTestOutput>) {
        _status = result.value.noTests
            ? 'dotnet.noTests'
            : 'dotnet.testSucceeded';
        _paths =
            '${result.value.resultsDirectory}\n${result.value.reportDirectory}';
      } else {
        final failure = result as ChimeraFailure<DotnetTestOutput>;
        _status = failure.messageKey;
        final code = failure.details['exitCode'];
        if (code is int) {
          _diagnostics +=
              '\n${text('dotnet.exitStatus').replaceAll('{code}', '$code')}\n';
        }
        final results = failure.details['resultsDirectory'];
        final report = failure.details['reportDirectory'];
        if (results is String && report is String) {
          _paths = '$results\n$report';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final supported = widget.supported ?? dotnetBuildSupported;
    final running = _cancellation != null;
    return Scaffold(
      appBar: AppBar(title: Text(text('dotnet.testTitle'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text('dotnet.testDescription')),
            if (!supported) Text(text('error.dotnet.testUnsupported')),
            TextField(
              key: const Key('dotnet-test-base'),
              controller: _base,
              enabled: supported && !running,
              decoration: InputDecoration(labelText: text('dotnet.testBase')),
            ),
            ElevatedButton(
              key: const Key('dotnet-test'),
              onPressed: !supported || running ? null : _test,
              child: Text(text('dotnet.testAction')),
            ),
            if (running)
              OutlinedButton(
                key: const Key('dotnet-test-cancel'),
                onPressed: _cancellation!.cancel,
                child: Text(text('dotnet.cancel')),
              ),
            if (_status != null)
              Text(text(_status!), key: const Key('dotnet-test-status')),
            if (_paths != null)
              SelectableText(_paths!, key: const Key('dotnet-test-paths')),
            SelectableText(
              _diagnostics,
              key: const Key('dotnet-test-diagnostics'),
            ),
          ],
        ),
      ),
    );
  }
}
