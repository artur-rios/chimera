import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_file_save.dart';

typedef LoremOperationService =
    OperationService<LoremOperationRequest, LoremOutput>;
typedef LoremClipboardWriter = Future<void> Function(String value);
typedef LoremFileSaver = Future<bool> Function(
  String name,
  Uint8List bytes,
  String mimeType,
);
typedef LoremOutputEncoder = Uint8List Function(String value);

Future<void> writeLoremClipboard(String text) =>
    Clipboard.setData(ClipboardData(text: text));
Uint8List encodeLoremOutput(String text) => utf8.encode(text);
Future<bool> saveLoremFile(String name, Uint8List bytes, String mimeType) =>
    saveLocalFile(name, bytes, mimeType, extensions: const ['txt']);

final class LoremPage extends StatefulWidget {
  const LoremPage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.clipboardWriter,
    required this.fileSaver,
    required this.outputEncoder,
    super.key,
  });
  final MessageCatalog catalog;
  final String localeTag;
  final LoremOperationService service;
  final LoremClipboardWriter clipboardWriter;
  final LoremFileSaver fileSaver;
  final LoremOutputEncoder outputEncoder;
  @override
  State<LoremPage> createState() => _LoremPageState();
}

final class _LoremPageState extends State<LoremPage> {
  final _count = TextEditingController(text: '1');
  final _resultFocus = FocusNode(debugLabel: 'Lorem result');
  String _unit = 'paragraphs';
  LoremOutput? _output;
  String? _error;
  String? _notice;
  bool _busy = false;
  int _generation = 0;
  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'lorem.$key');
  bool _current(int generation) => mounted && generation == _generation;
  void _invalidate() {
    _generation++;
    _output = null;
    _error = null;
    _notice = null;
    _busy = false;
  }

  int _begin({bool preserve = false}) {
    setState(() {
      if (!preserve) _output = null;
      _generation++;
      _error = null;
      _notice = null;
      _busy = true;
    });
    return _generation;
  }

  void _fail(int generation, String key) {
    if (!_current(generation)) return;
    setState(() {
      _invalidate();
      _error = widget.catalog.lookup(widget.localeTag, 'error.lorem.$key');
    });
  }

  Future<void> _generate() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final result = await widget.service.execute(
        LoremOperationRequest(unit: _unit, count: _count.text),
      );
      if (!_current(generation)) return;
      result.fold(
        onSuccess: (value) {
          setState(() {
            _output = value;
            _busy = false;
          });
          _resultFocus.requestFocus();
        },
        onFailure: (failure) => _fail(
          generation,
          failure.kind == FailureKind.resource ? 'resource' : 'validation',
        ),
      );
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'outputAccess');
    }
  }

  Future<void> _copy() async {
    final output = _output;
    if (_busy || output == null) return;
    final generation = _begin(preserve: true);
    try {
      await widget.clipboardWriter(output.text);
      if (!_current(generation)) return;
      setState(() {
        _busy = false;
        _notice = _label('copied');
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'clipboardWrite');
    }
  }

  Future<void> _save() async {
    final output = _output;
    if (_busy || output == null) return;
    final generation = _begin(preserve: true);
    try {
      final saved = await widget.fileSaver(
        'chimera-lorem.txt',
        widget.outputEncoder(output.text),
        'text/plain; charset=utf-8',
      );
      if (!_current(generation)) return;
      setState(() {
        _busy = false;
        if (saved) _notice = _label('saved');
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'outputAccess');
    }
  }

  @override
  void dispose() {
    _generation++;
    _output = null;
    _count.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_label('pageTitle'))),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_label('semantics')),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('lorem-unit'),
                    initialValue: _unit,
                    decoration: InputDecoration(
                      labelText: _label('unitLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final unit in ['words', 'sentences', 'paragraphs'])
                        DropdownMenuItem(
                          value: unit,
                          child: Text(_label(unit)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null || value == _unit) return;
                      setState(() {
                        _unit = value;
                        _invalidate();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('lorem-count'),
                    controller: _count,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: _label('countLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(_invalidate),
                    onSubmitted: (_) => _generate(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const Key('lorem-generate'),
                    onPressed: _busy ? null : _generate,
                    child: Text(_label('generate')),
                  ),
                  if (_error case final error?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('lorem-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_notice case final notice?)
                    Semantics(
                      liveRegion: true,
                      child: Text(notice, key: const Key('lorem-notice')),
                    ),
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    Focus(
                      focusNode: _resultFocus,
                      child: Semantics(
                        key: const Key('lorem-result'),
                        container: true,
                        focusable: true,
                        liveRegion: true,
                        excludeSemantics: true,
                        role: SemanticsRole.region,
                        label: _label('resultLabel'),
                        value: '${_label('success')} ${output.text}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _label('resultLabel'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  output.text,
                                  key: const Key('lorem-output'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('lorem-copy'),
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: Text(_label('copy')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('lorem-save'),
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save_alt),
                      label: Text(_label('save')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
