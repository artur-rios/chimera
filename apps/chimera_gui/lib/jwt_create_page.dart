import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef JwtCreateOperationService =
    OperationService<JwtCreateOperationRequest, JwtCreateOutput>;
typedef JwtCreateFilePicker = Future<List<int>?> Function(String field);
typedef JwtCreateClipboardReader = Future<String?> Function(String field);
typedef JwtCreateClipboardWriter = Future<void> Function(String value);
typedef JwtCreateFileSaver = Future<bool> Function(
  String fileName,
  Uint8List bytes,
  String mimeType,
);

Future<List<int>?> pickJwtCreateFile(String _) async =>
    (await FilePicker.pickFile())?.readAsBytes();

Future<String?> readJwtCreateClipboard(String _) async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeJwtCreateClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

Future<bool> saveJwtCreateFile(
  String name,
  Uint8List bytes,
  String mimeType,
) async {
  final result = await FilePicker.saveFile(
    fileName: name,
    bytes: bytes,
    mimeType: mimeType,
    type: FileType.custom,
    allowedExtensions: <String>['txt', 'jwt'],
  );
  return kIsWeb || result != null;
}

final class JwtCreatePage extends StatefulWidget {
  const JwtCreatePage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.clipboardReader,
    required this.clipboardWriter,
    required this.fileSaver,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final JwtCreateOperationService service;
  final JwtCreateFilePicker filePicker;
  final JwtCreateClipboardReader clipboardReader;
  final JwtCreateClipboardWriter clipboardWriter;
  final JwtCreateFileSaver fileSaver;

  @override
  State<JwtCreatePage> createState() => _JwtCreatePageState();
}

final class _JwtCreatePageState extends State<JwtCreatePage> {
  static const _algorithms = <String>[
    'HS256',
    'HS384',
    'HS512',
    'RS256',
    'RS384',
    'RS512',
    'ES256',
    'ES256K',
    'ES384',
    'ES512',
  ];

  final _header = TextEditingController(text: '{}');
  final _claims = TextEditingController(text: '{}');
  final _key = TextEditingController();
  final _resultFocus = FocusNode(debugLabel: 'JWT result');
  var _algorithm = 'HS256';
  var _editorGeneration = 0;
  var _generation = 0;
  var _busy = false;
  JwtCreateOutput? _output;
  String? _error;
  String? _notice;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'jwtCreate.$key');

  void _clearEditors() {
    _header.text = '{}';
    _claims.text = '{}';
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
      _error = widget.catalog.lookup(widget.localeTag, 'error.jwtCreate.$key');
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

  Future<void> _create() async {
    if (_busy) return;
    final generation = _begin();
    final request = JwtCreateOperationRequest(
      headerJson: _header.text,
      claimsJson: _claims.text,
      algorithm: _algorithm,
      key: _key.text,
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
      await widget.clipboardWriter(output.token);
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

  Future<void> _save() async {
    final output = _output;
    if (_busy || output == null) return;
    final generation = _begin(keepResult: true);
    Uint8List? bytes;
    try {
      bytes = utf8.encode(output.token);
      final saved = await widget.fileSaver(
        'chimera-jwt.txt',
        bytes,
        'application/jwt',
      );
      if (!_current(generation)) return;
      setState(() {
        _busy = false;
        if (saved) _notice = _label('fileSaved');
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'outputAccess');
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
    }
  }

  @override
  void dispose() {
    _generation++;
    _clearEditors();
    _output = null;
    _header.dispose();
    _claims.dispose();
    _key.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  Widget _editor({
    required String field,
    required TextEditingController controller,
    required String label,
    required bool obscure,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      KeyedSubtree(
        key: ValueKey<String>('$field-$_editorGeneration'),
        child: TextField(
          key: Key('jwt-create-$field'),
          controller: controller,
          enabled: !_busy,
          obscureText: obscure,
          enableSuggestions: !obscure,
          autocorrect: !obscure,
          minLines: obscure ? 1 : 3,
          maxLines: obscure ? 1 : 8,
          onChanged: _sourceChanged,
          decoration: InputDecoration(
            labelText: label,
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
            key: Key('jwt-create-$field-file'),
            onPressed: _busy ? null : () => _load(field, controller),
            icon: const Icon(Icons.file_open),
            label: Text(_label('${field}FileAction')),
          ),
          OutlinedButton.icon(
            key: Key('jwt-create-$field-paste'),
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
                DropdownButtonFormField<String>(
                  key: const Key('jwt-create-algorithm'),
                  initialValue: _algorithm,
                  decoration: InputDecoration(
                    labelText: _label('algorithmLabel'),
                    border: const OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final algorithm in _algorithms)
                      DropdownMenuItem<String>(
                        value: algorithm,
                        child: Text(algorithm),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _algorithm = value;
                            _clearResult();
                          });
                        },
                ),
                const SizedBox(height: 16),
                _editor(
                  field: 'header',
                  controller: _header,
                  label: _label('headerLabel'),
                  obscure: false,
                ),
                const SizedBox(height: 16),
                _editor(
                  field: 'claims',
                  controller: _claims,
                  label: _label('claimsLabel'),
                  obscure: false,
                ),
                const SizedBox(height: 16),
                _editor(
                  field: 'key',
                  controller: _key,
                  label: _label('keyLabel'),
                  obscure: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('jwt-create-submit'),
                  onPressed: _busy ? null : _create,
                  child: Text(_label('submitAction')),
                ),
                if (_error case final error?) ...<Widget>[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      key: const Key('jwt-create-error'),
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
                    child: Text(notice, key: const Key('jwt-create-notice')),
                  ),
                ],
                if (_output case final output?) ...<Widget>[
                  const SizedBox(height: 24),
                  Focus(
                    focusNode: _resultFocus,
                    child: Semantics(
                      key: const Key('jwt-create-result'),
                      container: true,
                      focusable: true,
                      liveRegion: true,
                      excludeSemantics: true,
                      role: SemanticsRole.region,
                      label: _label('outputLabel'),
                      value: _label('resultSuccess'),
                      child: SelectableText(
                        output.token,
                        key: const Key('jwt-create-output'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('jwt-create-copy'),
                    onPressed: _busy ? null : _copy,
                    icon: const Icon(Icons.copy),
                    label: Text(_label('copyAction')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('jwt-create-save'),
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_alt),
                    label: Text(_label('saveAction')),
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
