import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iloveprepa/models/document_item.dart';
import 'package:iloveprepa/screens/dashboard_screen.dart';
import 'package:iloveprepa/services/api_service.dart';
import 'package:iloveprepa/theme/app_theme.dart';
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
    home: DashboardScreen(api: _FakeApiService()),
  );
}

Future<void> _pumpDashboard(WidgetTester tester, {bool wide = true}) async {
  if (wide) await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(wide: wide));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('App boots and shows search bar, recent section and tree',
      (tester) async {
    await _pumpDashboard(tester);

    expect(find.text('Rechercher une matière, un dossier ou un document…'),
        findsOneWidget);
    expect(find.text('Récents'), findsOneWidget);
    expect(find.text('Bibliothèque'), findsWidgets);
    expect(find.text('Algèbre'), findsOneWidget);
    expect(find.text('Analyse'), findsOneWidget);
    expect(find.text('4 documents'), findsOneWidget);
  });

  testWidgets('Typing shows matching search results', (tester) async {
    await _pumpDashboard(tester);

    await tester.enterText(
      find.byType(TextField),
      'Algèbre',
    );
    await tester.pumpAndSettle();

    expect(find.byType(SearchResultTile), findsWidgets);
    expect(find.textContaining('TD 1'), findsWidgets);
  });

  testWidgets('Opening a folder adds it to recents', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.text('Analyse'));
    await tester.pumpAndSettle();

    expect(find.text('Récents'), findsOneWidget);
    expect(find.textContaining('Analyse'), findsWidgets);
  });
}
