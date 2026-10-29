import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/order_service.dart';
import '../widgets/don_view.dart';
import '../widgets/landing/landing_colors.dart' as landing;

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _ink = Color(0xFF16255E);
  static const _muted = Color(0xFF5C6578);

  final _orders = OrderService();
  List<CourseOrder> _items = const [];
  bool _loading = true;
  String? _error;
  String? _claiming;

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
      final items = await _orders.mine();
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

  Future<void> _askPaid(CourseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer le paiement'),
        content: const Text(
          'Vous déclarez avoir payé en scannant le QR D17.\n\n'
          'Un administrateur vérifiera ce paiement avant d’activer l’accès. '
          'Ne confirmez que si le transfert est déjà parti.',
          style: TextStyle(height: 1.4, color: _ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non, pas encore'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: landing.AppColors.orange,
              foregroundColor: _ink,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, j’ai payé'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _claiming = order.id);
    try {
      await _orders.claimPaid(order.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('ApiException: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  void _showQr(CourseOrder order) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 12, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.label,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _ink),
                    ),
                  ],
                ),
                Text(
                  '${order.amountDt} DT',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _ink, height: 1),
                ),
                const SizedBox(height: 8),
                const Text('Scannez ce QR avec D17 pour payer.', style: TextStyle(color: _muted)),
                const SizedBox(height: 16),
                QrImageView(
                  data: 'D17:$kD17Number:${order.amountDt}',
                  size: 280,
                  backgroundColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                        'Mes commandes',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _ink),
                      ),
                      Text(
                        'Scannez le QR pour payer, puis déclarez le paiement',
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
        const minWidth = 860.0;
        final table = Column(
          children: [
            const _Header(),
            const Divider(height: 1, color: Color(0xFFE6E8EF)),
            Expanded(child: _rows()),
          ],
        );
        if (constraints.maxWidth >= minWidth) return table;
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
        child: Text('Aucune commande pour le moment.', style: TextStyle(color: _muted, fontSize: 13)),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F2F6)),
      itemBuilder: (context, index) {
        final order = _items[index];
        return _OrderRow(
          order: order,
          busy: _claiming == order.id,
          onQr: () => _showQr(order),
          onPaid: () => _askPaid(order),
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
            _Cell('Référence', flex: 14, header: true),
            _Cell('Date', flex: 22, header: true),
            _Cell('Commande', flex: 28, header: true),
            _Cell('Montant', flex: 12, header: true),
            _Cell('Statut', flex: 18, header: true),
            SizedBox(width: 196),
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.busy,
    required this.onQr,
    required this.onPaid,
  });

  final CourseOrder order;
  final bool busy;
  final VoidCallback onQr;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    final ref = order.id.length >= 8 ? order.id.substring(0, 8).toUpperCase() : order.id;
    final payable = order.status == 'pending_payment';
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _Cell(ref, flex: 14, strong: true),
          _Cell(_when(order.createdAt), flex: 22),
          _Cell(order.label, flex: 28, strong: true),
          _Cell('${order.amountDt} DT', flex: 12, strong: true),
          Expanded(
            flex: 18,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Flexible(child: _StatusPill(label: order.statusLabel, color: _tone(order.status))),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 196,
            child: payable
                ? Row(
                    children: [
                      OutlinedButton(
                        onPressed: onQr,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(64, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          foregroundColor: _OrdersScreenState._ink,
                          side: const BorderSide(color: Color(0xFFE6E8EF)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('QR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: busy ? null : onPaid,
                        style: FilledButton.styleFrom(
                          backgroundColor: landing.AppColors.orange,
                          foregroundColor: _OrdersScreenState._ink,
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(96, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        child: Text(busy ? '…' : 'J’ai payé'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {required this.flex, this.header = false, this.strong = false});

  final String text;
  final int flex;
  final bool header;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: header ? _OrdersScreenState._muted : _OrdersScreenState._ink,
            fontSize: header ? 11 : 13,
            fontWeight: header || strong ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: header ? 0.3 : 0,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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

Color _tone(String status) => switch (status) {
      'pending_payment' => const Color(0xFF9A6200),
      'payment_claimed' => const Color(0xFF1B3FA0),
      'validated' => const Color(0xFF1B7F4B),
      'rejected' => const Color(0xFFC4432F),
      _ => const Color(0xFF5C6578),
    };

String _when(String iso) {
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) return '';
  const months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year} · $hour:$minute';
}
