import 'document_item.dart';

/// A folder node in the library tree.
///
/// The R2 worker returns a flat list of object keys (e.g.
/// `Mathematics/Analyse/Chapter-1.pdf`). We rebuild the hierarchy locally
/// from those keys so the existing data flow (`ApiService.fetchDocuments`)
/// remains untouched — only the presentation changes.
class LibraryFolder {
  LibraryFolder({required this.name});
 
  final String name;
  final Map<String, LibraryFolder> children = {};
  final List<DocumentItem> files = [];

  bool get isEmpty => children.isEmpty && files.isEmpty;
  int get folderCount => children.length;
  int get fileCount => files.length;

  /// Total documents nested anywhere under this folder.
  int get totalDocuments {
    var total = files.length;
    for (final child in children.values) {
      total += child.totalDocuments;
    }
    return total;
  }

  /// Total storage bytes nested anywhere under this folder.
  int get totalSize {
    var total = 0;
    for (final file in files) {
      total += file.sizeBytes;
    }
    for (final child in children.values) {
      total += child.totalSize;
    }
    return total;
  }

  LibraryFolder? child(String name) => children[name];

  /// Walks the tree down to the folder at [path] (relative to this node),
  /// or returns null if any segment is missing.
  LibraryFolder? descend(List<String> path) {
    var node = this;
    for (final segment in path) {
      final next = node.children[segment];
      if (next == null) return null;
      node = next;
    }
    return node;
  }
}

/// Builds the full library tree from the flat list returned by the R2 worker.
LibraryFolder buildLibraryTree(List<DocumentItem> documents) {
  final root = LibraryFolder(name: 'Library');

  for (final doc in documents) {
    final parts = doc.name
        .split('/')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) continue;

    var node = root;
    for (var i = 0; i < parts.length - 1; i++) {
      final segment = parts[i].trim();
      node = node.children.putIfAbsent(
        segment,
        () => LibraryFolder(name: segment),
      );
    }
    node.files.add(doc);
  }

  return root;
}
