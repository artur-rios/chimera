import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';

typedef UpdateCheckCallback =
    Future<ChimeraResult<UpdateCheckResult>> Function();
typedef UpdateApplyCallback = Future<ChimeraResult<UpdateApplyResult>> Function(
  ReleaseMetadata release,
);

final class UpdatePage extends StatefulWidget {
  const UpdatePage({
    required this.catalog,
    required this.localeTag,
    required this.checker,
    this.applier,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final UpdateCheckCallback checker;
  final UpdateApplyCallback? applier;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

final class _UpdatePageState extends State<UpdatePage> {
  bool _checking = false;
  bool _applying = false;
  bool _updatePending = false;
  String? _status;
  ReleaseMetadata? _availableRelease;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
      _availableRelease = null;
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
      if (result case ChimeraSuccess<UpdateCheckResult>(:final value)) {
        _availableRelease = value.availableRelease;
        _status = _successMessage(value);
      } else {
        final failure = result as ChimeraFailure<UpdateCheckResult>;
        _status = widget.catalog.lookup(widget.localeTag, failure.messageKey);
      }
    });
  }

  Future<void> _confirmAndApply() async {
    final release = _availableRelease;
    final applier = widget.applier;
    if (release == null || applier == null) return;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.catalog
              .lookup(widget.localeTag, 'update.applyConfirmTitle')
              .replaceAll('{version}', release.releaseVersion.toString()),
        ),
        content: Text(
          widget.catalog
              .lookup(widget.localeTag, 'update.applyConfirmMessage')
              .replaceAll('{package}', release.packageType.name)
              .replaceAll('{checksum}', release.checksum),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('update-apply-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              widget.catalog.lookup(widget.localeTag, 'update.applyCancel'),
            ),
          ),
          FilledButton(
            key: const Key('update-apply-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              widget.catalog.lookup(widget.localeTag, 'update.applyAction'),
            ),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    setState(() {
      _applying = true;
      _status = null;
    });
    final ChimeraResult<UpdateApplyResult> result;
    try {
      result = await applier(release);
    } on Object {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _status = widget.catalog.lookup(
          widget.localeTag,
          'error.update.installFailed',
        );
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _applying = false;
      if (result case ChimeraSuccess<UpdateApplyResult>(:final value)) {
        _availableRelease = null;
        _updatePending = value.status == UpdateApplyStatus.scheduled;
        _status = widget.catalog
            .lookup(
              widget.localeTag,
              value.status == UpdateApplyStatus.scheduled
                  ? 'update.scheduled'
                  : value.restartRequired
                  ? 'update.appliedRestart'
                  : 'update.applied',
            )
            .replaceAll('{version}', value.release.releaseVersion.toString());
      } else {
        final failure = result as ChimeraFailure<UpdateApplyResult>;
        _status = widget.catalog.lookup(widget.localeTag, failure.messageKey);
      }
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
                    onPressed: _checking || _applying || _updatePending
                        ? null
                        : _check,
                    icon: const Icon(Icons.system_update_alt),
                    label: Text(
                      widget.catalog.lookup(
                        widget.localeTag,
                        'update.checkAction',
                      ),
                    ),
                  ),
                  if (_availableRelease != null &&
                      widget.applier != null) ...<Widget>[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('update-apply-action'),
                      onPressed: _checking || _applying
                          ? null
                          : _confirmAndApply,
                      icon: const Icon(Icons.download_for_offline),
                      label: Text(
                        widget.catalog.lookup(
                          widget.localeTag,
                          'update.applyAction',
                        ),
                      ),
                    ),
                  ],
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
                  if (_applying) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      key: const Key('update-apply-progress'),
                      liveRegion: true,
                      label: widget.catalog.lookup(
                        widget.localeTag,
                        'update.applying',
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
