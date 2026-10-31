import 'dart:async';

import 'package:flutter/material.dart';

import '../services/order_service.dart';
import '../widgets/landing/landing_colors.dart' as landing;

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  static const _ink = Color(0xFF16255E);
  static const _muted = Color(0xFF5C6578);

  final _orders = OrderService();
  final _search = TextEditingController();
  Timer? _searchTimer;
  static const _filters = <String, String>{
    'in_progress': 'En cours',
    'validated': 'Validées',
    'cancelled': 'Annulées',
    'all': 'Toutes',
  };

  List<CourseOrder> _items = const [];
  String _filter = 'in_progress';
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _orders.adminOrders(_filter, query: _search.text);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _validate(CourseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Valider cette commande'),
        content: Text(
          'Activer « ${order.label} » pour ${order.name ?? order.email} ?\n\n'
          'Le paiement de ${order.amountDt} DT doit déjà être reçu sur D17.',
          style: const TextStyle(height: 1.4, color: _ink),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: landing.AppColors.orange,
              foregroundColor: _ink,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(order, () => _orders.validate(order.id));
  }

  Future<void> _reject(CourseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler cette commande'),
        content: Text(
          order.status == 'validated'
              ? 'Annuler la commande de ${order.name ?? order.email} ?\n\nL’accès déjà activé sera retiré.'
              : 'Annuler la commande de ${order.name ?? order.email} ?\n\nAucun accès ne sera activé.',
          style: const TextStyle(height: 1.4, color: _ink),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler la commande'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(order, () => _orders.reject(order.id));
  }

  Future<void> _reopen(CourseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remettre en cours'),
        content: Text(
          'Remettre la commande de ${order.name ?? order.email} en cours ?\n\n'
          'L’accès n’est pas activé. Vous pourrez la valider ensuite.',
          style: const TextStyle(height: 1.4, color: _ink),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: landing.AppColors.orange,
              foregroundColor: _ink,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remettre en cours'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(order, () => _orders.reopen(order.id));
  }

  Future<void> _unvalidate(CourseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remettre en cours'),
        content: Text(
          'Retirer « ${order.label} » à ${order.name ?? order.email} ?\n\n'
          'L’accès est retiré. La commande repasse en cours.',
          style: const TextStyle(height: 1.4, color: _ink),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: landing.AppColors.orange,
              foregroundColor: _ink,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remettre en cours'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(order, () => _orders.unvalidate(order.id));
  }

  Future<void> _run(CourseOrder order, Future<void> Function() action) async {
    setState(() => _busyId = order.id);
    try {
      await action();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('ApiException: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: landing.AppColors.lightBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gérer les commandes',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _ink),
                      ),
                      Text(
                        _filters[_filter] ?? '',
                        style: const TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _FilterMenu(
                  value: _filter,
                  labels: _filters,
                  onChanged: (value) {
                    setState(() {
                      _filter = value;
                      _items = const [];
                      _loading = true;
                    });
                    _load();
                  },
                ),
                IconButton(
                  tooltip: 'Actualiser',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded, color: _ink),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) {
                _searchTimer?.cancel();
                _searchTimer = Timer(const Duration(milliseconds: 300), _load);
              },
              style: const TextStyle(color: _ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Nom, e-mail, référence ou téléphone',
                hintStyle: const TextStyle(color: _muted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE6E8EF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE6E8EF)),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6E8EF)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _body(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) return Center(child: Text(_error!));
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 1220.0;
        final wide = constraints.maxWidth >= minWidth;
        final table = Column(
          children: [
            const _Header(),
            const Divider(height: 1, color: Color(0xFFE6E8EF)),
            Expanded(child: _rows()),
          ],
        );
        if (wide) return table;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minWidth, child: table),
          ),
        );
      },
    );
  }

  Widget _rows() {
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _search.text.trim().isNotEmpty
              ? 'Aucune commande ne correspond.'
              : _filter == 'in_progress'
                  ? 'Aucune commande en cours.'
                  : 'Aucune commande dans ce filtre.',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F2F6)),
      itemBuilder: (context, index) {
        final order = _items[index];
        return _OrderRow(
          order: order,
          busy: _busyId == order.id,
          onValidate: () => _validate(order),
          onReject: () => _reject(order),
          onReopen: () => _reopen(order),
          onUnvalidate: () => _unvalidate(order),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF7F8FB),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            _Cell('Référence', flex: 12, header: true),
            _Cell('Date', flex: 12, header: true),
            _Cell('Client', flex: 22, header: true),
            _Cell('Téléphone', flex: 14, header: true),
            _Cell('Commande', flex: 18, header: true),
            _Cell('Montant', flex: 10, header: true),
            _Cell('Statut', flex: 16, header: true),
            SizedBox(width: 280),
          ],
        ),
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.value, required this.labels, required this.onChanged});

  final String value;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E8EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            borderRadius: BorderRadius.circular(10),
            style: const TextStyle(
              color: _AdminOrdersScreenState._ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            items: [
              for (final entry in labels.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (next) {
              if (next != null && next != value) onChanged(next);
            },
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.busy,
    required this.onValidate,
    required this.onReject,
    required this.onReopen,
    required this.onUnvalidate,
  });

  final CourseOrder order;
  final bool busy;
  final VoidCallback onValidate;
  final VoidCallback onReject;
  final VoidCallback onReopen;
  final VoidCallback onUnvalidate;

  @override
  Widget build(BuildContext context) {
    final ref = order.id.length >= 8 ? order.id.substring(0, 8).toUpperCase() : order.id;
    final who = (order.name != null && order.name!.trim().isNotEmpty) ? order.name! : 'Sans nom';
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _Cell(ref, flex: 12, strong: true),
          _Cell(_orderDay(order.createdAt), flex: 12, sub: _orderTime(order.createdAt)),
          _Cell(who, flex: 22, sub: order.email, strong: true),
          _Cell(order.payerPhone, flex: 14),
          _Cell(order.label, flex: 18),
          _Cell('${order.amountDt} DT', flex: 10, strong: true),
          Expanded(
            flex: 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Status(order.status, order.statusLabel),
              ),
            ),
          ),
          SizedBox(
            width: 280,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _actions(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    if (order.status == 'validated') {
      return Row(
        children: [
          TextButton(
            onPressed: busy ? null : onUnvalidate,
            style: TextButton.styleFrom(
              foregroundColor: _AdminOrdersScreenState._ink,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: Text(busy ? '…' : 'Remettre en cours'),
          ),
          TextButton(
            onPressed: busy ? null : onReject,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB42318),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: const Text('Annuler'),
          ),
        ],
      );
    }
    if (order.status == 'cancelled') {
      return Row(
        children: [
          FilledButton(
            onPressed: busy ? null : onValidate,
            style: FilledButton.styleFrom(
              backgroundColor: landing.AppColors.orange,
              foregroundColor: _AdminOrdersScreenState._ink,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(72, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: Text(busy ? '…' : 'Valider'),
          ),
          TextButton(
            onPressed: busy ? null : onReopen,
            style: TextButton.styleFrom(
              foregroundColor: _AdminOrdersScreenState._ink,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: const Text('Remettre en cours'),
          ),
        ],
      );
    }
    if (order.status != 'in_progress') return const SizedBox.shrink();
    return Row(
      children: [
        FilledButton(
          onPressed: busy ? null : onValidate,
          style: FilledButton.styleFrom(
            backgroundColor: landing.AppColors.orange,
            foregroundColor: _AdminOrdersScreenState._ink,
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(72, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          child: Text(busy ? '…' : 'Valider'),
        ),
        const SizedBox(width: 4),
        TextButton(
            onPressed: busy ? null : onReject,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB42318),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: const Text('Annuler'),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {required this.flex, this.sub, this.header = false, this.strong = false});

  final String text;
  final String? sub;
  final int flex;
  final bool header;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: header ? _AdminOrdersScreenState._muted : _AdminOrdersScreenState._ink,
      fontSize: header ? 11 : 13,
      fontWeight: header || strong ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: header ? 0.3 : 0,
    );
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: sub == null
            ? Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _AdminOrdersScreenState._muted, fontSize: 11),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.status, this.label);

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'in_progress' => landing.AppColors.orange,
      'validated' => const Color(0xFF1B7A3A),
      'cancelled' => const Color(0xFFB42318),
      _ => const Color(0xFF8A5A00),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _orderDay(String iso) {
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) return '';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _orderTime(String iso) {
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) return '';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
