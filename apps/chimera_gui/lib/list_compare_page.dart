import 'dart:convert';
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef ListCompareFilePicker = Future<String?> Function();
typedef ListCompareFileSaver = Future<bool> Function(
  String fileName,
  List<int> bytes,
);
typedef ListCompareClipboardReader = Future<String?> Function();
typedef ListCompareClipboardWriter = Future<void> Function(String value);

Future<String?> pickListCompareFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return file == null ? null : utf8.decode(await file.readAsBytes());
}

Future<bool> saveListCompareFile(String fileName, List<int> bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: 'text/plain',
    type: FileType.custom,
    allowedExtensions: const <String>['txt'],
  );
  return uri != null;
}

Future<String?> readListCompareClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

Future<void> writeListCompareClipboard(String value) =>
    Clipboard.setData(ClipboardData(text: value));

final class ListComparePage extends StatefulWidget {
  const ListComparePage({
    required this.catalog,
    required this.localeTag,
    required this.service,
    required this.leftFilePicker,
    required this.rightFilePicker,
    required this.fileSaver,
    required this.leftClipboardReader,
    required this.rightClipboardReader,
    required this.clipboardWriter,
    super.key,
  });

  final MessageCatalog catalog;
  final String localeTag;
  final ListCompareService service;
  final ListCompareFilePicker leftFilePicker;
  final ListCompareFilePicker rightFilePicker;
  final ListCompareFileSaver fileSaver;
  final ListCompareClipboardReader leftClipboardReader;
  final ListCompareClipboardReader rightClipboardReader;
  final ListCompareClipboardWriter clipboardWriter;

  @override
  State<ListComparePage> createState() => _ListComparePageState();
}

final class _ListComparePageState extends State<ListComparePage> {
  late final TextEditingController _leftController;
  late final TextEditingController _rightController;
  ListCompareOutput? _output;
  String? _error;
  String? _notice;
  String _caseMode = 'sensitive';
  String _whitespaceMode = 'preserve';
  String _duplicateMode = 'preserve';
  bool _isRunning = false;

  String _message(String key) => widget.catalog.lookup(widget.localeTag, key);

  @override
  void initState() {
    super.initState();
    _leftController = TextEditingController(text: 'alpha\nbeta');
    _rightController = TextEditingController(text: 'alpha\ngamma');
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearFeedback();
    });
    final result = await widget.service.execute(
      ListCompareOperationRequest(
        left: _leftController.text,
        right: _rightController.text,
        caseMode: _caseMode,
        whitespaceMode: _whitespaceMode,
        duplicateMode: _duplicateMode,
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

  Future<void> _loadLeftFile() => _loadInput(
    controller: _leftController,
    loader: widget.leftFilePicker,
    errorKey: 'error.listCompare.fileAccess',
  );

  Future<void> _loadRightFile() => _loadInput(
    controller: _rightController,
    loader: widget.rightFilePicker,
    errorKey: 'error.listCompare.fileAccess',
  );

  Future<void> _pasteLeft() => _loadInput(
    controller: _leftController,
    loader: widget.leftClipboardReader,
    errorKey: 'error.listCompare.clipboardRead',
  );

  Future<void> _pasteRight() => _loadInput(
    controller: _rightController,
    loader: widget.rightClipboardReader,
    errorKey: 'error.listCompare.clipboardRead',
  );

  Future<void> _loadInput({
    required TextEditingController controller,
    required Future<String?> Function() loader,
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
        if (value != null) controller.text = value;
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
        _notice = _message('listCompare.copiedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.listCompare.clipboardWrite');
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
        'chimera-list-comparison.txt',
        utf8.encode(_preview(output)),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        if (saved) _notice = _message('listCompare.savedResult');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _output = null;
        _error = _message('error.listCompare.outputAccess');
      });
    }
  }

  void _selectCase(String? value) {
    if (value == null) return;
    setState(() {
      _caseMode = value;
      _clearFeedback();
    });
  }

  void _selectWhitespace(String? value) {
    if (value == null) return;
    setState(() {
      _whitespaceMode = value;
      _clearFeedback();
    });
  }

  void _selectDuplicates(String? value) {
    if (value == null) return;
    setState(() {
      _duplicateMode = value;
      _clearFeedback();
    });
  }

  void _clearFeedback() {
    _output = null;
    _error = null;
    _notice = null;
  }

  String _preview(ListCompareOutput output) {
    final buffer = StringBuffer();
    void writeSection(String key, List<String> values) {
      buffer.writeln('${_message(key)}:');
      for (final value in values) {
        buffer.writeln(value);
      }
    }

    writeSection('listCompare.leftOnlyLabel', output.leftOnly);
    writeSection('listCompare.rightOnlyLabel', output.rightOnly);
    writeSection('listCompare.intersectionLabel', output.intersection);
    buffer.writeln(
      '${_message('listCompare.equalLabel')}: '
      '${_message(output.equal ? 'listCompare.yesValue' : 'listCompare.noValue')}',
    );
    return buffer.toString();
  }

  Widget _inputPanel({
    required String side,
    required TextEditingController controller,
    required VoidCallback loadFile,
    required VoidCallback paste,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextField(
        key: Key('list-compare-$side-input'),
        controller: controller,
        autofocus: side == 'left',
        enabled: !_isRunning,
        minLines: 5,
        maxLines: 10,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        onChanged: (_) {
          if (!_isRunning) setState(_clearFeedback);
        },
        decoration: InputDecoration(
          labelText: _message('listCompare.${side}InputLabel'),
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
            key: Key('list-compare-$side-file'),
            onPressed: _isRunning ? null : loadFile,
            icon: const Icon(Icons.file_open),
            label: Text(_message('listCompare.fileAction.$side')),
          ),
          OutlinedButton.icon(
            key: Key('list-compare-$side-paste'),
            onPressed: _isRunning ? null : paste,
            icon: const Icon(Icons.content_paste),
            label: Text(_message('listCompare.pasteAction.$side')),
          ),
        ],
      ),
    ],
  );

  Widget _selector({
    required Key key,
    required String value,
    required String labelKey,
    required Iterable<String> values,
    required ValueChanged<String?> onChanged,
    required String itemPrefix,
  }) => DropdownButtonFormField<String>(
    key: key,
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: _message(labelKey),
      border: const OutlineInputBorder(),
    ),
    items: values
        .map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(_message('$itemPrefix.$item')),
          ),
        )
        .toList(growable: false),
    onChanged: _isRunning ? null : onChanged,
  );

  Widget _resultSection({
    required String name,
    required String labelKey,
    required List<String> values,
  }) {
    final count = '${_message('listCompare.itemCountLabel')}: ${values.length}';
    return Semantics(
      key: Key('list-compare-$name-semantics'),
      container: true,
      liveRegion: true,
      excludeSemantics: true,
      role: SemanticsRole.region,
      label: _message(labelKey),
      value: '$count\n${values.join('\n')}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _message(labelKey),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(count, key: Key('list-compare-$name-count')),
            const SizedBox(height: 8),
            SelectableText(values.join('\n'), key: Key('list-compare-$name')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_message('listCompare.pageTitle'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final left = _inputPanel(
                    side: 'left',
                    controller: _leftController,
                    loadFile: _loadLeftFile,
                    paste: _pasteLeft,
                  );
                  final right = _inputPanel(
                    side: 'right',
                    controller: _rightController,
                    loadFile: _loadRightFile,
                    paste: _pasteRight,
                  );
                  final selectors = <Widget>[
                    _selector(
                      key: const Key('list-compare-case'),
                      value: _caseMode,
                      labelKey: 'listCompare.caseLabel',
                      values: ListComparator.supportedCaseModes,
                      onChanged: _selectCase,
                      itemPrefix: 'listCompare.case',
                    ),
                    _selector(
                      key: const Key('list-compare-whitespace'),
                      value: _whitespaceMode,
                      labelKey: 'listCompare.whitespaceLabel',
                      values: ListComparator.supportedWhitespaceModes,
                      onChanged: _selectWhitespace,
                      itemPrefix: 'listCompare.whitespace',
                    ),
                    _selector(
                      key: const Key('list-compare-duplicates'),
                      value: _duplicateMode,
                      labelKey: 'listCompare.duplicateLabel',
                      values: ListComparator.supportedDuplicateModes,
                      onChanged: _selectDuplicates,
                      itemPrefix: 'listCompare.duplicate',
                    ),
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: left),
                            const SizedBox(width: 16),
                            Expanded(child: right),
                          ],
                        )
                      else ...<Widget>[left, const SizedBox(height: 16), right],
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          children: <Widget>[
                            for (
                              var index = 0;
                              index < selectors.length;
                              index++
                            ) ...<Widget>[
                              if (index > 0) const SizedBox(width: 12),
                              Expanded(child: selectors[index]),
                            ],
                          ],
                        )
                      else
                        ...selectors.expand(
                          (selector) => <Widget>[
                            selector,
                            const SizedBox(height: 8),
                          ],
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        key: const Key('list-compare-submit'),
                        onPressed: _isRunning ? null : _submit,
                        child: Text(_message('listCompare.submitAction')),
                      ),
                      if (_error case final error?) ...<Widget>[
                        const SizedBox(height: 24),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            key: const Key('list-compare-error'),
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
                        _resultSection(
                          name: 'left-only',
                          labelKey: 'listCompare.leftOnlyLabel',
                          values: output.leftOnly,
                        ),
                        const SizedBox(height: 12),
                        _resultSection(
                          name: 'right-only',
                          labelKey: 'listCompare.rightOnlyLabel',
                          values: output.rightOnly,
                        ),
                        const SizedBox(height: 12),
                        _resultSection(
                          name: 'intersection',
                          labelKey: 'listCompare.intersectionLabel',
                          values: output.intersection,
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          label: _message('listCompare.equalLabel'),
                          value: _message(
                            output.equal
                                ? 'listCompare.yesValue'
                                : 'listCompare.noValue',
                          ),
                          child: Text(
                            '${_message('listCompare.equalLabel')}: '
                            '${_message(output.equal ? 'listCompare.yesValue' : 'listCompare.noValue')}',
                            key: const Key('list-compare-equal'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            OutlinedButton.icon(
                              key: const Key('list-compare-copy'),
                              onPressed: _isRunning ? null : _copy,
                              icon: const Icon(Icons.copy),
                              label: Text(_message('listCompare.copyAction')),
                            ),
                            OutlinedButton.icon(
                              key: const Key('list-compare-save'),
                              onPressed: _isRunning ? null : _save,
                              icon: const Icon(Icons.save_alt),
                              label: Text(_message('listCompare.saveAction')),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
