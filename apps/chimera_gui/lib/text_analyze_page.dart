import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef TextAnalyzeFilePicker = Future<String?> Function();
typedef TextAnalyzeFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef TextAnalyzeClipboardReader = Future<String?> Function();
typedef TextAnalyzeClipboardWriter = Future<void> Function(String value);

Future<String?> pickTextAnalyzeFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

Future<bool> saveTextAnalyzeFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'text/plain',
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return uri != null;
}

Future<String?> readTextAnalyzeClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeTextAnalyzeClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class TextAnalyzePage extends StatefulWidget {
  const TextAnalyzePage({
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
  final TextAnalyzeService service;
  final TextAnalyzeFilePicker filePicker;
  final TextAnalyzeFileSaver fileSaver;
  final TextAnalyzeClipboardReader clipboardReader;
  final TextAnalyzeClipboardWriter clipboardWriter;

  @override
  State<TextAnalyzePage> createState() => _TextAnalyzePageState();
}

final class _TextAnalyzePageState extends State<TextAnalyzePage> {
  late final TextEditingController _inputController;
  TextAnalyzeOutput? _output;
  String? _error;
  String? _notice;
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(
      text: 'Hello, Chimera!\nSecond line.',
    );
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
      _clearFeedback();
    });
    final result = await widget.service.execute(
      TextAnalyzeOperationRequest(input: _inputController.text),
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
      _loadInput(widget.filePicker, errorKey: 'error.textAnalyze.fileAccess');

  Future<void> _paste() => _loadInput(
    widget.clipboardReader,
    errorKey: 'error.textAnalyze.clipboardRead',
  );

  Future<void> _loadInput(
    Future<String?> Function() loader, {
    required String errorKey,
  }) async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearFeedback();
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
    if (_isRunning || output == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.clipboardWriter(_preview(output));
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _notice = _message('textAnalyze.copiedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.textAnalyze.clipboardWrite');
      });
    }
  }

  Future<void> _save() async {
    final output = _output;
    if (_isRunning || output == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _notice = null;
    });
    try {
      final saved = await widget.fileSaver(
        'chimera-text-analysis.txt',
        utf8.encode(_preview(output)),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('textAnalyze.savedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.textAnalyze.outputAccess');
      });
    }
  }

  void _clearFeedback() {
    _output = null;
    _error = null;
    _notice = null;
  }

  String _preview(TextAnalyzeOutput output) =>
      '${_message('textAnalyze.characterCountLabel')}: ${output.characterCount}\n'
      '${_message('textAnalyze.wordCountLabel')}: ${output.wordCount}\n'
      '${_message('textAnalyze.lineCountLabel')}: ${output.lineCount}\n'
      '${_message('textAnalyze.byteCountLabel')}: ${output.byteCount}\n';

  Widget _statistic(String name, String labelKey, int value, double width) =>
      SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_message(labelKey)}: $value',
            key: Key('text-analyze-$name'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('textAnalyze.pageTitle'))),
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
                    key: const Key('text-analyze-input'),
                    controller: _inputController,
                    autofocus: true,
                    enabled: !_isRunning,
                    minLines: 5,
                    maxLines: 10,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) {
                      if (!_isRunning) setState(_clearFeedback);
                    },
                    decoration: InputDecoration(
                      labelText: _message('textAnalyze.inputLabel'),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const Key('text-analyze-file'),
                        onPressed: _isRunning ? null : _loadFile,
                        icon: const Icon(Icons.file_open),
                        label: Text(_message('textAnalyze.fileAction')),
                      ),
                      OutlinedButton.icon(
                        key: const Key('text-analyze-paste'),
                        onPressed: _isRunning ? null : _paste,
                        icon: const Icon(Icons.content_paste),
                        label: Text(_message('textAnalyze.pasteAction')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('text-analyze-submit'),
                    onPressed: _isRunning ? null : _submit,
                    child: Text(_message('textAnalyze.submitAction')),
                  ),
                  if (_error case final error?) ...<Widget>[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        key: const Key('text-analyze-error'),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final preview = _preview(output).trimRight();
                        final itemWidth = constraints.maxWidth >= 520
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                        return Semantics(
                          key: const Key('text-analyze-result-semantics'),
                          container: true,
                          liveRegion: true,
                          excludeSemantics: true,
                          role: SemanticsRole.region,
                          label: _message('textAnalyze.pageTitle'),
                          value: preview,
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              _statistic(
                                'characters',
                                'textAnalyze.characterCountLabel',
                                output.characterCount,
                                itemWidth,
                              ),
                              _statistic(
                                'words',
                                'textAnalyze.wordCountLabel',
                                output.wordCount,
                                itemWidth,
                              ),
                              _statistic(
                                'lines',
                                'textAnalyze.lineCountLabel',
                                output.lineCount,
                                itemWidth,
                              ),
                              _statistic(
                                'bytes',
                                'textAnalyze.byteCountLabel',
                                output.byteCount,
                                itemWidth,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          key: const Key('text-analyze-copy'),
                          onPressed: _isRunning ? null : _copy,
                          icon: const Icon(Icons.copy),
                          label: Text(_message('textAnalyze.copyAction')),
                        ),
                        OutlinedButton.icon(
                          key: const Key('text-analyze-save'),
                          onPressed: _isRunning ? null : _save,
                          icon: const Icon(Icons.save_alt),
                          label: Text(_message('textAnalyze.saveAction')),
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
    );
  }
}
