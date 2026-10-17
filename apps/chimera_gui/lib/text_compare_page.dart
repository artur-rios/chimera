import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef TextCompareFilePicker = Future<String?> Function();
typedef TextCompareFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef TextCompareClipboardReader = Future<String?> Function();
typedef TextCompareClipboardWriter = Future<void> Function(String value);

Future<String?> pickTextCompareFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

Future<bool> saveTextCompareFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'application/json',
    type: FileType.custom,
    allowedExtensions: const <String>['json'],
  );
  return uri != null;
}

Future<String?> readTextCompareClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeTextCompareClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class TextComparePage extends StatefulWidget {
  const TextComparePage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.leftFilePicker,
    required this.rightFilePicker,
    required this.fileSaver,
    required this.leftClipboardReader,
    required this.rightClipboardReader,
    required this.clipboardWriter,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final TextCompareService service;
  final TextCompareFilePicker leftFilePicker;
  final TextCompareFilePicker rightFilePicker;
  final TextCompareFileSaver fileSaver;
  final TextCompareClipboardReader leftClipboardReader;
  final TextCompareClipboardReader rightClipboardReader;
  final TextCompareClipboardWriter clipboardWriter;

  @override
  State<TextComparePage> createState() => _TextComparePageState();
}

final class _TextComparePageState extends State<TextComparePage> {
  late final TextEditingController _leftController;
  late final TextEditingController _rightController;
  TextCompareOutput? _output;
  String? _error;
  String? _notice;
  String _granularity = TextCompareGranularity.line.slug;
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _leftController = TextEditingController(text: 'alpha\nbeta');
    _rightController = TextEditingController(text: 'alpha\ngamma');
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearFeedback();
    });
    final result = await widget.service.execute(
      TextCompareOperationRequest(
        left: _leftController.text,
        right: _rightController.text,
        granularity: _granularity,
      ),
    );
    if (!mounted) return;
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

  Future<void> _loadLeftFile() => _loadInput(
    controller: _leftController,
    loader: widget.leftFilePicker,
    errorKey: 'error.textCompare.fileAccess',
  );

  Future<void> _loadRightFile() => _loadInput(
    controller: _rightController,
    loader: widget.rightFilePicker,
    errorKey: 'error.textCompare.fileAccess',
  );

  Future<void> _pasteLeft() => _loadInput(
    controller: _leftController,
    loader: widget.leftClipboardReader,
    errorKey: 'error.textCompare.clipboardRead',
  );

  Future<void> _pasteRight() => _loadInput(
    controller: _rightController,
    loader: widget.rightClipboardReader,
    errorKey: 'error.textCompare.clipboardRead',
  );

  Future<void> _loadInput({
    required TextEditingController controller,
    required Future<String?> Function() loader,
    required String errorKey,
  }) async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearFeedback();
    });
    try {
      final value = await loader();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (value != null) controller.text = value;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message(errorKey);
      });
    }
  }

  Future<void> _copy() async {
    final output = _output;
    if (_isRunning || output == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.clipboardWriter(_json(output));
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _notice = _message('textCompare.copiedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.textCompare.clipboardWrite');
      });
    }
  }

  Future<void> _save() async {
    final output = _output;
    if (_isRunning || output == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      final saved = await widget.fileSaver(
        'chimera-text-diff.json',
        utf8.encode(_json(output)),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('textCompare.savedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.textCompare.outputAccess');
      });
    }
  }

  void _selectGranularity(String? value) {
    if (value == null) return;
    setState(() {
      _granularity = value;
      _clearFeedback();
    });
  }

  void _clearFeedback() {
    _output = null;
    _error = null;
    _notice = null;
  }

  String _json(TextCompareOutput output) => jsonEncode(output.toJson());

  String _semanticValue(TextCompareOutput output) {
    final buffer = StringBuffer();
    for (final span in output.spans) {
      buffer.writeln(
        '${_message('textCompare.kind.${span.kind.slug}')}: ${span.text}',
      );
    }
    buffer
      ..writeln(
        '${_message('textCompare.addedCountLabel')}: ${output.summary.added}',
      )
      ..writeln(
        '${_message('textCompare.removedCountLabel')}: ${output.summary.removed}',
      )
      ..write(
        '${_message('textCompare.unchangedCountLabel')}: ${output.summary.unchanged}',
      );
    return buffer.toString();
  }

  Widget _inputPanel({
    required String side,
    required TextEditingController controller,
    required VoidCallback loadFile,
    required VoidCallback paste,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextField(
        key: Key('text-compare-$side-input'),
        controller: controller,
        autofocus: side == 'left',
        enabled: !_isRunning,
        minLines: 5,
        maxLines: 10,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        onChanged: (_) {
          if (!_isRunning) setState(_clearFeedback);
        },
        decoration: InputDecoration(
          labelText: _message('textCompare.${side}InputLabel'),
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          OutlinedButton.icon(
            key: Key('text-compare-$side-file'),
            onPressed: _isRunning ? null : loadFile,
            icon: const Icon(Icons.file_open),
            label: Text(_message('textCompare.fileAction.$side')),
          ),
          OutlinedButton.icon(
            key: Key('text-compare-$side-paste'),
            onPressed: _isRunning ? null : paste,
            icon: const Icon(Icons.content_paste),
            label: Text(_message('textCompare.pasteAction.$side')),
          ),
        ],
      ),
    ],
  );

  Widget _diffSpan(TextDiffSpan span, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (span.kind) {
      TextDiffKind.unchanged => (
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurface,
        Icons.drag_handle,
      ),
      TextDiffKind.removed => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        Icons.remove_circle_outline,
      ),
      TextDiffKind.added => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
        Icons.add_circle_outline,
      ),
    };
    return Container(
      key: Key('text-compare-span-$index'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 8),
              Text(
                _message('textCompare.kind.${span.kind.slug}'),
                key: Key('text-compare-span-$index-kind'),
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: foreground),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            span.text,
            key: Key('text-compare-span-$index-text'),
            style: TextStyle(
              color: foreground,
              decoration: span.kind == TextDiffKind.removed
                  ? TextDecoration.lineThrough
                  : null,
              decorationColor: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _result(TextCompareOutput output) => Semantics(
    key: const Key('text-compare-result-semantics'),
    container: true,
    liveRegion: true,
    excludeSemantics: true,
    role: SemanticsRole.region,
    label: _message('textCompare.outputLabel'),
    value: _semanticValue(output),
    child: Container(
      key: const Key('text-compare-result'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _message('textCompare.outputLabel'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < output.spans.length; index++)
            _diffSpan(output.spans[index], index),
          const SizedBox(height: 12),
          Text(
            '${_message('textCompare.addedCountLabel')}: '
            '${output.summary.added}',
          ),
          Text(
            '${_message('textCompare.removedCountLabel')}: '
            '${output.summary.removed}',
          ),
          Text(
            '${_message('textCompare.unchangedCountLabel')}: '
            '${output.summary.unchanged}',
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('textCompare.pageTitle'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final left = _inputPanel(
                    side: 'left',
                    controller: _leftController,
                    loadFile: _loadLeftFile,
                    paste: _pasteLeft,
                  );
                  final right = _inputPanel(
                    side: 'right',
                    controller: _rightController,
                    loadFile: _loadRightFile,
                    paste: _pasteRight,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: left),
                            const SizedBox(width: 16),
                            Expanded(child: right),
                          ],
                        )
                      else ...<Widget>[left, const SizedBox(height: 16), right],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: const Key('text-compare-granularity'),
                        initialValue: _granularity,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _message('textCompare.granularityLabel'),
                          border: const OutlineInputBorder(),
                        ),
                        items: TextCompareGranularity.values
                            .map(
                              (granularity) => DropdownMenuItem<String>(
                                value: granularity.slug,
                                child: Text(
                                  _message(
                                    'textCompare.granularity.${granularity.slug}',
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _isRunning ? null : _selectGranularity,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        key: const Key('text-compare-submit'),
                        onPressed: _isRunning ? null : _submit,
                        child: Text(_message('textCompare.submitAction')),
                      ),
                      if (_error case final error?) ...<Widget>[
                        const SizedBox(height: 24),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            key: const Key('text-compare-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      if (_notice case final notice?) ...<Widget>[
                        const SizedBox(height: 16),
                        Semantics(liveRegion: true, child: Text(notice)),
                      ],
                      if (_output case final output?) ...<Widget>[
                        const SizedBox(height: 24),
                        _result(output),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            OutlinedButton.icon(
                              key: const Key('text-compare-copy'),
                              onPressed: _isRunning ? null : _copy,
                              icon: const Icon(Icons.copy),
                              label: Text(_message('textCompare.copyAction')),
                            ),
                            OutlinedButton.icon(
                              key: const Key('text-compare-save'),
                              onPressed: _isRunning ? null : _save,
                              icon: const Icon(Icons.save_alt),
                              label: Text(_message('textCompare.saveAction')),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
