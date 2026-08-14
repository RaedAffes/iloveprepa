import 'package:flutter_test/flutter_test.dart';

import 'package:iloveprepa/models/document_item.dart';
import 'package:iloveprepa/models/library_index.dart';

DocumentItem _doc(String name, {int size = 1024}) =>
    DocumentItem(name: name, sizeBytes: size, contentType: 'application/pdf');

void main() {
  group('LibraryIndex search', () {
    test('returns a file with its full hierarchical path', () {
      final index = LibraryIndex([
        _doc('MP1/1. Math/Algèbre/Cours/S1/Polynômes.pdf'),
        _doc('MP1/1. Math/Algèbre/TD/S2/TD2.pdf'),
        _doc('MP2/3. Chimie/Etude - Mr. Ali/1. Cristallographie/fichier.pdf'),
      ]);

      final results = index.search('polynome');
      expect(results, hasLength(1));
      expect(results.first.isFolder, isFalse);
      expect(results.first.path, ['MP1', '1. Math', 'Algèbre', 'Cours', 'S1']);
      expect(results.first.pathLabel, 'MP1 → 1. Math → Algèbre → Cours → S1');
    });

    test('search matches names only and is accent-flexible', () {
      final index = LibraryIndex([
        _doc('MP1/1. Math/Algèbre/Cours/S1/Pointers.pdf'),
      ]);

      final folders = index.search('algebre');
      expect(folders, isNotEmpty);
      expect(folders.every((r) => r.isFolder), isTrue);
      expect(
        folders.any(
          (r) => r.title == 'Algèbre' && r.pathLabel == 'MP1 → 1. Math',
        ),
        isTrue,
      );

      final byName = index.search('cours');
      expect(byName, hasLength(1));
      expect(byName.single.isFolder, isTrue);
      expect(byName.single.title, 'Cours');

      final files = index.search('pointers');
      expect(files, hasLength(1));
      expect(files.single.isFolder, isFalse);
      expect(files.single.title, 'Pointers');
    });

    test('search is case-insensitive for folders and files', () {
      final index = LibraryIndex([
        _doc('MP1/1. Math/Algèbre/Cours/S1/Pointers.pdf'),
      ]);

      final upper = index.search('ALGEBRE COURS POINTERS');
      final lower = index.search('algebre cours pointers');
      final mixed = index.search('AlGèBrE CoUrS PoInTeRs');

      expect(
        upper.map((r) => r.title),
        unorderedEquals(lower.map((r) => r.title)),
      );
      expect(
        upper.map((r) => r.title),
        unorderedEquals(mixed.map((r) => r.title)),
      );
      expect(
        upper.where((r) => r.isFolder).map((r) => r.title),
        containsAll(['Algèbre', 'Cours']),
      );
      expect(
        upper.where((r) => !r.isFolder).map((r) => r.title),
        contains('Pointers'),
      );
    });

    test('ranks folders ahead of files at equal score', () {
      final index = LibraryIndex([
        _doc('MP1/1. Math/Algèbre/Cours/S1/A.pdf'),
        _doc('MP1/1. Math/Algèbre/TD/S1/B.pdf'),
        _doc('MP2/2. Physique/TD/S2/C.pdf'),
      ]);

      final results = index.search('cours');
      expect(results, isNotEmpty);
      expect(results.first.isFolder, isTrue);
      expect(results.first.title, 'Cours');
    });

    test('exposes size and type metadata for files', () {
      final index = LibraryIndex([
        _doc(
          'MP1/1. Math/Algèbre/Cours/S1/Long Document.pdf',
          size: 3 * 1024 * 1024,
        ),
      ]);

      final results = index.search('long document');
      expect(results.single.document!.sizeLabel, '3.0 MB');
      expect(results.single.type!.label, 'Cours');
    });
  });

  group('searchNorm', () {
    test('strips accents and lowercases', () {
      expect(searchNorm('Étude Séries'), 'etude series');
      expect(searchNorm('ALGÈBRE'), 'algebre');
    });

    test('equates é, è, ê and ë with e', () {
      expect(searchNorm('éèêë'), 'eeee');
      expect(searchNorm('E'), 'e');
    });

    test('handles œ and æ ligatures', () {
      expect(searchNorm('Œuvre Étude'), 'oeuvre etude');
    });
  });
}
