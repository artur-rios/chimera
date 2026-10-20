import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_file_save.dart';

typedef AlphabetDecodeOperationService =
    OperationService<AlphabetDecodeOperationRequest, AlphabetDecodeOutput>;
typedef AlphabetDecodeFilePicker = Future<List<int>?> Function();
typedef AlphabetDecodeClipboardReader = Future<String?> Function();
typedef AlphabetDecodeClipboardWriter = Future<void> Function(String value);
typedef AlphabetDecodeFileSaver = Future<bool> Function(
  String fileName,
  Uint8List bytes,
  String mimeType,
);
typedef AlphabetDecodeOutputEncoder = Uint8List Function(String value);

Future<List<int>?> pickAlphabetDecodeFile() async =>
    (await FilePicker.pickFile())?.readAsBytes();

Future<String?> readAlphabetDecodeClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeAlphabetDecodeClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

Uint8List encodeAlphabetDecodeOutput(String value) => utf8.encode(value);

Future<bool> saveAlphabetDecodeFile(
  String name,
  Uint8List bytes,
  String mimeType, {
  LocalSaveLocationChooser? chooseLocation,
  LocalFileTransactionWriter? writeTransaction,
}) => saveLocalFile(
  name,
  bytes,
  mimeType,
  extensions: const ['txt'],
  chooseLocation: chooseLocation,
  writeTransaction: writeTransaction,
);

final class AlphabetDecodePage extends StatefulWidget {
  const AlphabetDecodePage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.clipboardReader,
    required this.clipboardWriter,
    required this.fileSaver,
    required this.outputEncoder,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final AlphabetDecodeOperationService service;
  final AlphabetDecodeFilePicker filePicker;
  final AlphabetDecodeClipboardReader clipboardReader;
  final AlphabetDecodeClipboardWriter clipboardWriter;
  final AlphabetDecodeFileSaver fileSaver;
  final AlphabetDecodeOutputEncoder outputEncoder;

  @override
  State<AlphabetDecodePage> createState() => _AlphabetDecodePageState();
}

final class _AlphabetDecodePageState extends State<AlphabetDecodePage> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode(debugLabel: 'Alphabet decoding input');
  final _resultFocus = FocusNode(debugLabel: 'Alphabet decoding result');
  List<int>? _fileBytes;
  AlphabetDecodeOutput? _output;
  String? _error;
  String? _notice;
  String _alphabet = 'morse';
  int _editorGeneration = 0;
  int _generation = 0;
  bool _busy = false;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'alphabetDecode.$key');

  void _clearSource() {
    _fileBytes = null;
    _inputController.clear();
    _editorGeneration++;
  }

  void _clearResult() {
    _generation++;
    _output = null;
    _error = null;
    _notice = null;
  }

  bool _current(int generation) => mounted && generation == _generation;

  int _begin({bool preserveResult = false}) {
    setState(() {
      if (preserveResult) {
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
      _clearSource();
      _busy = false;
      _error = widget.catalog.lookup(
        widget.localeTag,
        'error.alphabetDecode.$key',
      );
    });
  }

  Future<void> _decode() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final request = _fileBytes == null
          ? AlphabetDecodeOperationRequest.text(
              _inputController.text,
              alphabet: _alphabet,
            )
          : AlphabetDecodeOperationRequest.utf8Bytes(
              _fileBytes!,
              alphabet: _alphabet,
            );
      setState(_clearSource);
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
          FailureKind.processing || FailureKind.unexpected => 'processing',
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

  Future<void> _loadFile() async {
    if (_busy) return;
    final generation = _begin(preserveResult: true);
    try {
      final bytes = await widget.filePicker();
      if (!_current(generation)) return;
      setState(() {
        if (bytes != null) {
          _clearResult();
          _clearSource();
          _fileBytes = List<int>.unmodifiable(bytes);
        }
        _busy = false;
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'fileAccess');
    }
  }

  Future<void> _paste() async {
    if (_busy) return;
    final generation = _begin(preserveResult: true);
    try {
      final text = await widget.clipboardReader();
      if (!_current(generation)) return;
      if (text != null && !_isScalarText(text)) {
        _fail(generation, 'validation');
        return;
      }
      setState(() {
        if (text != null) {
          _clearResult();
          _clearSource();
          _inputController.text = text;
        }
        _busy = false;
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'clipboardRead');
    }
  }

  Future<void> _copy() async {
    final output = _output;
    if (_busy || output == null) return;
    final generation = _begin(preserveResult: true);
    try {
      await widget.clipboardWriter(output.decoded);
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
    final generation = _begin(preserveResult: true);
    try {
      final saved = await widget.fileSaver(
        'chimera-alphabet-decoded.txt',
        widget.outputEncoder(output.decoded),
        'text/plain; charset=utf-8',
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
    }
  }

  void _textChanged() => setState(() {
    _fileBytes = null;
    _busy = false;
    _clearResult();
  });

  void _alphabetChanged(String? value) {
    if (value == null || value == _alphabet) return;
    setState(() {
      _alphabet = value;
      _busy = false;
      _clearResult();
    });
  }

  bool _isScalarText(String text) {
    for (var index = 0; index < text.length; index++) {
      final unit = text.codeUnitAt(index);
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++index == text.length) return false;
        final next = text.codeUnitAt(index);
        if (next < 0xdc00 || next > 0xdfff) return false;
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        return false;
      }
    }
    return true;
  }

  Widget _ordered(double order, Widget child) =>
      FocusTraversalOrder(order: NumericFocusOrder(order), child: child);

  String _symbolReference(AlphabetDecodeOutput output) => output
      .mapping
      .symbols
      .entries
      .map((entry) => '${entry.key} = ${entry.value}')
      .join('\n');

  String _mappingSemanticsValue(AlphabetDecodeOutput output) =>
      '${output.mapping.id}; ${output.mapping.edition}; '
      '${output.mapping.sources.join('; ')}; '
      '${_symbolReference(output)}; ${output.mapping.rules.join('; ')}';

  @override
  void dispose() {
    _generation++;
    _fileBytes = null;
    _output = null;
    _inputController.dispose();
    _inputFocus.dispose();
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
              policy: OrderedTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ordered(
                    1,
                    KeyedSubtree(
                      key: ValueKey(_editorGeneration),
                      child: TextField(
                        key: const Key('alphabet-decode-input'),
                        controller: _inputController,
                        focusNode: _inputFocus,
                        autofocus: _editorGeneration == 0,
                        enabled: !_busy,
                        minLines: 3,
                        maxLines: 8,
                        onChanged: (_) => _textChanged(),
                        decoration: InputDecoration(
                          labelText: _label('inputLabel'),
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ordered(
                        2,
                        OutlinedButton.icon(
                          key: const Key('alphabet-decode-file'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _busy ? null : _loadFile,
                          icon: const Icon(Icons.file_open),
                          label: Text(_label('fileAction')),
                        ),
                      ),
                      _ordered(
                        3,
                        OutlinedButton.icon(
                          key: const Key('alphabet-decode-paste'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _busy ? null : _paste,
                          icon: const Icon(Icons.content_paste),
                          label: Text(_label('pasteAction')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ordered(
                    4,
                    DropdownButtonFormField<String>(
                      key: const Key('alphabet-decode-alphabet'),
                      initialValue: _alphabet,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _label('alphabetLabel'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final value in const ['morse', 'nato', 'braille'])
                          DropdownMenuItem(
                            value: value,
                            child: Text(_label('alphabet.$value')),
                          ),
                      ],
                      onChanged: _busy ? null : _alphabetChanged,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ordered(
                    5,
                    ElevatedButton(
                      key: const Key('alphabet-decode-submit'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _busy ? null : _decode,
                      child: Text(_label('submitAction')),
                    ),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('alphabet-decode-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  if (_notice case final notice?) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        notice,
                        key: const Key('alphabet-decode-notice'),
                      ),
                    ),
                  ],
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    _ordered(
                      6,
                      Focus(
                        focusNode: _resultFocus,
                        child: Semantics(
                          key: const Key('alphabet-decode-result'),
                          container: true,
                          focusable: true,
                          liveRegion: true,
                          explicitChildNodes: true,
                          role: SemanticsRole.region,
                          label: _label('outputLabel'),
                          value: '${_label('resultSuccess')} ${output.decoded}',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              output.decoded,
                              key: const Key('alphabet-decode-output'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      key: const Key('alphabet-decode-mapping'),
                      container: true,
                      explicitChildNodes: true,
                      role: SemanticsRole.region,
                      label: _label('mappingLabel'),
                      value: _mappingSemanticsValue(output),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _label('mappingLabel'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(_label('mappingIdLabel')),
                              SelectableText(output.mapping.id),
                              Text(_label('mappingEditionLabel')),
                              SelectableText(output.mapping.edition),
                              Text(_label('mappingSourcesLabel')),
                              for (final source in output.mapping.sources)
                                SelectableText(source),
                              Text(_label('mappingSymbolsLabel')),
                              SelectableText(_symbolReference(output)),
                              Text(_label('mappingRulesLabel')),
                              for (final rule in output.mapping.rules)
                                Text(' $rule'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ordered(
                      7,
                      OutlinedButton.icon(
                        key: const Key('alphabet-decode-copy'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy ? null : _copy,
                        icon: const Icon(Icons.copy),
                        label: Text(_label('copyAction')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ordered(
                      8,
                      OutlinedButton.icon(
                        key: const Key('alphabet-decode-save'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.save_alt),
                        label: Text(_label('saveAction')),
                      ),
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
