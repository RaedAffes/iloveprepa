import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/auth_service.dart';
import '../widgets/auth_button.dart';
import '../services/order_service.dart';
import '../widgets/don_view.dart';
import '../widgets/landing/landing_colors.dart' as landing;

class _Semester {
  const _Semester(this.code, this.label);
  final String code;
  final String label;
}

const _semesters = [
  _Semester('y1_s1', 'MP — Semestre 1'),
  _Semester('y1_s2', 'MP — Semestre 2'),
  _Semester('y2_s1', 'Année 2 — Semestre 1'),
  _Semester('y2_s2', 'Année 2 — Semestre 2'),
];

class _Checkout {
  const _Checkout({
    required this.planCode,
    required this.label,
    required this.amount,
    this.productCode,
  });

  final String planCode;
  final String label;
  final int amount;
  final String? productCode;
}

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key, required this.onBack, required this.onPlaced});

  final VoidCallback onBack;
  final VoidCallback onPlaced;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  static const _ink = Color(0xFF16255E);
  static const _muted = Color(0xFF5C6578);

  final _orders = OrderService();
  final _phone = TextEditingController();
  String _semester = _semesters.first.code;
  String _year = 'year1';
  _Checkout? _checkout;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _start(_Checkout checkout) async {
    var user = AuthSession.instance.user ?? await AuthService.currentUser();
    if (!mounted) return;
    if (user == null) {
      user = await showSignInDialog(context);
      if (!mounted || user == null) return;
      AuthSession.instance.setUser(user);
    }
    setState(() => _checkout = checkout);
  }

  Future<void> _place(bool payNow) async {
    final checkout = _checkout;
    if (checkout == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _orders.create(
        planCode: checkout.planCode,
        productCode: checkout.productCode,
        payerPhone: _phone.text,
        payNow: payNow,
      );
      if (!mounted) return;
      widget.onPlaced();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('ApiException: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkout = _checkout;
    return ColoredBox(
      color: landing.AppColors.lightBg,
      child: checkout == null ? _catalog() : _pay(checkout),
    );
  }

  Widget _catalog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Retour',
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  children: [
                    const Text(
                      'Choisissez votre accès',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Paiement par D17. L’accès est activé après vérification.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 16),
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth > 760;
                        final cards = [
                          _semesterCard(),
                          _yearCard(),
                          _shell(
                            name: 'Accès complet',
                            blurb: 'Les quatre semestres.',
                            amount: 50,
                            highlighted: true,
                            badge: 'Accès complet',
                            features: const ['Année 1 et année 2', 'Tous les semestres'],
                            onChoose: () => _start(const _Checkout(
                              planCode: 'full',
                              label: 'Accès complet',
                              amount: 50,
                            )),
                          ),
                        ];
                        if (!wide) {
                          return Column(
                            children: [
                              for (final card in cards)
                                Padding(padding: const EdgeInsets.only(bottom: 16), child: card),
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < cards.length; i++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8, right: i == 2 ? 0 : 8),
                                    child: cards[i],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _semesterCard() {
    final selected = _semesters.firstWhere((item) => item.code == _semester);
    return _shell(
      name: 'Semestre',
      blurb: 'Un seul semestre.',
      amount: 19,
      highlighted: false,
      features: const ['Cours, exercices et examens de ce semestre'],
      extra: DropdownButtonFormField<String>(
        initialValue: _semester,
        decoration: const InputDecoration(labelText: 'Semestre', isDense: true),
        items: [
          for (final item in _semesters)
            DropdownMenuItem(value: item.code, child: Text(item.label)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _semester = value);
        },
      ),
      onChoose: () => _start(_Checkout(
        planCode: 'semester',
        label: selected.label,
        amount: 19,
        productCode: selected.code,
      )),
    );
  }

  Widget _yearCard() {
    final isFirst = _year == 'year1';
    final label = isFirst ? 'Année 1' : 'Année 2';
    return _shell(
      name: 'Année',
      blurb: 'Les deux semestres d’une année.',
      amount: 29,
      highlighted: false,
      features: [
        isFirst ? 'Semestre 1 et semestre 2 de MP' : 'Semestre 1 et semestre 2 de l’année 2',
      ],
      extra: DropdownButtonFormField<String>(
        initialValue: _year,
        decoration: const InputDecoration(labelText: 'Année', isDense: true),
        items: const [
          DropdownMenuItem(value: 'year1', child: Text('Année 1 — MP')),
          DropdownMenuItem(value: 'year2', child: Text('Année 2')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _year = value);
        },
      ),
      onChoose: () => _start(_Checkout(planCode: _year, label: label, amount: 29)),
    );
  }

  Widget _shell({
    required String name,
    required String blurb,
    required int amount,
    required bool highlighted,
    required List<String> features,
    required VoidCallback onChoose,
    String? badge,
    Widget? extra,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? landing.AppColors.orange : const Color(0xFFE6E8EF),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlighted)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(999)),
              child: Text(
                badge ?? 'Le plus choisi',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A5A00)),
              ),
            ),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 4),
          Text(blurb, style: const TextStyle(color: _muted, height: 1.35)),
          const SizedBox(height: 16),
          Text('$amount DT', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _ink, height: 1)),
          if (extra != null) ...[const SizedBox(height: 16), extra],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: highlighted
                ? FilledButton(
                    onPressed: onChoose,
                    style: FilledButton.styleFrom(
                      backgroundColor: landing.AppColors.orange,
                      foregroundColor: _ink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Choisir $name'),
                  )
                : OutlinedButton(onPressed: onChoose, child: Text('Choisir $name')),
          ),
          const SizedBox(height: 16),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded, size: 18, color: _ink),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature, style: const TextStyle(color: _ink))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pay(_Checkout checkout) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _busy ? null : () => setState(() => _checkout = null),
            icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6E8EF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(checkout.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _ink)),
                      const SizedBox(height: 4),
                      Text('${checkout.amount} DT', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _ink)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Votre numéro D17',
                          hintText: '20 123 456',
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Scannez pour payer sur D17', style: TextStyle(color: _muted)),
                      const SizedBox(height: 12),
                      Center(
                        child: QrImageView(
                          data: 'D17:$kD17Number:${checkout.amount}',
                          size: 240,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _busy ? null : () => _place(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: landing.AppColors.orange,
                          foregroundColor: _ink,
                          minimumSize: const Size.fromHeight(46),
                        ),
                        child: Text(_busy ? 'Patientez…' : 'J’ai payé'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _place(false),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                        child: const Text('Valider la commande'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
