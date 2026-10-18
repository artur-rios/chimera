import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef JwtInspectOperationService =
    OperationService<JwtInspectOperationRequest, JwtInspectOutput>;
typedef JwtInspectFilePicker = Future<List<int>?> Function(String field);
typedef JwtInspectClipboardReader = Future<String?> Function(String field);
typedef JwtInspectClipboardWriter = Future<void> Function(String value);

Future<List<int>?> pickJwtInspectFile(String _) async {
  final file = await FilePicker.pickFile();
  if (file == null) return null;
  final length = await file.length();
  if (length != null && length > JwtInspector.defaultMaxInputBytes) {
    throw const _JwtInspectInputLimit();
  }
  final bytes = await file.readAsBytes();
  if (bytes.length <= JwtInspector.defaultMaxInputBytes) return bytes;
  bytes.fillRange(0, bytes.length, 0);
  throw const _JwtInspectInputLimit();
}

Future<String?> readJwtInspectClipboard(String _) async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeJwtInspectClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class JwtInspectPage extends StatefulWidget {
  const JwtInspectPage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.clipboardReader,
    required this.clipboardWriter,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final JwtInspectOperationService service;
  final JwtInspectFilePicker filePicker;
  final JwtInspectClipboardReader clipboardReader;
  final JwtInspectClipboardWriter clipboardWriter;

  @override
  State<JwtInspectPage> createState() => _JwtInspectPageState();
}

final class _JwtInspectPageState extends State<JwtInspectPage> {
  final _token = TextEditingController();
  final _key = TextEditingController();
  final _resultFocus = FocusNode(debugLabel: 'JWT inspection result');
  var _editorGeneration = 0;
  var _generation = 0;
  var _busy = false;
  JwtInspectOutput? _output;
  String? _error;
  String? _notice;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'jwtInspect.$key');

  void _clearEditors() {
    _token.clear();
    _key.clear();
    _editorGeneration++;
  }

  void _clearResult() {
    _generation++;
    _output = null;
    _error = null;
    _notice = null;
  }

  bool _current(int generation) => mounted && generation == _generation;

  int _begin({bool keepResult = false}) {
    setState(() {
      if (keepResult) {
        _generation++;
        _error = null;
        _notice = null;
      } else {
        _clearResult();
      }
      _busy = true;
    });
    return _generation;
  }

  void _fail(int generation, String key) {
    if (!_current(generation)) return;
    setState(() {
      _clearResult();
      _clearEditors();
      _busy = false;
      _error = widget.catalog.lookup(widget.localeTag, 'error.jwtInspect.$key');
    });
  }

  void _sourceChanged([String? _]) {
    if (!mounted) return;
    setState(_clearResult);
  }

  Future<void> _load(String field, TextEditingController controller) async {
    if (_busy) return;
    final generation = _begin(keepResult: true);
    List<int>? bytes;
    try {
      bytes = await widget.filePicker(field);
      if (!_current(generation)) return;
      if (bytes != null) {
        if (bytes.length > JwtInspector.defaultMaxInputBytes) {
          throw const _JwtInspectInputLimit();
        }
        final text = utf8.decode(bytes, allowMalformed: false);
        setState(() {
          _output = null;
          _error = null;
          _notice = null;
          controller.text = text;
          _editorGeneration++;
        });
      }
      if (_current(generation)) setState(() => _busy = false);
    } on _JwtInspectInputLimit {
      _fail(generation, 'resource');
    } on FormatException {
      _fail(generation, 'validation');
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'interactiveInputAccess');
    } finally {
      try {
        bytes?.fillRange(0, bytes.length, 0);
      } on Object {
        // Immutable picker bytes are released when this scope ends.
      }
    }
  }

  Future<void> _paste(String field, TextEditingController controller) async {
    if (_busy) return;
    final generation = _begin(keepResult: true);
    try {
      final text = await widget.clipboardReader(field);
      if (!_current(generation)) return;
      if (text != null) {
        setState(() {
          _output = null;
          _error = null;
          _notice = null;
          controller.text = text;
          _editorGeneration++;
        });
      }
      if (_current(generation)) setState(() => _busy = false);
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'clipboardRead');
    }
  }

  Future<void> _inspect() async {
    if (_busy) return;
    final generation = _begin();
    final key = _key.text;
    final request = JwtInspectOperationRequest(
      token: _token.text,
      key: key.isEmpty ? null : key,
    );
    setState(_clearEditors);
    try {
      final result = await widget.service.execute(request);
      if (!_current(generation)) return;
      result.fold(
        onSuccess: (output) {
          setState(() {
            _output = output;
            _busy = false;
          });
          _resultFocus.requestFocus();
        },
        onFailure: (failure) => _fail(generation, switch (failure.kind) {
          FailureKind.resource => 'resource',
          FailureKind.processing => 'processing',
          FailureKind.validation || FailureKind.range => 'validation',
          _ => 'interactiveInputAccess',
        }),
      );
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'interactiveInputAccess');
    }
  }

  Future<void> _copy() async {
    final output = _output;
    if (_busy || output == null) return;
    final generation = _begin(keepResult: true);
    try {
      await widget.clipboardWriter(jsonEncode(output.toJson()));
      if (!_current(generation)) return;
      setState(() {
        _busy = false;
        _notice = _label('copiedResult');
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'clipboardWrite');
    }
  }

  String _verificationLabel(JwtVerificationStatus status) => switch (status) {
    JwtVerificationStatus.notRequested => _label('statusNotRequested'),
    JwtVerificationStatus.verified => _label('statusVerified'),
    JwtVerificationStatus.failed => _label('statusFailed'),
  };

  @override
  void dispose() {
    _generation++;
    _clearEditors();
    _output = null;
    _token.dispose();
    _key.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  Widget _editor({
    required String field,
    required TextEditingController controller,
    required bool obscure,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      KeyedSubtree(
        key: ValueKey<String>('$field-$_editorGeneration'),
        child: TextField(
          key: Key('jwt-inspect-$field'),
          controller: controller,
          enabled: !_busy,
          obscureText: obscure,
          enableSuggestions: !obscure,
          autocorrect: !obscure,
          minLines: obscure ? 1 : 3,
          maxLines: obscure ? 1 : 8,
          onChanged: _sourceChanged,
          decoration: InputDecoration(
            labelText: _label('${field}Label'),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          OutlinedButton.icon(
            key: Key('jwt-inspect-$field-file'),
            onPressed: _busy ? null : () => _load(field, controller),
            icon: const Icon(Icons.file_open),
            label: Text(_label('${field}FileAction')),
          ),
          OutlinedButton.icon(
            key: Key('jwt-inspect-$field-paste'),
            onPressed: _busy ? null : () => _paste(field, controller),
            icon: const Icon(Icons.content_paste),
            label: Text(_label('${field}PasteAction')),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_label('pageTitle'))),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _editor(field: 'token', controller: _token, obscure: false),
                const SizedBox(height: 16),
                _editor(field: 'key', controller: _key, obscure: true),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('jwt-inspect-submit'),
                  onPressed: _busy ? null : _inspect,
                  child: Text(_label('submitAction')),
                ),
                if (_error case final error?) ...<Widget>[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      key: const Key('jwt-inspect-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                if (_notice case final notice?) ...<Widget>[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(notice, key: const Key('jwt-inspect-notice')),
                  ),
                ],
                if (_output case final output?) ...<Widget>[
                  const SizedBox(height: 24),
                  Focus(
                    focusNode: _resultFocus,
                    child: Semantics(
                      key: const Key('jwt-inspect-result'),
                      container: true,
                      focusable: true,
                      liveRegion: true,
                      role: SemanticsRole.region,
                      label: _label('outputLabel'),
                      value: _label('resultSuccess'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(_label('headerLabel')),
                          SelectableText(jsonEncode(output.header)),
                          const SizedBox(height: 12),
                          Text(_label('claimsLabel')),
                          SelectableText(
                            jsonEncode(output.claims),
                            key: const Key('jwt-inspect-output'),
                          ),
                          const SizedBox(height: 12),
                          Text(_label('verificationLabel')),
                          Text(_verificationLabel(output.verification)),
                          if (output.verification ==
                              JwtVerificationStatus.failed) ...<Widget>[
                            const SizedBox(height: 8),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _label('untrustedWarning'),
                                key: const Key('jwt-inspect-untrusted'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('jwt-inspect-copy'),
                    onPressed: _busy ? null : _copy,
                    icon: const Icon(Icons.copy),
                    label: Text(_label('copyAction')),
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

final class _JwtInspectInputLimit implements Exception {
  const _JwtInspectInputLimit();
}
