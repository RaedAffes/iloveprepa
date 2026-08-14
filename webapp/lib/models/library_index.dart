import 'document_item.dart';
import 'library_folder.dart';

/// A recognised resource type (folder such as "Cours", "TD", "Examens"…).
enum ResourceType {
  cours('Cours'),
  td('TD'),
  tp('TP'),
  examens('Examens'),
  series('Séries'),
  etude('Étude'),
  livres('Livres'),
  autre('Autre');

  const ResourceType(this.label);
  final String label;
}

/// One entry in the search results — a folder or a file, with the complete
/// hierarchical path it lives under.
class SearchResult {
  const SearchResult({
    required this.title,
    required this.path,
    required this.isFolder,
    this.document,
    this.type,
  });

  final String title;

  /// Full folder path (ancestors only, never includes [title]).
  final List<String> path;

  final bool isFolder;
  final DocumentItem? document;
  final ResourceType? type;

  String get pathLabel => path.join(' → ');
}

/// Normalises text for search: lowercase + strip accents so "é/è/ê/ë" all
/// behave like "e", "à/â/ä" like "a", etc.
String searchNorm(String input) {
  const accents = 'àáâãäåāăèéêëēėęìíîïīıòóôõöōøùúûüūçćčñńśšžżźýÿ';
  const plain = 'aaaaaaaaeeeeeeeiiiiiiioooooooouuuuucccnnsszzzyy';
  var text = input.toLowerCase().replaceAll('œ', 'oe').replaceAll('æ', 'ae');
  final buffer = StringBuffer();
  for (final ch in text.split('')) {
    final i = accents.indexOf(ch);
    buffer.write(i >= 0 ? plain[i] : ch);
  }
  return buffer.toString();
}

/// Builds a searchable, navigable index over the flat R2 document list.
///
/// The hierarchy (University → Year → Subject → Topic → Resource type →
/// Semester → files) is rebuilt locally from the flat object keys, and the
/// tree is the single source of truth for navigation.
class LibraryIndex {
  LibraryIndex(this.documents) : root = buildLibraryTree(documents);

  final List<DocumentItem> documents;
  final LibraryFolder root;

  /// Every folder and file whose name contains every typed word, ranked by
  /// number of matches. Folders sort ahead of files at equal score.
  List<SearchResult> search(String query) {
    final q = searchNorm(query.trim());
    if (q.isEmpty) return const [];

    // Any typed word can match a folder or a file name — like a real app.
    final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    int matchScore(String haystack) {
      var score = 0;
      for (final term in terms) {
        if (haystack.contains(term)) score++;
      }
      return score;
    }

    final results = <_Scored<SearchResult>>[];

    _walkFolder(root, const [], (folder, segments) {
      final score = matchScore(searchNorm(folder.name));
      if (score > 0) {
        results.add(
          _Scored(
            score,
            SearchResult(
              title: folder.name,
              path: List.of(segments)..removeLast(),
              isFolder: true,
              type: resourceTypeForName(folder.name),
            ),
          ),
        );
      }
    });

    for (final doc in documents) {
      final segments = doc.name
          .split('/')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      final score = matchScore(_fileHaystack(doc));
      if (score > 0) {
        results.add(
          _Scored(
            score,
            SearchResult(
              title: doc.displayName,
              path: List.of(segments)..removeLast(),
              document: doc,
              isFolder: false,
              type: _typeForSegments(segments),
            ),
          ),
        );
      }
    }

    results.sort((a, b) {
      if (a.score != b.score) return b.score.compareTo(a.score);
      if (a.value.isFolder != b.value.isFolder) {
        return a.value.isFolder ? -1 : 1;
      }
      return a.value.title.toLowerCase().compareTo(b.value.title.toLowerCase());
    });

    return [for (final r in results) r.value];
  }

  String _fileHaystack(DocumentItem doc) {
    final name = searchNorm(doc.fileName);
    final display = searchNorm(doc.displayName);
    return '$display $name';
  }
}

/// Type of a file result, taken from the first ancestor folder whose name
/// matches a known resource type ("Cours", "TD", "Examen"…).
ResourceType? _typeForSegments(List<String> segments) {
  for (var i = 1; i < segments.length; i++) {
    final type = resourceTypeForName(segments[i]);
    if (type != null) return type;
  }
  return null;
}

void _walkFolder(
  LibraryFolder node,
  List<String> ancestors,
  void Function(LibraryFolder folder, List<String> segments) visit,
) {
  for (final child in node.children.values) {
    final segments = [...ancestors, child.name];
    visit(child, segments);
    _walkFolder(child, segments, visit);
  }
}

class _Scored<T> {
  const _Scored(this.score, this.value);

  final int score;
  final T value;
}

// ── Resource type detection ───────────────────────────────────────────────

ResourceType? resourceTypeForName(String folderName) {
  final tokens = searchNorm(
    folderName,
  ).split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toSet();

  const cours = {
    'cours',
    'cm',
    'lecon',
    'lecons',
    'lesson',
    'lessons',
    'poly',
    'polys',
    'polycopie',
  };
  const td = {'td', 'tds', 'exercice', 'exercices'};
  const tp = {'tp', 'tps', 'laboratoire', 'pratique'};
  const examens = {
    'examen',
    'examens',
    'devoir',
    'devoirs',
    'controle',
    'controles',
    'epreuve',
    'epreuves',
    'ds',
    'test',
    'tests',
    'interro',
    'interrogation',
    'interrogations',
  };
  const series = {'serie', 'series'};
  const livres = {'livre', 'livres', 'manuel', 'manuels', 'book', 'books'};
  const etude = {'etude', 'etudes', 'revision', 'revisions', 'rappel'};

  if (tokens.any(examens.contains)) return ResourceType.examens;
  if (tokens.any(cours.contains)) return ResourceType.cours;
  if (tokens.any(td.contains)) return ResourceType.td;
  if (tokens.any(tp.contains)) return ResourceType.tp;
  if (tokens.any(series.contains)) return ResourceType.series;
  if (tokens.any(livres.contains)) return ResourceType.livres;
  if (tokens.any(etude.contains)) return ResourceType.etude;
  return null;
}
