import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef CertificateConvertOperationService =
    OperationService<
      CertificateConvertOperationRequest,
      CertificateConvertOutput
    >;
typedef CertificateConvertFilePicker = Future<List<int>?> Function();
typedef CertificateConvertFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef CertificateConvertClipboardReader = Future<String?> Function();
typedef CertificateConvertClipboardWriter = Future<void> Function(String value);

Future<List<int>?> pickCertificateConvertFile() async {
  final file = await FilePicker.pickFile();
  return await file?.readAsBytes();
}

Future<bool> saveCertificateConvertFile(String name, List<int> bytes) async {
  // Conversion owns one immutable Uint8List; pass it to the platform unchanged.
  final uri = await FilePicker.saveFile(
    fileName: name,
    bytes: bytes as Uint8List,
    type: FileType.custom,
    allowedExtensions: [name.split('.').last],
  );
  return uri != null;
}

Future<String?> readCertificateConvertClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeCertificateConvertClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class CertificateConvertPage extends StatefulWidget {
  const CertificateConvertPage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.fileSaver,
    required this.clipboardReader,
    required this.clipboardWriter,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final CertificateConvertOperationService service;
  final CertificateConvertFilePicker filePicker;
  final CertificateConvertFileSaver fileSaver;
  final CertificateConvertClipboardReader clipboardReader;
  final CertificateConvertClipboardWriter clipboardWriter;

  @override
  State<CertificateConvertPage> createState() => _CertificateConvertPageState();
}

final class _CertificateConvertPageState extends State<CertificateConvertPage> {
  final _inputController = TextEditingController();
  final _resultFocus = FocusNode(debugLabel: 'Certificate conversion result');
  CertificateInputRepresentation _source = CertificateInputRepresentation.auto;
  CertificateOutputRepresentation _target = CertificateOutputRepresentation.pem;
  List<int>? _fileBytes;
  CertificateConvertOutput? _output;
  String? _text;
  String? _error;
  String? _notice;
  bool _busy = false;
  int _generation = 0;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);
  String _label(String key) => _message('certificateConvert.$key');

  @override
  void dispose() {
    _generation++;
    _clearSource();
    _output = null;
    _text = null;
    _inputController.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  void _clearResult() {
    _generation++;
    _output = null;
    _text = null;
    _error = null;
    _notice = null;
  }

  void _clearSource() {
    _fileBytes = null;
    _inputController.clear();
  }

  bool _current(int generation) => mounted && generation == _generation;

  int _begin({bool preserveResult = false}) {
    setState(() {
      if (preserveResult) {
        _generation++;
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
      _error = _message('error.certificateConvert.$key');
    });
  }

  Future<void> _convert() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final bytes = _fileBytes;
      final request = bytes == null
          ? CertificateConvertOperationRequest.fromText(
              _inputController.text,
              source: _source,
              target: _target,
            )
          : CertificateConvertOperationRequest.fromBytes(
              bytes,
              source: _source,
              target: _target,
            );
      final result = await widget.service.execute(request);
      if (!_current(generation)) return;
      result.fold(
        onSuccess: (output) {
          // Materialization can itself throw a typed allocation failure.
          final text = output.text;
          setState(() {
            _busy = false;
            _output = output;
            _text = text;
          });
          _resultFocus.requestFocus();
        },
        onFailure: (failure) => _fail(generation, switch (failure.kind) {
          FailureKind.resource => 'resource',
          FailureKind.validation || FailureKind.range => 'validation',
          _ => 'inputAccess',
        }),
      );
    } on CertificateConversionResourceException {
      _fail(generation, 'resource');
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on CertificateConversionException {
      _fail(generation, 'validation');
    } on Object {
      _fail(generation, 'inputAccess');
    }
  }

  Future<void> _loadFile() async {
    if (_busy) return;
    // A canceled picker leaves the completed result and its source intact.
    final generation = _begin(preserveResult: true);
    try {
      final bytes = await widget.filePicker();
      if (!_current(generation)) return;
      setState(() {
        if (bytes != null) {
          _clearResult();
          _clearSource();
          _fileBytes = bytes;
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
    final generation = _begin();
    _clearSource();
    try {
      final text = await widget.clipboardReader();
      if (!_current(generation)) return;
      setState(() {
        _inputController.text = text ?? '';
        _busy = false;
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'clipboardRead');
    }
  }

  Future<void> _copy() async {
    final text = _text;
    if (_busy || text == null) return;
    final generation = _begin(preserveResult: true);
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      await widget.clipboardWriter(text);
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
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      final saved = await widget.fileSaver(
        'chimera-certificate.${output.targetRepresentation.name}',
        output.bytes,
      );
      if (!_current(generation)) return;
      setState(() {
        _busy = false;
        if (saved) _notice = _label('savedResult');
      });
    } on OutOfMemoryError {
      _fail(generation, 'resource');
    } on Object {
      _fail(generation, 'outputAccess');
    }
  }

  void _textChanged(String _) {
    setState(() {
      _fileBytes = null;
      _busy = false;
      _clearResult();
    });
  }

  void _sourceChanged(CertificateInputRepresentation value) {
    if (value == _source) return;
    setState(() {
      _source = value;
      _busy = false;
      _clearResult();
    });
  }

  void _targetChanged(CertificateOutputRepresentation value) {
    if (value == _target) return;
    setState(() {
      _target = value;
      _busy = false;
      _clearResult();
    });
  }

  Widget _ordered(double order, Widget child) =>
      FocusTraversalOrder(order: NumericFocusOrder(order), child: child);

  String _summary(CertificateConvertOutput output) =>
      '${_label('sourceLabel')}: ${_label('representation.${output.sourceRepresentation.name}')}\n'
      '${_label('targetLabel')}: ${_label('representation.${output.targetRepresentation.name}')}\n'
      '${_label('inputByteCountLabel')}: ${output.inputByteCount}\n'
      '${_label('derByteCountLabel')}: ${output.derByteCount}\n'
      '${_label('outputByteCountLabel')}: ${output.outputByteCount}';

  Widget _result(CertificateConvertOutput output) => _ordered(
    7,
    Focus(
      focusNode: _resultFocus,
      child: Semantics(
        key: const Key('certificate-convert-result-semantics'),
        container: true,
        focusable: true,
        liveRegion: true,
        excludeSemantics: true,
        role: SemanticsRole.region,
        label: _label('outputLabel'),
        value: '${_label('resultSuccess')}\n${_summary(output)}',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _label('outputLabel'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final line in _summary(output).split('\n')) Text(line),
              if (_text case final text?) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    key: const Key('certificate-convert-text-scroll'),
                    child: SelectableText(
                      text,
                      key: const Key('certificate-convert-result'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
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
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ordered(
                    1,
                    TextField(
                      key: const Key('certificate-convert-input'),
                      controller: _inputController,
                      autofocus: true,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 8,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      onChanged: _textChanged,
                      decoration: InputDecoration(
                        labelText: _label('inputLabel'),
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
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
                          key: const Key('certificate-convert-file'),
                          onPressed: _busy ? null : _loadFile,
                          icon: const Icon(Icons.file_open),
                          label: Text(_label('fileAction')),
                        ),
                      ),
                      _ordered(
                        3,
                        OutlinedButton.icon(
                          key: const Key('certificate-convert-paste'),
                          onPressed: _busy ? null : _paste,
                          icon: const Icon(Icons.content_paste),
                          label: Text(_label('pasteAction')),
                        ),
                      ),
                    ],
                  ),
                  if (_fileBytes case final bytes?) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${_label('inputByteCountLabel')}: ${bytes.length}',
                        key: const Key('certificate-convert-file-summary'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(_label('sourceLabel')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in CertificateInputRepresentation.values)
                        _ordered(
                          4 + value.index / 10,
                          ChoiceChip(
                            key: Key(
                              'certificate-convert-source-${value.name}',
                            ),
                            label: Semantics(
                              label:
                                  '${_label('sourceLabel')}: ${_label('representation.${value.name}')}',
                              excludeSemantics: true,
                              child: Text(
                                _label('representation.${value.name}'),
                              ),
                            ),
                            selected: value == _source,
                            onSelected: _busy
                                ? null
                                : (_) => _sourceChanged(value),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_label('targetLabel')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value
                          in CertificateOutputRepresentation.values)
                        _ordered(
                          5 + value.index / 10,
                          ChoiceChip(
                            key: Key(
                              'certificate-convert-target-${value.name}',
                            ),
                            label: Semantics(
                              label:
                                  '${_label('targetLabel')}: ${_label('representation.${value.name}')}',
                              excludeSemantics: true,
                              child: Text(
                                _label('representation.${value.name}'),
                              ),
                            ),
                            selected: value == _target,
                            onSelected: _busy
                                ? null
                                : (_) => _targetChanged(value),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ordered(
                    6,
                    ElevatedButton(
                      key: const Key('certificate-convert-submit'),
                      onPressed: _busy ? null : _convert,
                      child: Text(_label('submitAction')),
                    ),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('certificate-convert-error'),
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
                        key: const Key('certificate-convert-notice'),
                      ),
                    ),
                  ],
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    _result(output),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_text != null)
                          _ordered(
                            8,
                            OutlinedButton.icon(
                              key: const Key('certificate-convert-copy'),
                              onPressed: _busy ? null : _copy,
                              icon: const Icon(Icons.copy),
                              label: Text(_label('copyAction')),
                            ),
                          ),
                        _ordered(
                          9,
                          OutlinedButton.icon(
                            key: const Key('certificate-convert-save'),
                            onPressed: _busy ? null : _save,
                            icon: const Icon(Icons.save_alt),
                            label: Text(_label('saveAction')),
                          ),
                        ),
                      ],
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
