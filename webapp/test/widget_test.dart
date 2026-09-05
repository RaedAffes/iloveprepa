import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iloveprepa/main.dart';
import 'package:iloveprepa/models/document_item.dart';
import 'package:iloveprepa/screens/dashboard_screen.dart';
import 'package:iloveprepa/services/analytics_service.dart';
import 'package:iloveprepa/services/api_service.dart';
import 'package:iloveprepa/services/stats_service.dart';
import 'package:iloveprepa/theme/app_theme.dart';
import 'package:iloveprepa/widgets/app_footer.dart';
import 'package:iloveprepa/widgets/folder_content_view.dart';
import 'package:iloveprepa/widgets/iloveprepa_brand.dart';
import 'package:iloveprepa/widgets/library_sidebar.dart';
import 'package:iloveprepa/widgets/notion_folder_icon.dart';
import 'package:iloveprepa/widgets/search_result_tile.dart';

// Stubs for deleted landing page — keep old tests compiling after removal.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key, this.stats, this.analytics, this.api});
  final dynamic stats;
  final dynamic analytics;
  final dynamic api;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class LandingNavBar extends StatelessWidget {
  const LandingNavBar({
    super.key,
    required this.isWide,
    required this.scrolled,
    required this.onNavigate,
    required this.onHome,
  });
  final bool isWide;
  final bool scrolled;
  final ValueChanged<String> onNavigate;
  final VoidCallback onHome;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

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

class _RootFileApiService extends ApiService {
  static const List<String> files = [
    '2025.findings-acl.476 (4).pdf',
    'S1/Cours Algèbre (Arithmétique dans Z).pdf',
  ];

  @override
  Future<List<DocumentItem>> fetchDocuments() async {
    return [
      for (final name in files) DocumentItem(name: name, sizeBytes: 204800),
    ];
  }
}

class _RootFileTreeService extends ApiService {
  static const List<String> files = [
    '2025.findings-acl.476 (4).pdf',
    '1. Math/Algèbre/Cours/S1/Cours Algèbre.pdf',
  ];

  @override
  Future<List<DocumentItem>> fetchDocuments() async {
    return [
      for (final name in files) DocumentItem(name: name, sizeBytes: 204800),
    ];
  }
}

/// A single leaf folder packed with files, so the footer sits far below the
/// first viewport and is only mounted when the user scrolls down to it (this
/// is the scenario that used to make the footer crash into a grey page).
class _ManyFilesApiService extends ApiService {
  @override
  Future<List<DocumentItem>> fetchDocuments() async {
    return [
      for (var i = 0; i < 30; i++)
        DocumentItem(
          name: '1. Math/Algèbre/Cours/S1/Cours $i.pdf',
          sizeBytes: 204800,
        ),
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

  testWidgets('Launch shows a splash until the landing is ready',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      IloveprepaApp(
        stats: StatsService.forTest(),
        analytics: AnalyticsService.forTest(),
      ),
    );
    await tester.pump();

    // Splash first: the landing page is not built yet. The 44px spinner runs
    // only in the HTML boot preview, so no spinner exists in the Flutter tree
    // during the splash.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('BIBLIOTHÈQUE'), findsNothing);

    // Let the hero image actually finish decoding (real async), then advance
    // the fake clock past the minimum splash time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1500)),
    );
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Once the minimum wait is over (hero image precached), the landing page
    // opens, ready.
    expect(find.text('BIBLIOTHÈQUE'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Donate button opens a pop-up with the e-dinar card number',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LandingPage(
          stats: StatsService.forTest(),
          analytics: AnalyticsService.forTest(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down naturally: the strip's hold keeps the page pinned until the
    // boxes are all visible, then the page resumes to the donate section.
    final donateButton = find.byKey(const ValueKey('landing_donate_button'));
    for (var i = 0; i < 80; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 16));
      final center = tester.getCenter(donateButton, warnIfMissed: false);
      if (center.dy > 100 && center.dy < 700) break;
    }
    await tester.pumpAndSettle();

    await tester.tap(donateButton);
    await tester.pumpAndSettle();

    expect(find.text('25680686'), findsOneWidget);
    expect(find.text('Envoyez votre don à cette carte e-dinar :'), findsOneWidget);

    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('25680686'), findsNothing);
  });

  testWidgets('App boots and shows search bar and the tree', (tester) async {
    await _pumpDashboard(tester);

    expect(find.text('Rechercher une matière, un dossier ou un document…'),
        findsOneWidget);
    expect(find.text('Appuyez sur le bouton'), findsOneWidget);
    expect(find.textContaining('Prepa'), findsWidgets);

    // All folders start collapsed: open the maths branch to reveal its
    // folders.
    await tester.tap(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('1. Math'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Algèbre'), findsOneWidget);
    expect(find.text('Analyse'), findsOneWidget);
  });

  testWidgets('Root-level files appear in the sidebar like in Cloudflare',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DashboardScreen(
          api: _RootFileApiService(),
          stats: StatsService.forTest(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('2025.findings-acl.476 (4).pdf'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('S1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsWidgets,
    );
    // Every folder starts collapsed: the file inside S1 is hidden until the
    // folder is opened.
    expect(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Cours Algèbre (Arithmétique dans Z).pdf'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('S1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Cours Algèbre (Arithmétique dans Z).pdf'),
      ),
      findsOneWidget,
    );
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
    expect(find.text('Appuyez sur le bouton'), findsOneWidget);
  });

  testWidgets(
      'Footer shows the three live metrics when scrolled into view '
      '(short viewport falls back to scrolling)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

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
    expect(
      find.descendant(
        of: find.byType(AppFooter),
        matching: find.text('Documents'),
      ),
      findsOneWidget,
    );
    expect(find.text('Téléchargements'), findsOneWidget);
  });

  testWidgets('On a phone the welcome card is visible right away',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Appuyez sur le bouton'), findsOneWidget);
  });

  testWidgets('On a phone the sidebar opens on first entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The drawer is auto-opened on first entry: the sidebar is fully on
    // screen (left edge at x=0), not hidden off-screen.
    final sidebar = find.byType(LibrarySidebar);
    expect(sidebar, findsOneWidget);
    expect(tester.getTopLeft(sidebar).dx, closeTo(0, 1));

    // Folders still start collapsed: no sub-folder is visible until tapped.
    expect(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Algèbre'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Analyse'),
      ),
      findsNothing,
    );
  });

  testWidgets('Intermediate folders keep the welcome message',
      (tester) async {
    await _pumpDashboard(tester);

    Finder sidebarText(String label) => find.descendant(
          of: find.byType(LibrarySidebar),
          matching: find.text(label),
        );

    await tester.tap(sidebarText('1. Math'));
    await tester.pumpAndSettle();
    await tester.tap(sidebarText('Analyse'));
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
    expect(find.text('Appuyez sur le bouton'), findsOneWidget);
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
        matching: find.text('1. Math'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Algèbre'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Appuyez sur le bouton'), findsOneWidget);
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
    expect(find.text('Appuyez sur le bouton'), findsNothing);
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
        matching: find.text('Cours Algèbre.pdf'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'Expanding a folder with its caret also shows its documents in the main page',
      (tester) async {
    await _pumpDashboard(tester);

    // The caret lives in the same tree row as the folder label.
    Finder caretOf(String label) => find.descendant(
          of: find.ancestor(
            of: find.descendant(
              of: find.byType(LibrarySidebar),
              matching: find.text(label),
            ),
            matching: find.byType(Row),
          ).first,
          matching: find.byIcon(Icons.chevron_right_rounded),
        );

    await tester.tap(caretOf('1. Math'));
    await tester.pumpAndSettle();
    expect(find.text('Algèbre'), findsOneWidget);

    await tester.tap(caretOf('Algèbre'));
    await tester.pumpAndSettle();
    await tester.tap(caretOf('Cours'));
    await tester.pumpAndSettle();
    await tester.tap(caretOf('S1'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(FolderContentView),
        matching: find.text('Cours Algèbre'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('Cours Algèbre.pdf'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'File rows leave the sidebar when navigating to a folder without files',
      (tester) async {
    await _pumpDashboard(tester);

    Finder sidebarText(String label) => find.descendant(
          of: find.byType(LibrarySidebar),
          matching: find.text(label),
        );

    await tester.tap(sidebarText('1. Math'));
    await tester.pumpAndSettle();
    await tester.tap(sidebarText('Algèbre'));
    await tester.pumpAndSettle();
    await tester.tap(sidebarText('Cours'));
    await tester.pumpAndSettle();
    await tester.tap(sidebarText('S1'));
    await tester.pumpAndSettle();
    expect(sidebarText('Cours Algèbre.pdf'), findsOneWidget);

    await tester.tap(sidebarText('Cours'));
    await tester.pumpAndSettle();
    expect(sidebarText('Cours Algèbre.pdf'), findsNothing);
  });

  testWidgets('Files appear only in the folder that contains them',
      (tester) async {
    await _pumpDashboard(tester);

    Finder sidebarText(String label) => find.descendant(
          of: find.byType(LibrarySidebar),
          matching: find.text(label),
        );

    Finder mainDocs(String label) => find.descendant(
          of: find.byType(FolderContentView),
          matching: find.text(label),
        );

    await tester.tap(sidebarText('1. Math'));
    await tester.pumpAndSettle();
    await tester.tap(sidebarText('Algèbre'));
    await tester.pumpAndSettle();
    await tester.tap(sidebarText('Cours'));
    await tester.pumpAndSettle();
    expect(mainDocs('Cours Algèbre'), findsNothing);
    expect(find.text('Appuyez sur le bouton'), findsOneWidget);

    await tester.tap(sidebarText('S1'));
    await tester.pumpAndSettle();
    expect(mainDocs('Cours Algèbre'), findsOneWidget);
    expect(find.text('Appuyez sur le bouton'), findsNothing);

    await tester.tap(sidebarText('Cours'));
    await tester.pumpAndSettle();
    expect(mainDocs('Cours Algèbre'), findsNothing);
    expect(find.text('Appuyez sur le bouton'), findsOneWidget);

    await tester.tap(sidebarText('Algèbre'));
    await tester.pumpAndSettle();
    expect(mainDocs('Cours Algèbre'), findsNothing);

    await tester.tap(sidebarText('2. Physique - Chimie'));
    await tester.pumpAndSettle();
    await tester.tap(sidebarText('Physique'));
    await tester.pumpAndSettle();
    await tester.tap(sidebarText('Cours'));
    await tester.pumpAndSettle();
    await tester.tap(sidebarText('S1'));
    await tester.pumpAndSettle();
    expect(mainDocs('Cours Algèbre'), findsNothing);
    expect(mainDocs('Mécanique'), findsOneWidget);
  });

  testWidgets('Intermediate folders keep the welcome message',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DashboardScreen(
          api: _RootFileTreeService(),
          stats: StatsService.forTest(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder sidebarText(String label) => find.descendant(
          of: find.byType(LibrarySidebar),
          matching: find.text(label),
        );
    Finder mainDocs(String label) => find.descendant(
          of: find.byType(FolderContentView),
          matching: find.textContaining(label),
        );

    // First entry: no folder opened yet, so the welcome message is shown
    // instead of any documents.
    expect(mainDocs('2025.findings'), findsNothing);
    expect(find.text('Appuyez sur le bouton'), findsOneWidget);

    await tester.tap(sidebarText('1. Math'));
    await tester.pumpAndSettle();
    expect(mainDocs('2025.findings'), findsNothing);
    expect(find.text('Appuyez sur le bouton'), findsOneWidget);

    await tester.tap(sidebarText('Algèbre'));
    await tester.pumpAndSettle();
    expect(mainDocs('2025.findings'), findsNothing);

    await tester.tap(sidebarText('Cours'));
    await tester.pumpAndSettle();
    expect(mainDocs('2025.findings'), findsNothing);

    await tester.tap(sidebarText('S1'));
    await tester.pumpAndSettle();
    expect(mainDocs('Cours Algèbre'), findsOneWidget);
    expect(mainDocs('2025.findings'), findsNothing);
    expect(find.text('Appuyez sur le bouton'), findsNothing);
  });

  testWidgets('Viewing a document opens an in-page viewer', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(LibrarySidebar),
        matching: find.text('1. Math'),
      ),
    );
    await tester.pumpAndSettle();
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

  testWidgets('Landing page scrolls to the showcase image and black footer',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: LandingPage(
          stats: StatsService.forTest(),
          analytics: AnalyticsService.forTest(),
          api: _FakeApiService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('BIBLIOTHÈQUE'), findsOneWidget);

    await tester.tap(find.text('À propos'));
    await tester.pumpAndSettle();
    expect(find.text('La bibliothèque des prépas'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(LandingNavBar),
        matching: find.text('Faire un don'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Soutenez la bibliothèque'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parlons-en'), findsOneWidget);

    final imageFinder = find.byKey(const Key('landing_showcase_image'));
    expect(imageFinder, findsOneWidget);

    await tester.runAsync(() => precacheImage(
          const AssetImage('assets/main2.png'),
          tester.element(imageFinder),
        ));
    await tester.pump();

    final size = tester.getSize(imageFinder);
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));

    expect(find.text('Téléchargements'), findsOneWidget);

    final footerContainer = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppFooter),
        matching: find.byType(Container),
      ).first,
    );
    final gradient = footerContainer.decoration as BoxDecoration;
    expect(gradient.gradient, isA<LinearGradient>());
    expect(
      (gradient.gradient! as LinearGradient).colors.first,
      const Color(0xFF000000),
    );
  });

  testWidgets('Very fast scroll cannot pass the strip before all boxes show',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LandingPage(
          stats: StatsService.forTest(),
          analytics: AnalyticsService.forTest(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;

    // Simulate a single enormous scroll jump that skips the strip entirely
    // (as a very fast fling / trackpad swipe can).
    final big = position.maxScrollExtent;
    position.jumpTo(big);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The page must NOT be past the strip: it must have been rewound so the
    // strip sits at the header.
    expect(position.pixels, lessThan(big),
        reason: 'page must be pinned at the strip, not past it');
    final pinned = position.pixels;

    // Some scrolling feeds the boxes while the page stays pinned.
    for (var i = 0; i < 20; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(pinned, 10),
        reason: 'page must stay pinned at the strip while boxes feed');

    // Keep dragging until the hold releases and the page resumes.
    final prev = position.pixels;
    var released = false;
    for (var i = 0; i < 200; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
      await tester.pump(const Duration(milliseconds: 16));
      if (position.pixels > prev + 500) {
        released = true;
        break;
      }
    }
    expect(released, isTrue,
        reason: 'page should resume scrolling once all boxes are shown');
  });

  testWidgets(
      'Scrolling a long folder to the bottom renders the footer without an '
      'endless grey page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DashboardScreen(
          api: _ManyFilesApiService(),
          stats: StatsService.forTest(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('1. Math'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Algèbre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('S1'));
    await tester.pumpAndSettle();

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('mainScroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;

    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(find.byType(AppFooter), findsOneWidget);
    expect(find.text('Visites'), findsOneWidget);
    expect(find.text('Téléchargements'), findsOneWidget);
    // The footer is real content now; the page must not have ballooned into
    // the infinite grey scroll area the crash used to produce.
    expect(position.maxScrollExtent, lessThan(10000));
  });

  testWidgets('Tapping the landing brand scrolls back to the top',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: LandingPage(
          stats: StatsService.forTest(),
          analytics: AnalyticsService.forTest(),
          api: _FakeApiService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    await tester.tap(
      find.descendant(
        of: find.byType(LandingNavBar),
        matching: find.text('Faire un don'),
      ),
    );
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));

    await tester.tap(find.byType(IloveprepaBrand));
    await tester.pumpAndSettle();

    expect(position.pixels, 0);
  });
}
