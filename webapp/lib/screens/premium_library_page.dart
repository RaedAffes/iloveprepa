import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import '../models/library_folder.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/auth_button.dart';
import '../utils/pdf_blob.dart';
import '../utils/web_download.dart';
import '../widgets/document_viewer.dart';
import '../widgets/folder_content_view.dart';
import '../widgets/overview_view.dart';

/// Premium bucket, shown like the library: only the semesters this account bought.
class PremiumLibraryPage extends StatefulWidget {
  const PremiumLibraryPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<PremiumLibraryPage> createState() => _PremiumLibraryPageState();
}

class _PremiumLibraryPageState extends State<PremiumLibraryPage> {
  final _api = ApiService();
  List<DocumentItem> _docs = const [];
  final Set<String> _expanded = {};
  List<String> _path = const [];
  String? _busy;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthService.authToken();
      if (token == null) {
        throw ApiException('Connectez-vous pour ouvrir l’espace premium.');
      }
      final fresh = await AuthService.currentUser();
      if (!mounted) return;
      AuthSession.instance.setUser(fresh);
      if (fresh == null || !fresh.isPremium) {
        widget.onBack();
        return;
      }
      final docs = await _api.fetchPremiumDocuments(token);
      if (!mounted) return;
      setState(() {
        _docs = docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Impossible de charger l’espace premium.';
      });
    }
  }

  LibraryFolder get _root => buildLibraryTree(_docs);

  Future<void> _open(DocumentItem item) async {
    final token = await AuthService.authToken();
    if (token == null || !mounted) return;
    setState(() => _busy = item.name);
    try {
      final bytes = await _api.premiumFile(token, item.name);
      if (!mounted) return;
      final url = createPdfBlobUrl(bytes);
      final name = item.name.split('/').last;
      try {
        await showDocumentViewer(
          context: context,
          url: url,
          downloadUrl: url,
          fileName: name,
        );
      } finally {
        revokePdfBlobUrl(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Impossible d’ouvrir le document.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _download(DocumentItem item) async {
    final token = await AuthService.authToken();
    if (token == null || !mounted) return;
    setState(() => _busy = item.name);
    try {
      final bytes = await _api.premiumFile(token, item.name);
      final url = createPdfBlobUrl(bytes);
      final ok = await triggerWebDownload(url, fileName: item.name.split('/').last);
      revokePdfBlobUrl(url);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de télécharger le document.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Impossible de télécharger le document.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _toggle(List<String> path) {
    final key = path.join('/');
    setState(() {
      if (!_expanded.remove(key)) _expanded.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final root = _root;
    final folder = _path.isEmpty ? null : root.descend(_path);
    final top = root.children.values.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _path.isEmpty ? widget.onBack : () => setState(() => _path = _path.sublist(0, _path.length - 1)),
            tooltip: 'Retour',
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          ),
        ),
        Text(
          _path.isEmpty ? 'Examens corrigés' : _path.last,
          style: AppTypography.sectionTitle(),
        ),
        if (_path.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_path.join('  /  '), style: AppTypography.metadata()),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Text(_error!, style: AppTypography.body(AppColors.danger))
        else if (_docs.isEmpty)
          Text(
            'Aucun document n’est disponible pour vos semestres.',
            style: AppTypography.body(),
          )
        else if (folder == null)
          OverviewView(
            folders: top,
            onOpenFolder: (path) => setState(() => _path = path),
          )
        else
          FolderContentView(
            folder: folder,
            currentPath: _path,
            expanded: _expanded,
            busy: _busy,
            onView: _open,
            onDownload: _download,
            onToggle: _toggle,
          ),
      ],
    );
  }
}
