import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/auth_user.dart';
import '../widgets/auth_button.dart';

/// Admin-only screen: search for a user and grant/revoke premium access per
/// semester product. Shown in the main content area in place of the library.
class AdminAccessScreen extends StatefulWidget {
  const AdminAccessScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AdminAccessScreen> createState() => _AdminAccessScreenState();
}

class _AdminAccessScreenState extends State<AdminAccessScreen> {
  final _admin = AdminService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<AdminUser> _users = const [];
  bool _loading = true;
  String? _error;

  /// userId currently being updated, to disable its chips while in flight.
  String? _updating;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _admin.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e'.replaceFirst('ApiException: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _toggle(AdminUser user, PremiumProduct product, bool grant) async {
    setState(() => _updating = user.id);
    try {
      final entitlements = await _admin.setEntitlement(
        userId: user.id,
        productCode: product.code,
        grant: grant,
      );
      if (AuthSession.instance.user?.id == user.id) {
        AuthSession.instance.setUser(await AuthService.currentUser());
      }
      if (!mounted) return;
      setState(() {
        _users = _users
            .map((u) => u.id == user.id
                ? AdminUser(
                    id: u.id,
                    email: u.email,
                    name: u.name,
                    phone: u.phone,
                    role: u.role,
                    entitlements: entitlements,
                  )
                : u)
            .toList();
        _updating = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('ApiException: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Gérer les accès',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: _loading ? null : () => _search(_searchController.text),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, e-mail ou téléphone…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_users.isEmpty) {
      return const Center(child: Text('Aucun utilisateur trouvé.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _UserCard(
        user: _users[index],
        busy: _updating == _users[index].id,
        onToggle: _toggle,
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.busy, required this.onToggle});

  final AdminUser user;
  final bool busy;
  final void Function(AdminUser user, PremiumProduct product, bool grant) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      user.phone == null || user.phone!.isEmpty
                          ? user.email
                          : '${user.email}  ·  ${user.phone}',
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (user.role == 'admin')
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.sm),
                  child: Chip(
                    label: Text('Admin', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final product in PremiumProduct.values)
                _ProductChip(
                  product: product,
                  active: user.entitlements.contains(product.code),
                  busy: busy,
                  onChanged: (grant) => onToggle(user, product, grant),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.product,
    required this.active,
    required this.busy,
    required this.onChanged,
  });

  final PremiumProduct product;
  final bool active;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(product.label, style: const TextStyle(fontSize: 12)),
      selected: active,
      onSelected: busy ? null : onChanged,
      selectedColor: AppColors.ink.withValues(alpha: 0.9),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: active ? Colors.white : AppColors.ink),
      backgroundColor: Colors.white,
      side: BorderSide(color: active ? AppColors.ink : AppColors.border),
    );
  }
}
