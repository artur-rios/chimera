/// The chooser receives metadata only and must not create/write the destination.
typedef LocalSaveLocationChooser = Future<String?> Function(
  String name,
  List<String> extensions,
);
typedef LocalFileTransactionWriter = Future<void> Function(
  String path,
  List<int> bytes,
);
