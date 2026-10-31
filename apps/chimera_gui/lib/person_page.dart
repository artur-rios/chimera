import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_file_save.dart';

typedef PersonOperationService =
    OperationService<PersonOperationRequest, PersonOutput>;
typedef PersonClipboardWriter = Future<void> Function(String value);
typedef PersonFileSaver = Future<bool> Function(
  String name,
  Uint8List bytes,
  String mimeType,
);
typedef PersonOutputEncoder = Uint8List Function(String value);

Future<void> writePersonClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));
Uint8List encodePersonOutput(String value) => utf8.encode(value);
Future<bool> savePersonFile(String name, Uint8List bytes, String mimeType) =>
    saveLocalFile(name, bytes, mimeType, extensions: const ['txt']);

final class PersonPage extends StatefulWidget {
  const PersonPage({
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
  final PersonOperationService service;
  final PersonClipboardWriter clipboardWriter;
  final PersonFileSaver fileSaver;
  final PersonOutputEncoder outputEncoder;

  @override
  State<PersonPage> createState() => _PersonPageState();
}

final class _PersonPageState extends State<PersonPage> {
  final _minAge = TextEditingController(text: '18');
  final _maxAge = TextEditingController(text: '90');
  final _count = TextEditingController(text: '1');
  final _resultFocus = FocusNode(debugLabel: 'Person result');
  String _locale = 'us';
  PersonOutput? _output;
  String? _error;
  String? _notice;
  bool _busy = false;
  int _generation = 0;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'person.$key');
  bool _current(int generation) => mounted && generation == _generation;
  String? get _body => _output == null ? null : _formatPeople(_output!);
  String? get _text =>
      _body == null ? null : '${_label('syntheticLabel')}\n$_body';

  String _formatPeople(PersonOutput output) {
    final lines = <String>[];
    for (var index = 0; index < output.people.length; index++) {
      final person = output.people[index];
      if (index > 0) lines.add('');
      lines
        ..add('${_label('entryLabel')} ${index + 1}')
        ..add(
          '${_label('nameLabel')}: ${person.givenName} ${person.familyName}',
        )
        ..add('${_label('birthDateLabel')}: ${_dateText(person.birthDate)}')
        ..add(
          '${_label('addressLabel')}: ${person.address.street}, '
          '${person.address.city}, ${person.address.region} '
          '${person.address.postalCode}, ${person.address.countryCode}',
        )
        ..add('${_label('phoneLabel')}: ${person.phone}')
        ..add('${_label('emailLabel')}: ${person.email}')
        ..add('${_label('identifiersLabel')}:');
      for (final identifier in person.identifiers) {
        lines.add(
          '  ${identifier.type.name.toUpperCase()}: ${identifier.value}',
        );
      }
    }
    return lines.join('\n');
  }

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
      _error = widget.catalog.lookup(widget.localeTag, 'error.person.$key');
    });
  }

  Future<void> _generate() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final result = await widget.service.execute(
        PersonOperationRequest(
          locale: _locale,
          minAge: _minAge.text,
          maxAge: _maxAge.text,
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
        'chimera-synthetic-people.txt',
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
      _invalidate();
    });
  }

  @override
  void dispose() {
    _generation++;
    _output = null;
    _minAge.dispose();
    _maxAge.dispose();
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
                    key: const Key('person-locale'),
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
                  TextField(
                    key: const Key('person-min-age'),
                    controller: _minAge,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _label('minAgeLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(_invalidate),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('person-max-age'),
                    controller: _maxAge,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _label('maxAgeLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(_invalidate),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('person-count'),
                    controller: _count,
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
                    key: const Key('person-generate'),
                    onPressed: _busy ? null : _generate,
                    child: Text(_label('generate')),
                  ),
                  if (_error case final error?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('person-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_notice case final notice?)
                    Semantics(
                      liveRegion: true,
                      child: Text(notice, key: const Key('person-notice')),
                    ),
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    Focus(
                      focusNode: _resultFocus,
                      child: Semantics(
                        key: const Key('person-result'),
                        container: true,
                        focusable: true,
                        liveRegion: true,
                        excludeSemantics: true,
                        role: SemanticsRole.region,
                        label: _label('resultLabel'),
                        value:
                            '${_label('success')} ${_label('syntheticLabel')} ${_formatPeople(output)}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _label('resultLabel'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              _label('syntheticLabel'),
                              key: const Key('person-synthetic-label'),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            SelectableText(
                              _formatPeople(output),
                              key: const Key('person-output'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('person-copy'),
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: Text(_label('copy')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('person-save'),
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

String _dateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
