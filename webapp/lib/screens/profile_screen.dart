import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/auth_user.dart';
import '../widgets/landing/landing_colors.dart' as landing;

/// Global notifier to sync avatar changes instantly across the entire app
class AvatarNotifier extends ChangeNotifier {
  AvatarNotifier._();
  static final instance = AvatarNotifier._();

  int _selectedAvatar = 1;
  int get selectedAvatar => _selectedAvatar;

  void setAvatar(int id) {
    _selectedAvatar = id;
    notifyListeners();
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, required this.onBack});

  final AuthUser user;
  final VoidCallback onBack;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _facultyController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.label);
    _facultyController = TextEditingController(text: widget.user.faculty ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _facultyController.dispose();
    super.dispose();
  }

  void _openAvatarDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFFF5EBDD),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: _AdvancedAvatarSelector(
                initialSelection: AvatarNotifier.instance.selectedAvatar,
                onSelected: (id) {
                  AvatarNotifier.instance.setAvatar(id);
                  Navigator.of(context).pop();
                  setState(() {});
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _resetPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Un e-mail de réinitialisation de mot de passe a été envoyé.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: ArtisticBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF263C3D)),
                        onPressed: widget.onBack,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: ListenableBuilder(
                          listenable: AvatarNotifier.instance,
                          builder: (context, _) {
                            final avatarId = AvatarNotifier.instance.selectedAvatar;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'MON PROFIL',
                                  style: TextStyle(
                                    letterSpacing: 5,
                                    fontSize: 11,
                                    color: Color(0xFF34565A),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                GestureDetector(
                                  onTap: _openAvatarDialog,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        width: 126,
                                        height: 126,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: backgrounds[(avatarId - 1) % backgrounds.length],
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF234F50).withOpacity(0.18),
                                              blurRadius: 35,
                                              spreadRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: CustomPaint(
                                            painter: _AvatarPainter(avatarId: avatarId),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF345F5A),
                                        ),
                                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28),
                                TextField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Nom et Prénom',
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF6C8980)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF6C8980)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: TextEditingController(text: widget.user.email),
                                  enabled: false,
                                  decoration: InputDecoration(
                                    labelText: 'E-mail',
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.4),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF6C8980)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _facultyController,
                                  decoration: InputDecoration(
                                    labelText: 'Faculté / Établissement',
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF6C8980)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF6C8980)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                SizedBox(
                                  width: double.infinity,
                                  child: ArtistButton(
                                    label: 'Réinitialiser le mot de passe  ↗',
                                    style: ArtistButtonStyle.outlined,
                                    onPressed: _resetPassword,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user, required this.onBack});
  final AuthUser user;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ProfilePage(user: user, onBack: onBack);
  }
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.initial,
    this.picture,
    this.size = 32,
    this.inverted = false,
  });

  final String initial;
  final String? picture;
  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AvatarNotifier.instance,
      builder: (context, _) {
        final avatarId = AvatarNotifier.instance.selectedAvatar;
        return ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: Container(
              color: backgrounds[(avatarId - 1) % backgrounds.length],
              child: CustomPaint(
                painter: _AvatarPainter(avatarId: avatarId),
              ),
            ),
          ),
        );
      },
    );
  }
}

// 12 High-Quality Educational Avatars (Student, Graduate, Engineer, Scientist, etc.)
final List<Color> skins = [
  const Color(0xFFF5C9A5), const Color(0xFF9B6043), const Color(0xFFE8B58D),
  const Color(0xFF70432F), const Color(0xFFFFD7B5), const Color(0xFFC58B63),
  const Color(0xFFE9BC91), const Color(0xFF86583F), const Color(0xFFF2C6A0),
  const Color(0xFFAD7654), const Color(0xFFFCE3C2), const Color(0xFF613B24),
];

final List<Color> hairs = [
  const Color(0xFF38251F), const Color(0xFF241B18), const Color(0xFF7A4527),
  const Color(0xFF171719), const Color(0xFFDEAA42), const Color(0xFF493027),
  const Color(0xFF30201B), const Color(0xFF24202B), const Color(0xFFB86B32),
  const Color(0xFF35241D), const Color(0xFFE6C79C), const Color(0xFF100E13),
];

final List<Color> backgrounds = [
  const Color(0xFFE7DEFF), const Color(0xFFD5F5ED), const Color(0xFFFFE3D7),
  const Color(0xFFDCEBFF), const Color(0xFFFFE8AE), const Color(0xFFFFDDEB),
  const Color(0xFFD9F0FF), const Color(0xFFE8DDFB), const Color(0xFFFFE1C5),
  const Color(0xFFD6F4E2), const Color(0xFFFAD2E1), const Color(0xFFDFE1F5),
];

class _AdvancedAvatarSelector extends StatefulWidget {
  final ValueChanged<int>? onSelected;
  final int initialSelection;

  const _AdvancedAvatarSelector({
    this.onSelected,
    this.initialSelection = 1,
  });

  @override
  State<_AdvancedAvatarSelector> createState() => _AdvancedAvatarSelectorState();
}

class _AdvancedAvatarSelectorState extends State<_AdvancedAvatarSelector> {
  late int selected;

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
          'Choisir votre avatar académique',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF263C3D),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sélectionnez votre profil d\'étude (Prépa & Ingénierie).',
          style: TextStyle(color: Color(0xFF476363)),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final id = index + 1;
            final isSelected = selected == id;

            return GestureDetector(
              onTap: () {
                setState(() => selected = id);
                widget.onSelected?.call(id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: backgrounds[index],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF345F5A) : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: CustomPaint(
                  painter: _AvatarPainter(avatarId: id),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final int avatarId;
  _AvatarPainter({required this.avatarId});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 4;
    final index = (avatarId - 1) % 12;

    final skin = skins[index];
    final hair = hairs[index];

    final faceRect = Rect.fromCenter(
      center: Offset(cx, cy + 2),
      width: size.width * 0.5,
      height: size.height * 0.6,
    );

    // Ears
    final skinPaint = Paint()..color = skin;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - (size.width * 0.26), cy + 2), width: size.width * 0.1, height: size.height * 0.16),
      skinPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + (size.width * 0.26), cy + 2), width: size.width * 0.1, height: size.height * 0.16),
      skinPaint,
    );

    // Face
    canvas.drawOval(faceRect, skinPaint);

    // Neck & Collar
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy + (size.height * 0.35)), width: size.width * 0.22, height: size.height * 0.18),
      skinPaint,
    );

    if (index % 4 == 0) {
      final glassPaint = Paint()
        ..color = const Color(0xFF263C3D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx - 10, cy), 7, glassPaint);
      canvas.drawCircle(Offset(cx + 10, cy), 7, glassPaint);
      canvas.drawLine(Offset(cx - 3, cy), Offset(cx + 3, cy), glassPaint);
    } else if (index % 4 == 1) {
      final capPaint = Paint()..color = const Color(0xFF263C3D);
      final path = Path()
        ..moveTo(cx, cy - (size.height * 0.35))
        ..lineTo(cx + (size.width * 0.35), cy - (size.height * 0.25))
        ..lineTo(cx, cy - (size.height * 0.15))
        ..lineTo(cx - (size.width * 0.35), cy - (size.height * 0.25))
        ..close();
      canvas.drawPath(path, capPaint);
    }

    final hairPaint = Paint()..color = hair;
    final hairPath = Path();
    hairPath.addOval(Rect.fromCenter(center: Offset(cx, cy - (size.height * 0.12)), width: size.width * 0.54, height: size.height * 0.38));
    canvas.drawPath(hairPath, hairPaint);

    final eyePaint = Paint()..color = const Color(0xFF263C3D);
    canvas.drawCircle(Offset(cx - (size.width * 0.11), cy), size.width * 0.045, eyePaint);
    canvas.drawCircle(Offset(cx + (size.width * 0.11), cy), size.width * 0.045, eyePaint);

    final smile = Path()
      ..moveTo(cx - (size.width * 0.08), cy + (size.height * 0.14))
      ..quadraticBezierTo(cx, cy + (size.height * 0.22), cx + (size.width * 0.08), cy + (size.height * 0.14));
    canvas.drawPath(
      smile,
      Paint()
        ..color = const Color(0xFF263C3D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) => oldDelegate.avatarId != avatarId;
}

// Artistic background
class ArtisticBackground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF5EBDD),
    );

    void wash(double x, double y, double radius, Color color) {
      canvas.drawCircle(
        Offset(w * x, h * y),
        radius,
        Paint()
          ..color = color.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55),
      );
    }

    wash(0.08, 0.12, w * 0.18, const Color(0xFFE8BBA0));
    wash(0.92, 0.18, w * 0.19, const Color(0xFF8EBAB0));
    wash(0.08, 0.85, w * 0.20, const Color(0xFFA6B6D8));
    wash(0.94, 0.83, w * 0.18, const Color(0xFFD9A0A5));

    final random = math.Random(18);
    final colors = [
      const Color(0xFF477E78),
      const Color(0xFFB66F60),
      const Color(0xFF6C80B2),
      const Color(0xFFCC9E55),
    ];

    for (int i = 0; i < 65; i++) {
      final x = random.nextDouble() * w;
      final y = random.nextDouble() * h;
      if (x > w * 0.25 && x < w * 0.75 && y > h * 0.2 && y < h * 0.8) continue;
      final radius = random.nextDouble() * 2.5 + 0.5;
      canvas.drawCircle(Offset(x, y), radius, Paint()..color = colors[i % colors.length].withOpacity(0.5));
    }
  }

  @override
  bool shouldRepaint(covariant ArtisticBackground oldDelegate) => false;
}

enum ArtistButtonStyle { filled, outlined }

class ArtistButton extends StatefulWidget {
  const ArtistButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = ArtistButtonStyle.filled,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final ArtistButtonStyle style;

  static const Color ink = Color(0xFF263C3D);
  static const Color teal = Color(0xFF477E78);
  static const Color paper = Color(0xFFFBF7F0);

  @override
  State<ArtistButton> createState() => _ArtistButtonState();
}

class _ArtistButtonState extends State<ArtistButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final filled = widget.style == ArtistButtonStyle.filled;
    final foreground = filled ? Colors.white : ArtistButton.ink;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          decoration: BoxDecoration(
            color: filled ? ArtistButton.ink : ArtistButton.paper,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: filled ? Colors.transparent : ArtistButton.teal,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: ArtistButton.ink.withAlpha(_pressed ? 20 : 45),
                blurRadius: _pressed ? 8 : 18,
                offset: Offset(0, _pressed ? 2 : 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: foreground),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
