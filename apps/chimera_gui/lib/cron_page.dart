import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';

final class CronPage extends StatefulWidget {
  const CronPage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.currentTime,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final CronService service;
  final DateTime Function() currentTime;

  @override
  State<CronPage> createState() => _CronPageState();
}

final class _CronPageState extends State<CronPage> {
  late final TextEditingController _expressionController;
  late final TextEditingController _timeZoneController;
  late final TextEditingController _countController;
  late final TextEditingController _referenceController;
  CronOutput? _output;
  String? _error;
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _expressionController = TextEditingController(text: '0 9 * * MON-FRI');
    _timeZoneController = TextEditingController(text: 'UTC');
    _countController = TextEditingController(text: '5');
    _referenceController = TextEditingController(
      text: widget.currentTime().toUtc().toIso8601String(),
    );
  }

  @override
  void dispose() {
    _expressionController.dispose();
    _timeZoneController.dispose();
    _countController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final count = int.tryParse(_countController.text);
    final reference = parseCronReference(_referenceController.text);
    if (count == null || reference == null) {
      setState(() {
        _output = null;
        _error = _message('error.cron.validation');
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _output = null;
      _error = null;
    });
    final result = await widget.service.execute(
      CronRequest(
        expression: _expressionController.text,
        timeZone: _timeZoneController.text,
        occurrenceCount: count,
        referenceUtc: reference,
      ),
    );
    if (!mounted) {
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('cron.pageTitle'))),
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
                    key: const Key('cron-expression'),
                    controller: _expressionController,
                    decoration: InputDecoration(
                      labelText: _message('cron.expressionLabel'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('cron-time-zone'),
                    controller: _timeZoneController,
                    decoration: InputDecoration(
                      labelText: _message('cron.timeZoneLabel'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('cron-count'),
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _message('cron.countLabel'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('cron-reference'),
                    controller: _referenceController,
                    decoration: InputDecoration(
                      labelText: _message('cron.referenceLabel'),
                      helperText: _message('cron.referenceHelp'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const Key('cron-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('cron.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('cron-error'),
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
                      child: _CronResultView(
                        output: output,
                        catalog: widget.catalog,
                        localeTag: widget.localeTag,
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
}

final class _CronResultView extends StatelessWidget {
  const _CronResultView({
    required this.output,
    required this.catalog,
    required this.localeTag,
  });

  final CronOutput output;
  final MessageCatalog catalog;
  final String localeTag;

  String _message(String key) => catalog.lookup(localeTag, key);

  @override
  Widget build(BuildContext context) {
    final evaluation = output.evaluation;
    final fieldDescription = evaluation.fields.entries
        .map((entry) {
          final label = _message('cron.field.${entry.key}');
          final value = entry.value == '*'
              ? _message('cron.everyValue')
              : entry.value;
          return '$label $value';
        })
        .join('; ');
    return Column(
      key: const Key('cron-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${_message('cron.scheduleLabel')}: ${evaluation.normalizedExpression}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text('${_message('cron.timeZoneLabel')}: ${evaluation.timeZone}'),
        const SizedBox(height: 8),
        Text('${_message('cron.explanationLabel')}: $fieldDescription'),
        const SizedBox(height: 12),
        for (final occurrence in evaluation.previous)
          Text('${_message('cron.previousLabel')}: ${occurrence.localIso8601}'),
        for (final occurrence in evaluation.next)
          Text('${_message('cron.nextLabel')}: ${occurrence.localIso8601}'),
      ],
    );
  }
}
