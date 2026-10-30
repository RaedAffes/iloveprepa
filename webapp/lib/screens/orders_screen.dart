import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/order_service.dart';
import '../widgets/don_view.dart';
import '../widgets/landing/landing_colors.dart' as landing;

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.onBack,
    this.paymentOrder,
    this.onPaymentShown,
  });

  final VoidCallback onBack;
  final CourseOrder? paymentOrder;
  final VoidCallback? onPaymentShown;

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
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
    final order = widget.paymentOrder;
    if (order != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onPaymentShown?.call();
        _showQr(order);
      });
    }
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

  void _showQr(CourseOrder order) {
    final paying = order.status != 'validated';
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
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
                const SizedBox(height: 16),
                const Text(
                  'Payer depuis le compte D17 lié à ce numéro',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _prettyPhone(order.payerPhone),
                  style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                QrImageView(
                  data: 'D17:$kD17Number:${order.amountDt}',
                  size: 240,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 4),
                const Text('QR commerçant D17', style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    paying
                        ? 'Merci de faire le paiement vers ce QR code. Le service client activera votre accès une fois le paiement reçu, dans un délai maximum de 12 h.'
                        : 'Votre accès est activé.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _ink, height: 1.45),
                  ),
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
                        'Le service client active l’accès après le paiement (maximum 12 h)',
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
        const minWidth = 940.0;
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

  Future<void> _cancel(CourseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler cette commande'),
        content: Text(
          'Annuler « ${order.label} » ?\n\nAucun accès ne sera activé.',
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
    setState(() => _busyId = order.id);
    try {
      await _orders.cancel(order.id);
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
          busy: _busyId == order.id,
          onQr: () => _showQr(order),
          onCancel: order.status == 'in_progress' ? () => _cancel(order) : null,
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
            SizedBox(width: 176),
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
    required this.onCancel,
  });

  final CourseOrder order;
  final bool busy;
  final VoidCallback onQr;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final ref = order.id.length >= 8 ? order.id.substring(0, 8).toUpperCase() : order.id;
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
            width: 176,
            child: order.status != 'in_progress'
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      FilledButton(
                        onPressed: busy ? null : onQr,
                        style: FilledButton.styleFrom(
                          backgroundColor: landing.AppColors.orange,
                          foregroundColor: _OrdersScreenState._ink,
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(64, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('QR'),
                      ),
                      if (onCancel != null) ...[
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: busy ? null : onCancel,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFB42318),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          child: Text(busy ? '…' : 'Annuler'),
                        ),
                      ],
                    ],
                  ),
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
      'in_progress' => landing.AppColors.orange,
      'validated' => const Color(0xFF1B7A3A),
      'cancelled' => const Color(0xFFB42318),
      _ => const Color(0xFF5C6578),
    };

String _prettyPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('216')) {
    final local = digits.substring(3);
    return '+216 ${local.substring(0, 2)} ${local.substring(2, 5)} ${local.substring(5)}';
  }
  return phone;
}

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
