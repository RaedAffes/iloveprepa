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
  List<CourseOrder> _items = const [];
  bool _loading = true;
  String? _error;
  String? _validating;

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
      final items = await _orders.pendingForAdmin();
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
    setState(() => _validating = order.id);
    try {
      await _orders.validate(order.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('ApiException: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _validating = null);
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gérer les commandes',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _ink),
                      ),
                      Text(
                        'Paiements en attente de validation',
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualiser',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded, color: _ink),
                ),
              ],
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
        const minWidth = 980.0;
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
      return const Center(
        child: Text('Aucune commande à valider.', style: TextStyle(color: _muted, fontSize: 13)),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F2F6)),
      itemBuilder: (context, index) {
        final order = _items[index];
        return _OrderRow(
          order: order,
          busy: _validating == order.id,
          onValidate: () => _validate(order),
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
            _Cell('Client', flex: 24, header: true),
            _Cell('Téléphone', flex: 16, header: true),
            _Cell('Commande', flex: 22, header: true),
            _Cell('Montant', flex: 10, header: true),
            _Cell('Statut', flex: 16, header: true),
            SizedBox(width: 112),
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.busy, required this.onValidate});

  final CourseOrder order;
  final bool busy;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    final ref = order.id.length >= 8 ? order.id.substring(0, 8).toUpperCase() : order.id;
    final who = (order.name != null && order.name!.trim().isNotEmpty) ? order.name! : 'Sans nom';
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _Cell(ref, flex: 12, strong: true),
          _Cell(who, flex: 24, sub: order.email, strong: true),
          _Cell(order.payerPhone, flex: 16),
          _Cell(order.label, flex: 22),
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
            width: 112,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: busy ? null : onValidate,
                style: FilledButton.styleFrom(
                  backgroundColor: landing.AppColors.orange,
                  foregroundColor: _AdminOrdersScreenState._ink,
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(88, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                child: Text(busy ? '…' : 'Valider'),
              ),
            ),
          ),
        ],
      ),
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
      'payment_claimed' => const Color(0xFF1B3FA0),
      'validated' => const Color(0xFF1B7A3A),
      'rejected' => const Color(0xFFB42318),
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
