import 'package:flutter_test/flutter_test.dart';

import 'package:iloveprepa/models/document_item.dart';
import 'package:iloveprepa/models/library_index.dart';

DocumentItem _doc(String name, {int size = 1024}) =>
    DocumentItem(name: name, sizeBytes: size, contentType: 'application/pdf');

void main() {
  group('LibraryIndex classification', () {
    test('classifies year, subject, type and semester from the path', () {
      final index = LibraryIndex([
        _doc('MP1/1. Math/Algèbre/Cours/S1/Polynômes.pdf'),
        _doc('MP1/1. Math/Algèbre/TD/S2/TD2.pdf'),
        _doc('MP2/3. Chimie/Etude - Mr. Ali/1. Cristallographie/fichier.pdf'),
      ]);

      expect(index.years, ['MP1', 'MP2']);
      expect(index.subjects, ['1. Math', '3. Chimie']);
      expect(index.semesters, ['S1', 'S2']);

      final results = index.search('polynome');
      expect(results, hasLength(1));
      expect(results.first.isFolder, isFalse);
      expect(results.first.pathLabel, 'MP1 → 1. Math → Algèbre → Cours → S1');
    });

    test('search matches folders, accents and resource types', () {
      final index = LibraryIndex([
        _doc('MP1/1. Math/Algèbre/Cours/S1/Pointers.pdf'),
      ]);

      final folders = index.search('algebre', scope: SearchScope.folders);
      expect(folders, isNotEmpty);
      expect(folders.every((r) => r.isFolder), isTrue);
      expect(
        folders.any(
          (r) => r.title == 'Algèbre' && r.pathLabel == 'MP1 → 1. Math',
        ),
        isTrue,
      );

      final byType = index.search('cours');
      expect(byType, isNotEmpty);
      expect(byType.every((r) => r.type == ResourceType.cours), isTrue);
      expect(byType.any((r) => !r.isFolder), isTrue);
    });

    test('filters narrow results', () {
      final index = LibraryIndex([
        _doc('MP1/1. Math/Algèbre/Cours/S1/A.pdf'),
        _doc('MP1/1. Math/Algèbre/TD/S1/B.pdf'),
        _doc('MP2/2. Physique/TD/S2/C.pdf'),
      ]);

      final tdMp1 = index.search('algebre', scope: SearchScope.td, year: 'MP1');
      expect(tdMp1, isNotEmpty);
      expect(tdMp1.every((r) => r.type == ResourceType.td), isTrue);
      expect(tdMp1.every((r) => r.path.first == 'MP1'), isTrue);
      expect(tdMp1.any((r) => r.title == 'B'), isTrue);

      final tdMp2 = index.search('c', scope: SearchScope.td, year: 'MP2');
      expect(tdMp2.map((r) => r.title), contains('C'));
      expect(tdMp2.every((r) => r.type == ResourceType.td), isTrue);
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
  });
}
