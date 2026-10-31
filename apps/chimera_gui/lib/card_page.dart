import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_file_save.dart';

typedef CardOperationService =
    OperationService<CardOperationRequest, CardOutput>;
typedef CardClipboardWriter = Future<void> Function(String value);
typedef CardFileSaver = Future<bool> Function(
  String name,
  Uint8List bytes,
  String mimeType,
);
typedef CardOutputEncoder = Uint8List Function(String value);

Future<void> writeCardClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));
Uint8List encodeCardOutput(String value) => utf8.encode(value);
Future<bool> saveCardFile(String name, Uint8List bytes, String mimeType) =>
    saveLocalFile(name, bytes, mimeType, extensions: const ['txt']);

final class CardPage extends StatefulWidget {
  const CardPage({
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
  final CardOperationService service;
  final CardClipboardWriter clipboardWriter;
  final CardFileSaver fileSaver;
  final CardOutputEncoder outputEncoder;

  @override
  State<CardPage> createState() => _CardPageState();
}

final class _CardPageState extends State<CardPage> {
  final _count = TextEditingController(text: '1');
  final _resultFocus = FocusNode(debugLabel: 'Card result');
  String _network = 'visa';
  CardOutput? _output;
  String? _error;
  String? _notice;
  bool _busy = false;
  int _generation = 0;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'card.$key');
  bool _current(int generation) => mounted && generation == _generation;
  String? get _text => _output == null
      ? null
      : [_label('syntheticLabel'), ..._output!.values].join('\n');

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
      _error = widget.catalog.lookup(widget.localeTag, 'error.card.$key');
    });
  }

  Future<void> _generate() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final result = await widget.service.execute(
        CardOperationRequest(network: _network, count: _count.text),
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
        'chimera-synthetic-cards.txt',
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

  void _selectNetwork(String? value) {
    if (value == null || value == _network) return;
    setState(() {
      _network = value;
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
                    key: const Key('card-network'),
                    initialValue: _network,
                    decoration: InputDecoration(
                      labelText: _label('networkLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'visa',
                        child: Text(_label('network.visa')),
                      ),
                      DropdownMenuItem(
                        value: 'mastercard',
                        child: Text(_label('network.mastercard')),
                      ),
                      DropdownMenuItem(
                        value: 'amex',
                        child: Text(_label('network.amex')),
                      ),
                      DropdownMenuItem(
                        value: 'discover',
                        child: Text(_label('network.discover')),
                      ),
                    ],
                    onChanged: _busy ? null : _selectNetwork,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('card-count'),
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
                    key: const Key('card-generate'),
                    onPressed: _busy ? null : _generate,
                    child: Text(_label('generate')),
                  ),
                  if (_error case final error?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('card-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_notice case final notice?)
                    Semantics(
                      liveRegion: true,
                      child: Text(notice, key: const Key('card-notice')),
                    ),
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    Focus(
                      focusNode: _resultFocus,
                      child: Semantics(
                        key: const Key('card-result'),
                        container: true,
                        focusable: true,
                        liveRegion: true,
                        excludeSemantics: true,
                        role: SemanticsRole.region,
                        label: _label('resultLabel'),
                        value:
                            '${_label('success')} ${_label('syntheticLabel')} ${output.values.join(' ')}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _label('resultLabel'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              _label('syntheticLabel'),
                              key: const Key('card-synthetic-label'),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            SelectableText(
                              output.values.join('\n'),
                              key: const Key('card-output'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('card-copy'),
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: Text(_label('copy')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('card-save'),
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
