import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';

typedef UpdateCheckCallback =
    Future<ChimeraResult<UpdateCheckResult>> Function();

final class UpdatePage extends StatefulWidget {
  const UpdatePage({
    required this.catalog,
    required this.localeTag,
    required this.checker,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final UpdateCheckCallback checker;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

final class _UpdatePageState extends State<UpdatePage> {
  bool _checking = false;
  String? _status;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
    });

    final ChimeraResult<UpdateCheckResult> result;
    try {
      result = await widget.checker();
    } on Object {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _status = widget.catalog.lookup(
          widget.localeTag,
          'error.update.checkFailed',
        );
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _checking = false;
      _status = result.fold(
        onSuccess: _successMessage,
        onFailure: (failure) =>
            widget.catalog.lookup(widget.localeTag, failure.messageKey),
      );
    });
  }

  String _successMessage(UpdateCheckResult result) {
    if (result.status == UpdateCheckStatus.current) {
      return widget.catalog
          .lookup(widget.localeTag, 'update.current')
          .replaceAll('{version}', result.installedVersion.toString());
    }

    final release = result.availableRelease!;
    return widget.catalog
        .lookup(widget.localeTag, 'update.available')
        .replaceAll('{available}', release.releaseVersion.toString())
        .replaceAll('{installed}', result.installedVersion.toString())
        .replaceAll('{package}', release.packageType.name)
        .replaceAll('{checksum}', release.checksum);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.catalog.lookup(widget.localeTag, 'update.pageTitle'),
        ),
      ),
      body: Focus(
        autofocus: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      widget.catalog.lookup(
                        widget.localeTag,
                        'update.pageTitle',
                      ),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.catalog.lookup(
                      widget.localeTag,
                      'update.description',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    key: const Key('update-check-action'),
                    onPressed: _checking ? null : _check,
                    icon: const Icon(Icons.system_update_alt),
                    label: Text(
                      widget.catalog.lookup(
                        widget.localeTag,
                        'update.checkAction',
                      ),
                    ),
                  ),
                  if (_checking) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      key: const Key('update-check-progress'),
                      liveRegion: true,
                      label: widget.catalog.lookup(
                        widget.localeTag,
                        'update.checking',
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  if (_status != null) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      key: const Key('update-check-status'),
                      liveRegion: true,
                      child: Text(_status!),
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
