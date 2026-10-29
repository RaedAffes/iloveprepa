import 'package:flutter/material.dart';

class PremiumAvatarSelector extends StatefulWidget {
  final ValueChanged<int>? onSelected;
  final int initialSelection;

  const PremiumAvatarSelector({
    super.key,
    this.onSelected,
    this.initialSelection = 1,
  });

  @override
  State<PremiumAvatarSelector> createState() => _PremiumAvatarSelectorState();
}

class _PremiumAvatarSelectorState extends State<PremiumAvatarSelector> {
  late int selected;

  final List<Color> skins = [
    const Color(0xFFF5C9A5), const Color(0xFF9B6043), const Color(0xFFE8B58D),
    const Color(0xFF70432F), const Color(0xFFFFD7B5), const Color(0xFFC58B63),
    const Color(0xFFE9BC91), const Color(0xFF86583F), const Color(0xFFF2C6A0),
    const Color(0xFFAD7654),
  ];

  final List<Color> hairs = [
    const Color(0xFF38251F), const Color(0xFF241B18), const Color(0xFF7A4527),
    const Color(0xFF171719), const Color(0xFFDEAA42), const Color(0xFF493027),
    const Color(0xFF30201B), const Color(0xFF24202B), const Color(0xFFB86B32),
    const Color(0xFF35241D),
  ];

  final List<Color> backgrounds = [
    const Color(0xFFE7DEFF), const Color(0xFFD5F5ED), const Color(0xFFFFE3D7),
    const Color(0xFFDCEBFF), const Color(0xFFFFE8AE), const Color(0xFFFFDDEB),
    const Color(0xFFD9F0FF), const Color(0xFFE8DDFB), const Color(0xFFFFE1C5),
    const Color(0xFFD6F4E2),
  ];

  @override
  void initState() {
    super.initState();
    selected = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choisir un avatar',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1B2340)),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 10,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            final id = index + 1;
            final isSelected = selected == id;
            return GestureDetector(
              onTap: () {
                setState(() => selected = id);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: backgrounds[index],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1B3FA0) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: CustomPaint(
                  painter: _AvatarHeadPainter(
                    skin: skins[index],
                    hair: hairs[index],
                    style: index % 5,
                    expression: index % 3,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => widget.onSelected?.call(selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B3FA0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmer l\'avatar'),
          ),
        ),
      ],
    );
  }
}

class _AvatarHeadPainter extends CustomPainter {
  final Color skin;
  final Color hair;
  final int style;
  final int expression;

  _AvatarHeadPainter({required this.skin, required this.hair, required this.style, required this.expression});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    
    // Simplification for grid view: draw a smaller head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.7, height: size.height * 0.7),
      Paint()..color = skin,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarHeadPainter oldDelegate) => false;
}
