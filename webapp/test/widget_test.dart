import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iloveprepa/models/document_item.dart';
import 'package:iloveprepa/screens/dashboard_screen.dart';
import 'package:iloveprepa/services/api_service.dart';
import 'package:iloveprepa/services/stats_service.dart';
import 'package:iloveprepa/theme/app_theme.dart';
import 'package:iloveprepa/widgets/folder_content_view.dart';
import 'package:iloveprepa/widgets/library_sidebar.dart';
import 'package:iloveprepa/widgets/notion_folder_icon.dart';
import 'package:iloveprepa/widgets/search_result_tile.dart';

class _FakeApiService extends ApiService {
  static const List<String> files = [
    '1. Math/Algèbre/Cours/S1/Cours Algèbre.pdf',
    '1. Math/Algèbre/TD/S1/TD 1.pdf',
    '1. Math/Analyse/Devoirs/S1/DS 1.pdf',
    '2. Physique - Chimie/Physique/Cours/S1/Mécanique.pdf',
  ];

  @override
  Future<List<DocumentItem>> fetchDocuments() async {
    return [
      for (final name in files) DocumentItem(name: name, sizeBytes: 204800),
    ];
  }
}

Widget _app({bool wide = true}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: DashboardScreen(
      api: _FakeApiService(),
      stats: StatsService.forTest(),
    ),
  );
}

Future<void> _pumpDashboard(WidgetTester tester, {bool wide = true}) async {
  if (wide) await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(wide: wide));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots and shows search bar, recent section and tree',
      (tester) async {
    await _pumpDashboard(tester);

    expect(find.text('Rechercher une matière, un dossier ou un document…'),
        findsOneWidget);
    expect(find.text('Récents'), findsOneWidget);
    expect(find.textContaining('Prepa'), findsWidgets);
    expect(find.text('Algèbre'), findsOneWidget);
    expect(find.text('Analyse'), findsOneWidget);
  });

  testWidgets('Typing shows matching search results in the sidebar',
      (tester) async {
    await _pumpDashboard(tester);

    await tester.enterText(
      find.byType(TextField),
      'Algèbre',
    );
    await tester.pumpAndSettle();

    expect(find.byType(SearchResultTile), findsNothing);
    expect(find.text('Résultats'), findsOneWidget);
    expect(find.text('Algèbre'), findsWidgets);
    expect(find.text('Récents'), findsOneWidget);
  });

  testWidgets('Footer shows the three live metrics when scrolled into view',
      (tester) async {
    await _pumpDashboard(tester);

    expect(find.text('Visites'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Visites'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('mainScroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('Visites'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Téléchargements'), findsOneWidget);
  });

  testWidgets('Opening a folder shows its contents in the main content',
      (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.text('Analyse'));
    await tester.pumpAndSettle();

    expect(find.text('Récents'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FolderContentView),
        matching: find.text('Dossiers'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(FolderContentView),
        matching: find.text('Documents'),
      ),
      findsNothing,
    );
    expect(find.text('DS 1'), findsNothing);
    expect(find.text('Ce dossier contient des sous-dossiers'), findsNothing);
    expect(find.text('Taille'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FolderContentView),
        matching: find.text('Analyse'),
      ),
      findsNothing,
    );
  });

  testWidgets(
      'Navigating to a leaf folder reveals its documents in the main page',
      (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Algèbre'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ce dossier contient des sous-dossiers'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FolderContentView),
        matching: find.text('Cours Algèbre'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Cours'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('S1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(FolderContentView),
        matching: find.text('Documents'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(FolderContentView),
        matching: find.text('Cours Algèbre'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(FolderContentView),
        matching: find.text('TD 1'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(FolderContentView),
        matching: find.byType(NotionFolderIcon),
      ),
      findsNothing,
    );
    expect(find.widgetWithText(FilledButton, 'Télécharger'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Voir'), findsOneWidget);

    expect(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Cours Algèbre'),
      ),
      findsNothing,
    );
  });

  testWidgets('Viewing a document opens an in-page viewer', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Algèbre'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Cours'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('S1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(FolderContentView),
        matching: find.text('Cours Algèbre'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Fermer'), findsOneWidget);
    expect(find.byTooltip('Ouvrir dans un nouvel onglet'), findsNothing);
    expect(find.byTooltip('Télécharger'), findsNothing);
    expect(find.text('Aperçu'), findsNothing);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Fermer'), findsNothing);
  });

  testWidgets('Recents are restored from storage on boot', (tester) async {
    SharedPreferences.setMockInitialValues({
      'recent_files_v1':
          '[{"name":"1. Math/Analyse/Devoirs/S1/DS 1.pdf","openedAt":'
          '${DateTime.now().millisecondsSinceEpoch}}]',
    });
    await _pumpDashboard(tester);

    expect(find.text('DS 1'), findsOneWidget);
    expect(find.text('Récents'), findsOneWidget);
  });

  testWidgets('Recents missing from the server are dropped on restore',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'recent_files_v1':
          '[{"name":"1. Math/Analyse/Devoirs/S1/Gone.pdf","openedAt":'
          '${DateTime.now().millisecondsSinceEpoch}}]',
    });
    await _pumpDashboard(tester);

    expect(find.text('Gone'), findsNothing);
    expect(
      find.text('Les fichiers PDF que vous ouvrez apparaîtront ici.'),
      findsOneWidget,
    );
  });
}
