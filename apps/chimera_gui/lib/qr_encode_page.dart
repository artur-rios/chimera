import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef QrEncodeOperationService =
    OperationService<QrEncodeOperationRequest, QrEncodeOutput>;
typedef QrEncodeFilePicker = Future<List<int>?> Function();
typedef QrEncodeClipboardReader = Future<String?> Function();
typedef QrEncodeFileSaver = Future<bool> Function(
  String fileName,
  Uint8List bytes,
  String mimeType,
);

Future<List<int>?> pickQrEncodeFile() async =>
    (await FilePicker.pickFile())?.readAsBytes();

Future<String?> readQrEncodeClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<bool> saveQrEncodeFile(
  String fileName,
  Uint8List bytes,
  String mimeType,
) async {
  final result = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    type: FileType.custom,
    allowedExtensions: const <String>['png'],
  );
  return kIsWeb || result != null;
}

final class QrEncodePage extends StatefulWidget {
  const QrEncodePage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.filePicker,
    required this.clipboardReader,
    required this.fileSaver,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final QrEncodeOperationService service;
  final QrEncodeFilePicker filePicker;
  final QrEncodeClipboardReader clipboardReader;
  final QrEncodeFileSaver fileSaver;

  @override
  State<QrEncodePage> createState() => _QrEncodePageState();
}

final class _QrEncodePageState extends State<QrEncodePage> {
  final _input = TextEditingController();
  final _size = TextEditingController(text: '512');
  final _margin = TextEditingController(text: '4');
  final _foreground = TextEditingController(text: '#000000');
  final _background = TextEditingController(text: '#FFFFFF');
  final _inputFocus = FocusNode(debugLabel: 'QR encode input');
  final _resultFocus = FocusNode(debugLabel: 'QR encode result');
  var _correction = QrErrorCorrection.medium;
  var _busy = false;
  var _editorGeneration = 0;
  QrEncodeOutput? _output;
  String? _error;
  String? _notice;

  String _label(String key) =>
      widget.catalog.lookup(widget.localeTag, 'qrEncode.$key');

  @override
  void dispose() {
    _clearSource();
    _output = null;
    _input.dispose();
    _size.dispose();
    _margin.dispose();
    _foreground.dispose();
    _background.dispose();
    _inputFocus.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  void _clearSource() {
    _input.clear();
    // Rebuild the editor so Flutter drops its UndoHistory snapshots too.
    _editorGeneration++;
  }

  void _clearFeedback() {
    _output = null;
    _error = null;
    _notice = null;
  }

  void _changed([Object? _]) {
    if (_busy) return;
    setState(_clearFeedback);
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _clearFeedback();
    });
    final result = await widget.service.execute(
      QrEncodeOperationRequest(
        text: _input.text,
        errorCorrection: _correction,
        size: int.tryParse(_size.text) ?? -1,
        quietZoneModules: int.tryParse(_margin.text) ?? -1,
        foreground: _foreground.text,
        background: _background.text,
      ),
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (value) {
        setState(() {
          _clearSource();
          _output = value;
          _busy = false;
        });
        _resultFocus.requestFocus();
      },
      onFailure: (failure) {
        setState(() {
          _clearSource();
          _error = widget.catalog.lookup(widget.localeTag, failure.messageKey);
          _busy = false;
        });
      },
    );
  }

  Future<void> _loadFile() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _clearFeedback();
    });
    try {
      final bytes = await widget.filePicker();
      if (!mounted) return;
      if (bytes != null && bytes.length > QrEncoder.defaultMaxInputBytes) {
        _adapterFailure('error.qrEncode.resource');
        return;
      }
      final value = bytes == null
          ? null
          : utf8.decode(bytes, allowMalformed: false);
      setState(() {
        _busy = false;
        if (value != null) _input.text = value;
      });
    } on FormatException {
      _adapterFailure('error.qrEncode.validation');
    } on OutOfMemoryError {
      _adapterFailure('error.qrEncode.resource');
    } on Object {
      _adapterFailure('error.qrEncode.fileAccess');
    }
  }

  Future<void> _paste() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _clearFeedback();
    });
    try {
      final value = await widget.clipboardReader();
      if (!mounted) return;
      if (value != null && QrEncoder.inputExceedsByteLimit(value)) {
        _adapterFailure('error.qrEncode.resource');
        return;
      }
      setState(() {
        _busy = false;
        if (value != null) _input.text = value;
      });
    } on OutOfMemoryError {
      _adapterFailure('error.qrEncode.resource');
    } on Object {
      _adapterFailure('error.qrEncode.clipboardRead');
    }
  }

  Future<void> _save() async {
    final output = _output;
    if (_busy || output == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final saved = await widget.fileSaver(
        'chimera-qr.png',
        output.pngBytes,
        'image/png',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (saved) _notice = _label('fileSaved');
      });
    } on OutOfMemoryError {
      _adapterFailure('error.qrEncode.resource');
    } on Object {
      _adapterFailure('error.qrEncode.outputAccess');
    }
  }

  void _adapterFailure(String key) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _clearSource();
      _output = null;
      _notice = null;
      _error = widget.catalog.lookup(widget.localeTag, key);
    });
  }

  Widget _ordered(double order, Widget child) =>
      FocusTraversalOrder(order: NumericFocusOrder(order), child: child);

  String _correctionLabel(QrErrorCorrection value) =>
      _label('correction.${value.name}');

  Widget _result(QrEncodeOutput output) => _ordered(
    9,
    Focus(
      focusNode: _resultFocus,
      child: Semantics(
        key: const Key('qr-encode-result-semantics'),
        container: true,
        focusable: true,
        liveRegion: true,
        excludeSemantics: true,
        role: SemanticsRole.region,
        label: _label('resultLabel'),
        value:
            '${_label('resultSuccess')} '
            '${output.size} x ${output.size}, '
            '${_label('versionLabel')} ${output.version}, '
            '${_correctionLabel(output.errorCorrection)}.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Image.memory(
                output.pngBytes,
                key: const Key('qr-encode-preview'),
                width: 320,
                height: 320,
                filterQuality: FilterQuality.none,
                semanticLabel: _label('previewLabel'),
              ),
            ),
            const SizedBox(height: 12),
            Text('${output.size} x ${output.size}'),
            Text('${_label('versionLabel')}: ${output.version}'),
            Text(
              '${_label('correctionLabel')}: '
              '${_correctionLabel(output.errorCorrection)}',
            ),
            Text(
              '${_label('outputByteCountLabel')}: ${output.outputByteCount}',
            ),
          ],
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
                children: <Widget>[
                  _ordered(
                    1,
                    KeyedSubtree(
                      key: ValueKey(_editorGeneration),
                      child: TextField(
                        key: const Key('qr-encode-input'),
                        controller: _input,
                        focusNode: _inputFocus,
                        autofocus: _editorGeneration == 0,
                        enabled: !_busy,
                        minLines: 3,
                        maxLines: 8,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onChanged: _changed,
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
                    children: <Widget>[
                      _ordered(
                        2,
                        OutlinedButton.icon(
                          key: const Key('qr-encode-file'),
                          onPressed: _busy ? null : _loadFile,
                          icon: const Icon(Icons.file_open),
                          label: Text(_label('fileAction')),
                        ),
                      ),
                      _ordered(
                        3,
                        OutlinedButton.icon(
                          key: const Key('qr-encode-paste'),
                          onPressed: _busy ? null : _paste,
                          icon: const Icon(Icons.content_paste),
                          label: Text(_label('pasteAction')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ordered(
                    4,
                    DropdownButtonFormField<QrErrorCorrection>(
                      key: const Key('qr-encode-correction'),
                      initialValue: _correction,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _label('correctionLabel'),
                        border: const OutlineInputBorder(),
                      ),
                      items: QrErrorCorrection.values
                          .map(
                            (value) => DropdownMenuItem<QrErrorCorrection>(
                              value: value,
                              child: Text(_correctionLabel(value)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _correction = value;
                                _clearFeedback();
                              });
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ordered(
                          5,
                          TextField(
                            key: const Key('qr-encode-size'),
                            controller: _size,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            onChanged: _changed,
                            decoration: InputDecoration(
                              labelText: _label('sizeLabel'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ordered(
                          6,
                          TextField(
                            key: const Key('qr-encode-margin'),
                            controller: _margin,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            onChanged: _changed,
                            decoration: InputDecoration(
                              labelText: _label('marginLabel'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ordered(
                          7,
                          TextField(
                            key: const Key('qr-encode-foreground'),
                            controller: _foreground,
                            enabled: !_busy,
                            onChanged: _changed,
                            decoration: InputDecoration(
                              labelText: _label('foregroundLabel'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ordered(
                          8,
                          TextField(
                            key: const Key('qr-encode-background'),
                            controller: _background,
                            enabled: !_busy,
                            onChanged: _changed,
                            decoration: InputDecoration(
                              labelText: _label('backgroundLabel'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ordered(
                    8.5,
                    ElevatedButton(
                      key: const Key('qr-encode-submit'),
                      onPressed: _busy ? null : _generate,
                      child: Text(_label('submitAction')),
                    ),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('qr-encode-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  if (_notice case final notice?) ...<Widget>[
                    const SizedBox(height: 16),
                    Semantics(liveRegion: true, child: Text(notice)),
                  ],
                  if (_output case final output?) ...<Widget>[
                    const SizedBox(height: 24),
                    _result(output),
                    const SizedBox(height: 8),
                    _ordered(
                      10,
                      OutlinedButton.icon(
                        key: const Key('qr-encode-save'),
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
