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

/// Scope used by the search chips.
enum SearchScope {
  all('Tout'),
  folders('Dossiers'),
  files('Fichiers'),
  cours('Cours'),
  td('TD'),
  tp('TP'),
  examens('Examens');

  const SearchScope(this.label);
  final String label;

  ResourceType? get type => switch (this) {
    SearchScope.cours => ResourceType.cours,
    SearchScope.td => ResourceType.td,
    SearchScope.tp => ResourceType.tp,
    SearchScope.examens => ResourceType.examens,
    _ => null,
  };
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

/// Normalises text for search: lowercase + strip accents.
String searchNorm(String input) {
  const accents = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
  const plain = 'aaaaaaceeeeiiiinooooouuuuyy';
  final buffer = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    final i = accents.indexOf(ch);
    buffer.write(i >= 0 ? plain[i] : ch);
  }
  return buffer.toString();
}

/// Builds a searchable, navigable index over the flat R2 document list.
///
/// The hierarchy is University → Year → Subject → Topic → Resource type →
/// Semester → files. Because real keys vary in depth, each node is classified
/// heuristically (year = top level, subject = second level, resource type and
/// semester are detected from folder names). The tree itself always remains
/// the single source of truth for navigation.
class LibraryIndex {
  LibraryIndex(this.documents) : root = buildLibraryTree(documents);

  final List<DocumentItem> documents;
  final LibraryFolder root;

  final Map<String, _FileMeta> _fileMeta = {};
  final Map<String, _FileMeta> _folderMeta = {};

  // ── Classification helpers ──────────────────────────────────────────────

  _FileMeta _metaForPath(List<String> segments) {
    final year = segments.isNotEmpty ? segments.first : null;
    final subject = segments.length > 1 ? segments[1] : null;
    ResourceType? type;
    String? typeFolder;
    String? semester;

    for (var i = 1; i < segments.length; i++) {
      final seg = segments[i];
      final t = resourceTypeForName(seg);
      if (t != null) {
        if (type == null) {
          type = t;
          typeFolder = seg;
        }
      }
      if (isSemester(seg) && semester == null) semester = seg;
    }

    return _FileMeta(
      year: year,
      subject: subject,
      semester: semester,
      type: type,
      typeFolder: typeFolder,
    );
  }

  _FileMeta _metaForFile(DocumentItem doc) {
    final segments = doc.name
        .split('/')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return _fileMeta[doc.name] ??= _metaForPath(segments);
  }

  _FileMeta _metaForFolder(List<String> segments) {
    final key = segments.join('/');
    return _folderMeta[key] ??= _metaForPath(segments);
  }

  // ── Filter options (populated from real data) ───────────────────────────

  List<String> get years => _distinct(_collect((m) => m.year));
  List<String> get subjects => _distinct(_collect((m) => m.subject));
  List<String> get semesters => _distinct(_collect((m) => m.semester));
  List<String> get types => _distinct(_collect((m) => m.type?.label));

  List<String?> _collect(String? Function(_FileMeta) pick) {
    final out = <String?>[];
    for (final doc in documents) {
      out.add(pick(_metaForFile(doc)));
    }
    return out;
  }

  List<String> _distinct(List<String?> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final v in values) {
      if (v != null && seen.add(v)) out.add(v);
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  // ── Search ──────────────────────────────────────────────────────────────

  List<SearchResult> search(
    String query, {
    SearchScope scope = SearchScope.all,
    String? year,
    String? semester,
    String? subject,
    String? type,
  }) {
    final q = searchNorm(query.trim());
    if (q.isEmpty) return const [];

    final wantFolders =
        scope == SearchScope.all ||
        scope == SearchScope.folders ||
        scope.type != null;
    final wantFiles =
        scope == SearchScope.all ||
        scope == SearchScope.files ||
        scope.type != null;

    final results = <SearchResult>[];

    if (wantFolders) {
      _walkFolder(root, const [], (folder, segments) {
        final meta = _metaForFolder(segments);
        if (!_matchesFilters(meta, scope, year, semester, subject, type)) {
          return;
        }
        final haystack = _folderHaystack(folder, segments, meta);
        if (haystack.contains(q)) {
          results.add(
            SearchResult(
              title: folder.name,
              path: List.of(segments)..removeLast(),
              isFolder: true,
              type: meta.type,
            ),
          );
        }
      });
    }

    if (wantFiles) {
      for (final doc in documents) {
        final meta = _metaForFile(doc);
        if (!_matchesFilters(meta, scope, year, semester, subject, type)) {
          continue;
        }
        final haystack = _fileHaystack(doc, meta);
        if (haystack.contains(q)) {
          results.add(
            SearchResult(
              title: doc.displayName,
              path:
                  doc.name.split('/').where((s) => s.trim().isNotEmpty).toList()
                    ..removeLast(),
              document: doc,
              isFolder: false,
              type: meta.type,
            ),
          );
        }
      }
    }

    results.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return results;
  }

  bool _matchesFilters(
    _FileMeta meta,
    SearchScope scope,
    String? year,
    String? semester,
    String? subject,
    String? type,
  ) {
    if (scope.type != null && meta.type != scope.type) return false;
    if (year != null && meta.year != year) return false;
    if (semester != null && meta.semester != semester) return false;
    if (subject != null && meta.subject != subject) return false;
    if (type != null && meta.type?.label != type) return false;
    return true;
  }

  String _fileHaystack(DocumentItem doc, _FileMeta meta) {
    final name = searchNorm(doc.name);
    final display = searchNorm(doc.displayName);
    final type = searchNorm(meta.type?.label ?? '');
    return '$display $name $type ${meta.year ?? ''} '
        '${meta.subject ?? ''} ${meta.semester ?? ''}';
  }

  String _folderHaystack(
    LibraryFolder folder,
    List<String> segments,
    _FileMeta meta,
  ) {
    final name = searchNorm(folder.name);
    final path = searchNorm(segments.join('/'));
    final type = searchNorm(meta.type?.label ?? '');
    return '$name $path $type ${meta.year ?? ''} '
        '${meta.subject ?? ''} ${meta.semester ?? ''}';
  }
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

class _FileMeta {
  _FileMeta({
    this.year,
    this.subject,
    this.semester,
    this.type,
    this.typeFolder,
  });

  final String? year;
  final String? subject;
  final String? semester;
  final ResourceType? type;
  final String? typeFolder;
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

bool isSemester(String name) {
  final n = searchNorm(name);
  if (RegExp(r'^s[1-6]$').hasMatch(n)) return true;
  return n.contains('semestre') ||
      n.contains('semester') ||
      n.contains('trimestre');
}
