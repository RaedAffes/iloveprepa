import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Donation screen shown in the main area when the Don icon is tapped.
/// Payment is made by D17 only: tapping the button reveals the merchant card
/// number to copy, then the visitor pays from their D17 app.
///
/// The background is a static star field tinted with the app's palette
/// (navy-blue / orange) on a white surface.
class DonView extends StatefulWidget {
  const DonView({super.key});

  @override
  State<DonView> createState() => _DonViewState();
}

/// The D17 merchant card number presented to visitors.
const String kD17Number = '25680686';

class _DonViewState extends State<DonView> {
  bool _showNumber = false;

  void _revealNumber() {
    if (_showNumber) return;
    setState(() => _showNumber = true);
  }

  Future<void> _copyNumber() async {
    await Clipboard.setData(const ClipboardData(text: kD17Number));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro copié !')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFFFF),
      width: double.infinity,
      height: double.infinity,
      child: Align(
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Soutenir iloveprepa',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Pacifico',
                    height: 1.1,
                    fontSize: 36,
                    color: Color(0xFF212529),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Votre soutien fait grandir notre idée. '
                  'Merci de faire partie de l’aventure. ❤️',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 1.5,
                    color: Color(0xFF57565C),
                  ),
                ),
                const SizedBox(height: 26),
                _buildRevealButton(),
                if (_showNumber) ...[
                  const SizedBox(height: 20),
                  _buildNumberCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevealButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _revealNumber,
        borderRadius: BorderRadius.circular(48),
        child: Ink(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFFF923C),
            borderRadius: BorderRadius.circular(48),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.smartphone_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Faire un don via D17',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1F212529)),
      ),
      child: Column(
        children: [
          const Text(
            'Numéro D17',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF838788),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                kD17Number,
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                  letterSpacing: 2,
                  color: Color(0xFF212529),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _copyNumber,
                borderRadius: BorderRadius.circular(20),
                child: const Tooltip(
                  message: 'Copier',
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 22,
                      color: Color(0xFFFF923C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}