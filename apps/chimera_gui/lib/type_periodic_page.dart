import 'dart:async';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/type_periodic_terminal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final class TypePeriodicPage extends StatefulWidget {
  const TypePeriodicPage({
    required this.catalog,
    required this.localeTag,
    this.serviceFactory,
    super.key,
  });
  final MessageCatalog catalog;
  final String localeTag;
  final TypePeriodicService Function()? serviceFactory;
  @override
  State<TypePeriodicPage> createState() => _TypePeriodicPageState();
}

final class _TypePeriodicPageState extends State<TypePeriodicPage>
    with WidgetsBindingObserver {
  final _interval = TextEditingController(text: '20');
  PeriodicCancellation? _cancellation;
  String? _status;
  int _seconds = 20;
  int _count = 0;
  String message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) _cancellation?.cancel();
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _interval.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_cancellation != null) return;
    final cancellation = PeriodicCancellation();
    setState(() {
      _cancellation = cancellation;
      _count = 0;
      _status = 'typePeriodic.starting';
    });
    final service =
        widget.serviceFactory?.call() ??
        TypePeriodicService(terminal: createPeriodicTerminal());
    final result = await service.run(
      interval: _interval.text,
      cancellation: cancellation,
      onStarted: (seconds) {
        if (!mounted) return;
        setState(() {
          _seconds = seconds;
          _status = 'typePeriodic.running';
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _cancellation = null;
      result.fold(
        onSuccess: (output) {
          _count = output.sentCount;
          _status = 'typePeriodic.stopped';
        },
        onFailure: (failure) {
          _status = failure.messageKey;
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(message('typePeriodic.pageTitle')),
      leading: IconButton(
        icon: const Icon(Icons.home),
        tooltip: message('app.name'),
        onPressed: () => context.go('/'),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message('typePeriodic.description')),
              const SizedBox(height: 16),
              TextField(
                controller: _interval,
                enabled: _cancellation == null,
                decoration: InputDecoration(
                  labelText: message('typePeriodic.interval'),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('type-periodic-start'),
                onPressed: _cancellation == null
                    ? () => unawaited(_start())
                    : null,
                child: Text(message('typePeriodic.start')),
              ),
              OutlinedButton(
                key: const Key('type-periodic-stop'),
                onPressed: _cancellation == null
                    ? null
                    : () => _cancellation?.cancel(),
                child: Text(message('typePeriodic.stop')),
              ),
              if (_status != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message(_status!)
                        .replaceAll('{seconds}', '$_seconds')
                        .replaceAll('{count}', '$_count'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
