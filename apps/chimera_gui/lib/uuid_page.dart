import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_file_save.dart';

typedef UuidOperationService =
    OperationService<UuidOperationRequest, UuidOutput>;
typedef UuidClipboardWriter = Future<void> Function(String value);
typedef UuidFileSaver = Future<bool> Function(
  String name,
  Uint8List bytes,
  String mimeType,
);
typedef UuidOutputEncoder = Uint8List Function(String value);

Future<void> writeUuidClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));
Uint8List encodeUuidOutput(String value) => utf8.encode(value);
Future<bool> saveUuidFile(String name, Uint8List bytes, String mimeType) =>
    saveLocalFile(name, bytes, mimeType, extensions: const ['txt']);

final class UuidPage extends StatefulWidget {
  const UuidPage({
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
  final UuidOperationService service;
  final UuidClipboardWriter clipboardWriter;
  final UuidFileSaver fileSaver;
  final UuidOutputEncoder outputEncoder;

  @override
  State<UuidPage> createState() => _UuidPageState();
}

final class _UuidPageState extends State<UuidPage> {
  final _count = TextEditingController(text: '1');
  final _resultFocus = FocusNode(debugLabel: 'UUID result');
  String _version = 'v4';
  String _representation = 'uuid';
  UuidOutput? _output;
  String? _error;
  String? _notice;
  bool _busy = false;
  int _generation = 0;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'uuid.$key');
  bool _current(int generation) => mounted && generation == _generation;
  String? get _text => _output?.values.join('\n');

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
      _error = widget.catalog.lookup(widget.localeTag, 'error.uuid.$key');
    });
  }

  Future<void> _generate() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final result = await widget.service.execute(
        UuidOperationRequest(
          version: _version,
          representation: _representation,
          count: _count.text,
        ),
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
        onFailure: (failure) => _fail(generation, switch (failure.kind) {
          FailureKind.processing => 'processing',
          FailureKind.resource => 'resource',
          _ => 'validation',
        }),
      );
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'processing');
    }
  }

  Future<void> _copy() async {
    final text = _text;
    if (_busy || text == null) return;
    final generation = _begin(preserve: true);
    try {
      await widget.clipboardWriter(text);
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
    final text = _text;
    if (_busy || text == null) return;
    final generation = _begin(preserve: true);
    try {
      final saved = await widget.fileSaver(
        'chimera-identifiers.txt',
        widget.outputEncoder(text),
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

  void _selectVersion(String? value) {
    if (value == null || value == _version) return;
    setState(() {
      _version = value;
      _invalidate();
    });
  }

  void _selectRepresentation(String? value) {
    if (value == null || value == _representation) return;
    setState(() {
      _representation = value;
      _invalidate();
    });
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
                    key: const Key('uuid-version'),
                    initialValue: _version,
                    decoration: InputDecoration(
                      labelText: _label('versionLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'v4',
                        child: Text(_label('version4')),
                      ),
                      DropdownMenuItem(
                        value: 'v7',
                        child: Text(_label('version7')),
                      ),
                    ],
                    onChanged: _busy ? null : _selectVersion,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('uuid-representation'),
                    initialValue: _representation,
                    decoration: InputDecoration(
                      labelText: _label('representationLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'uuid',
                        child: Text(_label('uuidRepresentation')),
                      ),
                      DropdownMenuItem(
                        value: 'guid',
                        child: Text(_label('guidRepresentation')),
                      ),
                    ],
                    onChanged: _busy ? null : _selectRepresentation,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('uuid-count'),
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
                    key: const Key('uuid-generate'),
                    onPressed: _busy ? null : _generate,
                    child: Text(_label('generate')),
                  ),
                  if (_error case final error?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('uuid-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_notice case final notice?)
                    Semantics(
                      liveRegion: true,
                      child: Text(notice, key: const Key('uuid-notice')),
                    ),
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    Focus(
                      focusNode: _resultFocus,
                      child: Semantics(
                        key: const Key('uuid-result'),
                        container: true,
                        focusable: true,
                        liveRegion: true,
                        excludeSemantics: true,
                        role: SemanticsRole.region,
                        label: _label('resultLabel'),
                        value:
                            '${_label('success')} ${output.values.join(' ')}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _label('resultLabel'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SelectableText(
                              output.values.join('\n'),
                              key: const Key('uuid-output'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('uuid-copy'),
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: Text(_label('copy')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('uuid-save'),
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
