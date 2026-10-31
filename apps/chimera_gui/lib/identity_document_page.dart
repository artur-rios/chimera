import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_file_save.dart';

typedef IdentityDocumentOperationService =
    OperationService<IdentityDocumentOperationRequest, IdentityDocumentOutput>;
typedef IdentityDocumentClipboardWriter = Future<void> Function(String value);
typedef IdentityDocumentFileSaver = Future<bool> Function(
  String name,
  Uint8List bytes,
  String mimeType,
);
typedef IdentityDocumentOutputEncoder = Uint8List Function(String value);

Future<void> writeIdentityDocumentClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));
Uint8List encodeIdentityDocumentOutput(String value) => utf8.encode(value);
Future<bool> saveIdentityDocumentFile(
  String name,
  Uint8List bytes,
  String mimeType,
) => saveLocalFile(name, bytes, mimeType, extensions: const ['txt']);

final class IdentityDocumentPage extends StatefulWidget {
  const IdentityDocumentPage({
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
  final IdentityDocumentOperationService service;
  final IdentityDocumentClipboardWriter clipboardWriter;
  final IdentityDocumentFileSaver fileSaver;
  final IdentityDocumentOutputEncoder outputEncoder;

  @override
  State<IdentityDocumentPage> createState() => _IdentityDocumentPageState();
}

final class _IdentityDocumentPageState extends State<IdentityDocumentPage> {
  final _count = TextEditingController(text: '1');
  final _resultFocus = FocusNode(debugLabel: 'Identity document result');
  String _locale = 'us';
  String _type = 'ssn';
  String _cnpjFormat = 'alphanumeric';
  IdentityDocumentOutput? _output;
  String? _error;
  String? _notice;
  bool _busy = false;
  int _generation = 0;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'document.$key');
  bool _current(int generation) => mounted && generation == _generation;
  String? get _text => _output == null
      ? null
      : [_label('syntheticLabel'), ..._output!.values].join('\n');
  List<String> get _types => _locale == 'us'
      ? const ['ssn', 'itin', 'ein']
      : const ['cpf', 'cnpj', 'cnh', 'cin'];

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
      _error = widget.catalog.lookup(widget.localeTag, 'error.document.$key');
    });
  }

  Future<void> _generate() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final result = await widget.service.execute(
        IdentityDocumentOperationRequest(
          locale: _locale,
          type: _type,
          cnpjFormat: _type == 'cnpj' ? _cnpjFormat : null,
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
        'chimera-synthetic-identity-documents.txt',
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

  void _selectLocale(String? value) {
    if (value == null || value == _locale) return;
    setState(() {
      _locale = value;
      _type = value == 'us' ? 'ssn' : 'cpf';
      _invalidate();
    });
  }

  void _selectType(String? value) {
    if (value == null || value == _type) return;
    setState(() {
      _type = value;
      _invalidate();
    });
  }

  void _selectCnpjFormat(String? value) {
    if (value == null || value == _cnpjFormat) return;
    setState(() {
      _cnpjFormat = value;
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
                    key: const Key('identity-document-locale'),
                    isExpanded: true,
                    initialValue: _locale,
                    decoration: InputDecoration(
                      labelText: _label('localeLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'us',
                        child: Text(_label('locale.us')),
                      ),
                      DropdownMenuItem(
                        value: 'br',
                        child: Text(_label('locale.br')),
                      ),
                    ],
                    onChanged: _busy ? null : _selectLocale,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('identity-document-type'),
                    isExpanded: true,
                    initialValue: _type,
                    decoration: InputDecoration(
                      labelText: _label('typeLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _types
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(_label('type.$type')),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy ? null : _selectType,
                  ),
                  if (_type == 'cnpj') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: const Key('identity-document-cnpj-format'),
                      isExpanded: true,
                      initialValue: _cnpjFormat,
                      decoration: InputDecoration(
                        labelText: _label('cnpjFormatLabel'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'numeric',
                          child: Text(_label('cnpjFormat.numeric')),
                        ),
                        DropdownMenuItem(
                          value: 'alphanumeric',
                          child: Text(_label('cnpjFormat.alphanumeric')),
                        ),
                      ],
                      onChanged: _busy ? null : _selectCnpjFormat,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('identity-document-count'),
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
                    key: const Key('identity-document-generate'),
                    onPressed: _busy ? null : _generate,
                    child: Text(_label('generate')),
                  ),
                  if (_error case final error?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('identity-document-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_notice case final notice?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        notice,
                        key: const Key('identity-document-notice'),
                      ),
                    ),
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    Focus(
                      focusNode: _resultFocus,
                      child: Semantics(
                        key: const Key('identity-document-result'),
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
                              key: const Key(
                                'identity-document-synthetic-label',
                              ),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            SelectableText(
                              output.values.join('\n'),
                              key: const Key('identity-document-output'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('identity-document-copy'),
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: Text(_label('copy')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('identity-document-save'),
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
