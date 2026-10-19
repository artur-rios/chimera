import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_file_save.dart';

typedef PasswordOperationService =
    OperationService<PasswordOperationRequest, PasswordOutput>;
typedef PasswordClipboardWriter = Future<void> Function(String value);
typedef PasswordFileSaver = Future<bool> Function(
  String name,
  Uint8List bytes,
  String mimeType,
);
typedef PasswordOutputEncoder = Uint8List Function(String value);

Future<void> writePasswordClipboard(String password) =>
    Clipboard.setData(ClipboardData(text: password));
Uint8List encodePasswordOutput(String password) => utf8.encode(password);
Future<bool> savePasswordFile(String name, Uint8List bytes, String mimeType) =>
    saveLocalFile(name, bytes, mimeType, extensions: const ['txt']);

final class PasswordPage extends StatefulWidget {
  const PasswordPage({
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
  final PasswordOperationService service;
  final PasswordClipboardWriter clipboardWriter;
  final PasswordFileSaver fileSaver;
  final PasswordOutputEncoder outputEncoder;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

final class _PasswordPageState extends State<PasswordPage> {
  final _length = TextEditingController(text: '16');
  final _resultFocus = FocusNode(debugLabel: 'Password result');
  bool _lowercase = true;
  bool _uppercase = true;
  bool _digits = true;
  bool _symbols = true;
  PasswordOutput? _output;
  String? _error;
  String? _notice;
  bool _busy = false;
  int _generation = 0;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'password.$key');
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
      _error = widget.catalog.lookup(widget.localeTag, 'error.password.$key');
    });
  }

  Future<void> _generate() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final result = await widget.service.execute(
        PasswordOperationRequest(
          length: _length.text,
          lowercase: _lowercase,
          uppercase: _uppercase,
          digits: _digits,
          symbols: _symbols,
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
    final output = _output;
    if (_busy || output == null) return;
    final generation = _begin(preserve: true);
    try {
      await widget.clipboardWriter(output.password);
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
        'chimera-password.txt',
        widget.outputEncoder(output.password),
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

  void _setClass(void Function() update) {
    setState(() {
      update();
      _invalidate();
    });
  }

  @override
  void dispose() {
    _generation++;
    _output = null;
    _length.dispose();
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
                  TextField(
                    key: const Key('password-length'),
                    controller: _length,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: _label('lengthLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(_invalidate),
                    onSubmitted: (_) => _generate(),
                  ),
                  const SizedBox(height: 8),
                  _classSwitch(
                    key: 'lowercase',
                    value: _lowercase,
                    onChanged: (value) => _setClass(() => _lowercase = value),
                  ),
                  _classSwitch(
                    key: 'uppercase',
                    value: _uppercase,
                    onChanged: (value) => _setClass(() => _uppercase = value),
                  ),
                  _classSwitch(
                    key: 'digits',
                    value: _digits,
                    onChanged: (value) => _setClass(() => _digits = value),
                  ),
                  _classSwitch(
                    key: 'symbols',
                    value: _symbols,
                    onChanged: (value) => _setClass(() => _symbols = value),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const Key('password-generate'),
                    onPressed: _busy ? null : _generate,
                    child: Text(_label('generate')),
                  ),
                  if (_error case final error?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('password-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_notice case final notice?)
                    Semantics(
                      liveRegion: true,
                      child: Text(notice, key: const Key('password-notice')),
                    ),
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    Focus(
                      focusNode: _resultFocus,
                      child: Semantics(
                        key: const Key('password-result'),
                        container: true,
                        focusable: true,
                        liveRegion: true,
                        excludeSemantics: true,
                        role: SemanticsRole.region,
                        label: _label('resultLabel'),
                        value: '${_label('success')} ${output.password}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _label('resultLabel'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SelectableText(
                              output.password,
                              key: const Key('password-output'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('password-copy'),
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: Text(_label('copy')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('password-save'),
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

  Widget _classSwitch({
    required String key,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    key: Key('password-$key'),
    title: Text(_label(key)),
    value: value,
    onChanged: onChanged,
  );
}
