import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef CertificateInspectOperationService =
    OperationService<
      CertificateInspectOperationRequest,
      CertificateInspectOutput
    >;
typedef CertificateInspectFilePicker = Future<List<int>?> Function();
typedef CertificateInspectClipboardReader = Future<String?> Function();
typedef CertificateInspectClipboardWriter = Future<void> Function(String value);

Future<List<int>?> pickCertificateInspectFile() async {
  final file = await FilePicker.pickFile();
  return await file?.readAsBytes();
}

Future<String?> readCertificateInspectClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeCertificateInspectClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class CertificateInspectPage extends StatefulWidget {
  const CertificateInspectPage({
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
  final CertificateInspectOperationService service;
  final CertificateInspectFilePicker filePicker;
  final CertificateInspectClipboardReader clipboardReader;
  final CertificateInspectClipboardWriter clipboardWriter;

  @override
  State<CertificateInspectPage> createState() => _CertificateInspectPageState();
}

final class _CertificateInspectPageState extends State<CertificateInspectPage> {
  final _inputController = TextEditingController();
  final _resultFocus = FocusNode(debugLabel: 'Certificate inspection result');
  CertificateInputRepresentation _representation =
      CertificateInputRepresentation.auto;
  List<int>? _fileBytes;
  CertificateInspectOutput? _output;
  String? _metadata;
  String? _error;
  String? _notice;
  bool _busy = false;
  int _generation = 0;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);
  String _label(String key) => _message('certificateInspect.$key');

  @override
  void dispose() {
    _generation++;
    _fileBytes = null;
    _output = null;
    _metadata = null;
    _inputController.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  void _clearResult() {
    _generation++;
    _output = null;
    _metadata = null;
    _error = null;
    _notice = null;
  }

  void _clearSource() {
    _fileBytes = null;
    _inputController.clear();
  }

  bool _current(int generation) => mounted && generation == _generation;

  int _begin({bool clearSource = false}) {
    setState(() {
      _clearResult();
      if (clearSource) _clearSource();
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
      _error = _message(key);
    });
  }

  Future<void> _inspect() async {
    if (_busy) return;
    final generation = _begin();
    try {
      final bytes = _fileBytes;
      final request = bytes == null
          ? CertificateInspectOperationRequest.fromText(
              _inputController.text,
              representation: _representation,
            )
          : CertificateInspectOperationRequest.fromBytes(
              bytes,
              representation: _representation,
            );
      final result = await widget.service.execute(request);
      if (!_current(generation)) return;
      result.fold(
        onSuccess: (output) {
          final metadata = _report(output);
          setState(() {
            _busy = false;
            _output = output;
            _metadata = metadata;
          });
          _resultFocus.requestFocus();
        },
        onFailure: (failure) => _fail(generation, failure.messageKey),
      );
    } on OutOfMemoryError {
      _fail(generation, 'error.certificateInspect.resource');
    } on Object {
      _fail(generation, 'error.unexpected');
    }
  }

  Future<void> _loadFile() async {
    if (_busy) return;
    final generation = _begin(clearSource: true);
    try {
      final bytes = await widget.filePicker();
      if (!_current(generation)) return;
      setState(() {
        _fileBytes = bytes;
        _busy = false;
      });
    } on OutOfMemoryError {
      _fail(generation, 'error.certificateInspect.resource');
    } on Object {
      _fail(generation, 'error.certificateInspect.fileAccess');
    }
  }

  Future<void> _paste() async {
    if (_busy) return;
    final generation = _begin(clearSource: true);
    try {
      final text = await widget.clipboardReader();
      if (!_current(generation)) return;
      setState(() {
        _inputController.text = text ?? '';
        _busy = false;
      });
    } on OutOfMemoryError {
      _fail(generation, 'error.certificateInspect.resource');
    } on Object {
      _fail(generation, 'error.certificateInspect.clipboardRead');
    }
  }

  Future<void> _copy() async {
    final output = _output;
    if (_busy || output == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.clipboardWriter(jsonEncode(output.toJson()));
      if (!_current(generation)) return;
      setState(() {
        _busy = false;
        _notice = _label('copiedResult');
      });
    } on OutOfMemoryError {
      _fail(generation, 'error.certificateInspect.resource');
    } on Object {
      _fail(generation, 'error.certificateInspect.clipboardWrite');
    }
  }

  void _textChanged(String _) {
    setState(() {
      _fileBytes = null;
      _busy = false;
      _clearResult();
    });
  }

  void _representationChanged(CertificateInputRepresentation value) {
    if (value == _representation) return;
    setState(() {
      _representation = value;
      _busy = false;
      _clearResult();
    });
  }

  String _report(CertificateInspectOutput output) {
    String row(String label, Object value) => '${_label(label)}: $value';
    String algorithm(CertificateAlgorithm value) =>
        value.name == null ? value.oid : '${value.name} (${value.oid})';
    String attribute(CertificateAttribute value) =>
        '${value.name ?? value.oid} (${value.oid}): ${value.value}';
    return <String>[
      row(
        'representationLabel',
        _label('representation.${output.representation.name}'),
      ),
      row('versionLabel', output.version),
      row('serialNumberHexLabel', output.serialNumberHex),
      '${_label('subjectLabel')}:',
      for (final value in output.subject) attribute(value),
      '${_label('issuerLabel')}:',
      for (final value in output.issuer) attribute(value),
      row('notBeforeLabel', output.notBefore.toIso8601String()),
      row('notAfterLabel', output.notAfter.toIso8601String()),
      row('signatureAlgorithmLabel', algorithm(output.signatureAlgorithm)),
      row('publicKeyAlgorithmLabel', algorithm(output.publicKeyAlgorithm)),
      '${_label('extensionsLabel')}:',
      for (final value in output.extensions)
        '${value.name ?? value.oid} (${value.oid}), '
            '${_label('criticalLabel')}: ${_label(value.critical ? 'yes' : 'no')}',
      row('inputByteCountLabel', output.inputByteCount),
      row('derByteCountLabel', output.derByteCount),
    ].join('\n');
  }

  Widget _ordered(double order, Widget child) =>
      FocusTraversalOrder(order: NumericFocusOrder(order), child: child);

  Widget _result(CertificateInspectOutput output) => _ordered(
    6,
    Focus(
      focusNode: _resultFocus,
      child: Semantics(
        key: const Key('certificate-inspect-result-semantics'),
        container: true,
        focusable: true,
        liveRegion: true,
        excludeSemantics: true,
        role: SemanticsRole.region,
        label: _label('outputLabel'),
        value:
            '${_label('resultSuccess')}\n'
            '${_label('representationLabel')}: '
            '${_label('representation.${output.representation.name}')}\n'
            '${_label('subjectCountLabel')}: ${output.subject.length}\n'
            '${_label('issuerCountLabel')}: ${output.issuer.length}\n'
            '${_label('extensionCountLabel')}: ${output.extensions.length}',
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
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  key: const Key('certificate-inspect-metadata-scroll'),
                  child: SelectableText(
                    _metadata!,
                    key: const Key('certificate-inspect-result'),
                  ),
                ),
              ),
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
                      key: const Key('certificate-inspect-input'),
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
                          key: const Key('certificate-inspect-file'),
                          onPressed: _busy ? null : _loadFile,
                          icon: const Icon(Icons.file_open),
                          label: Text(_label('fileAction')),
                        ),
                      ),
                      _ordered(
                        3,
                        OutlinedButton.icon(
                          key: const Key('certificate-inspect-paste'),
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
                        key: const Key('certificate-inspect-file-summary'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(_label('representationLabel')),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in CertificateInputRepresentation.values)
                        _ordered(
                          4 + value.index / 10,
                          ChoiceChip(
                            key: Key(
                              'certificate-inspect-representation-${value.name}',
                            ),
                            label: Text(_label('representation.${value.name}')),
                            selected: value == _representation,
                            onSelected: _busy
                                ? null
                                : (_) => _representationChanged(value),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ordered(
                    5,
                    ElevatedButton(
                      key: const Key('certificate-inspect-submit'),
                      onPressed: _busy ? null : _inspect,
                      child: Text(_label('submitAction')),
                    ),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('certificate-inspect-error'),
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
                        key: const Key('certificate-inspect-notice'),
                      ),
                    ),
                  ],
                  if (_output case final output?) ...[
                    const SizedBox(height: 24),
                    _result(output),
                    const SizedBox(height: 8),
                    _ordered(
                      7,
                      OutlinedButton.icon(
                        key: const Key('certificate-inspect-copy'),
                        onPressed: _busy ? null : _copy,
                        icon: const Icon(Icons.copy),
                        label: Text(_label('copyAction')),
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
