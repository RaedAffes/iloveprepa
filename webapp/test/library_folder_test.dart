import 'package:flutter_test/flutter_test.dart';

import 'package:iloveprepa/models/document_item.dart';
import 'package:iloveprepa/models/library_folder.dart';

DocumentItem _doc(String name) => DocumentItem(name: name, sizeBytes: 10);

void main() {
  test('builds hierarchy from flat R2 object keys', () {
    final root = buildLibraryTree([
      _doc('Mathematics/Analyse/Chapter-1.pdf'),
      _doc('Mathematics/Analyse/Exercises.pdf'),
      _doc('Mathematics/Algebra/Course.pdf'),
      _doc('Programming/C/Primer.pdf'),
      _doc('Networks/Notes.pdf'),
      _doc('README.txt'),
    ]);

    expect(root.folderCount, 3);
    expect(root.fileCount, 1); // README.txt sits at the root

    final maths = root.child('Mathematics')!;
    expect(maths.child('Analyse')!.fileCount, 2);
    expect(maths.child('Algebra')!.fileCount, 1);

    // Totals roll up through the tree.
    expect(root.totalDocuments, 6);
    expect(root.totalSize, 60);
    expect(_totalFolders(root), 6);
  });

  test('sorts sibling folders alphabetically on navigation', () {
    final root = buildLibraryTree([
      _doc('Zulu/chapter.pdf'),
      _doc('Alpha/chapter.pdf'),
    ]);
    final names = root.children.keys.toList()..sort();
    expect(names, ['Alpha', 'Zulu']);
  });
}

int _totalFolders(LibraryFolder node) {
  var count = 0;
  for (final child in node.children.values) {
    count += 1 + _totalFolders(child);
  }
  return count;
}
