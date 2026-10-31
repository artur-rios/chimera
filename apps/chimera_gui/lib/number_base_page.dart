import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef NumberBaseFilePicker = Future<String?> Function();
typedef NumberBaseFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef NumberBaseClipboardReader = Future<String?> Function();
typedef NumberBaseClipboardWriter = Future<void> Function(String value);

Future<String?> pickNumberBaseFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

Future<bool> saveNumberBaseFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'text/plain',
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return uri != null;
}

Future<String?> readNumberBaseClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeNumberBaseClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class NumberBasePage extends StatefulWidget {
  const NumberBasePage({
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
  final NumberBaseService service;
  final NumberBaseFilePicker filePicker;
  final NumberBaseFileSaver fileSaver;
  final NumberBaseClipboardReader clipboardReader;
  final NumberBaseClipboardWriter clipboardWriter;

  @override
  State<NumberBasePage> createState() => _NumberBasePageState();
}

final class _NumberBasePageState extends State<NumberBasePage> {
  static final List<int> _bases = List<int>.unmodifiable(
    List<int>.generate(35, (index) => index + 2),
  );

  late final TextEditingController _inputController;
  NumberBaseOutput? _output;
  String? _error;
  String? _notice;
  int _sourceBase = 10;
  int _targetBase = 16;
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: '255');
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _output = null;
      _error = null;
      _notice = null;
    });
    final result = await widget.service.execute(
      NumberBaseOperationRequest(
        value: _inputController.text,
        sourceBase: _sourceBase,
        targetBase: _targetBase,
      ),
    );
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      result.fold(
        onSuccess: (value) {
          _output = value;
          return null;
        },
        onFailure: (failure) {
          _error = _message(failure.messageKey);
          return null;
        },
      );
    });
  }

  Future<void> _loadFile() =>
      _loadInput(widget.filePicker, errorKey: 'error.numberBase.fileAccess');

  Future<void> _paste() => _loadInput(
    widget.clipboardReader,
    errorKey: 'error.numberBase.clipboardRead',
  );

  Future<void> _loadInput(
    Future<String?> Function() loader, {
    required String errorKey,
  }) async {
    setState(() {
      _isRunning = true;
      _output = null;
      _error = null;
      _notice = null;
    });
    try {
      final value = await loader();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (value != null) _inputController.text = value;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message(errorKey);
      });
    }
  }

  Future<void> _copy() async {
    final output = _output;
    if (output == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.clipboardWriter(output.converted);
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _notice = _message('numberBase.copiedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.numberBase.clipboardWrite');
      });
    }
  }

  Future<void> _save() async {
    final output = _output;
    if (output == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      final saved = await widget.fileSaver(
        'chimera-converted-number.txt',
        utf8.encode(output.converted),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('numberBase.savedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.numberBase.outputAccess');
      });
    }
  }

  void _selectSourceBase(int? value) {
    if (value == null) return;
    setState(() {
      _sourceBase = value;
      _clearFeedback();
    });
  }

  void _selectTargetBase(int? value) {
    if (value == null) return;
    setState(() {
      _targetBase = value;
      _clearFeedback();
    });
  }

  void _clearFeedback() {
    _output = null;
    _error = null;
    _notice = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('numberBase.pageTitle'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    key: const Key('number-base-input'),
                    controller: _inputController,
                    autofocus: true,
                    enabled: !_isRunning,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (!_isRunning) setState(_clearFeedback);
                    },
                    onSubmitted: _isRunning ? null : (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: _message('numberBase.inputLabel'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('number-base-file'),
                    onPressed: _isRunning ? null : _loadFile,
                    icon: const Icon(Icons.file_open),
                    label: Text(_message('numberBase.fileAction')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('number-base-paste'),
                    onPressed: _isRunning ? null : _paste,
                    icon: const Icon(Icons.content_paste),
                    label: Text(_message('numberBase.pasteAction')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: const Key('number-base-source'),
                    initialValue: _sourceBase,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _message('numberBase.sourceBaseLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _baseItems(),
                    onChanged: _isRunning ? null : _selectSourceBase,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: const Key('number-base-target'),
                    initialValue: _targetBase,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _message('numberBase.targetBaseLabel'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _baseItems(),
                    onChanged: _isRunning ? null : _selectTargetBase,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('number-base-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('numberBase.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('number-base-error'),
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
                    Semantics(
                      key: const Key('number-base-result-semantics'),
                      liveRegion: true,
                      label: _message('numberBase.resultLabel'),
                      value: output.converted,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          output.converted,
                          key: const Key('number-base-result'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('number-base-copy'),
                      onPressed: _isRunning ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: Text(_message('numberBase.copyAction')),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('number-base-save'),
                      onPressed: _isRunning ? null : _save,
                      icon: const Icon(Icons.save_alt),
                      label: Text(_message('numberBase.saveAction')),
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

  List<DropdownMenuItem<int>> _baseItems() => _bases
      .map((base) => DropdownMenuItem<int>(value: base, child: Text('$base')))
      .toList(growable: false);
}
