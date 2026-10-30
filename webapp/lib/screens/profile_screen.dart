import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

const profileAvatarChoices = [
  'local-avatar-1',
  'local-avatar-2',
  'local-avatar-3',
  'local-avatar-4',
  'local-avatar-5',
  'local-avatar-6',
  'local-avatar-7',
  'local-avatar-8',
  'local-avatar-9',
  'local-avatar-10',
  'local-avatar-11',
  'local-avatar-12',
  'local-avatar-13',
  'local-avatar-14',
  'local-avatar-15',
  'local-avatar-16',
];

class ProfileAvatarNotifier extends ChangeNotifier {
  String selected = profileAvatarChoices.first;

  void select(String avatar) {
    selected = avatar;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('profile_avatar', avatar),
    );
    notifyListeners();
  }
}

final profileAvatarNotifier = ProfileAvatarNotifier();

String accountInitial(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

InputDecoration _profileInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white.withOpacity(0.72),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF8CB9D8), width: 1.4),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF8CB9D8), width: 1.4),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF3B82C4), width: 2.2),
    ),
  );
}

class _EditableProfileField extends StatelessWidget {
  const _EditableProfileField({
    required this.controller,
    required this.label,
    required this.editing,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool editing;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: editing
            ? const [
                BoxShadow(
                  color: Color(0x243B82C4),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        readOnly: !editing,
        keyboardType: keyboardType,
        decoration: _profileInputDecoration(label).copyWith(
          fillColor: editing ? Colors.white : Colors.white.withOpacity(0.72),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: editing
                  ? const Color(0xFF3B82C4)
                  : const Color(0xFF8CB9D8),
              width: editing ? 2 : 1.4,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: editing
                  ? const Color(0xFFE58B4A)
                  : const Color(0xFF8CB9D8),
              width: editing ? 2.2 : 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.onBack,
    this.onSaved,
  });

  final AuthUser user;
  final VoidCallback onBack;
  final ValueChanged<AuthUser>? onSaved;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _givenNameController;
  late TextEditingController _familyNameController;
  late TextEditingController _facultyController;
  late TextEditingController _phoneController;
  String? _selectedAvatar;
  bool _editingGivenName = false;
  bool _editingFamilyName = false;
  bool _editingFaculty = false;
  bool _editingPhone = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _givenNameController = TextEditingController(
      text: widget.user.givenName ?? '',
    );
    _familyNameController = TextEditingController(
      text: widget.user.familyName ?? '',
    );
    _facultyController = TextEditingController(text: widget.user.faculty ?? '');
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _selectedAvatar = profileAvatarNotifier.selected;
    _rememberProfileValues();
    _restoreAvatar();
  }

  late String _savedGivenName;
  late String _savedFamilyName;
  late String _savedFaculty;
  late String _savedPhone;

  void _rememberProfileValues() {
    _savedGivenName = _givenNameController.text;
    _savedFamilyName = _familyNameController.text;
    _savedFaculty = _facultyController.text;
    _savedPhone = _phoneController.text;
  }

  Future<void> _restoreAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('profile_avatar');
    if (avatar == null || !profileAvatarChoices.contains(avatar) || !mounted) {
      return;
    }
    profileAvatarNotifier.select(avatar);
    setState(() => _selectedAvatar = avatar);
  }

  @override
  void dispose() {
    _givenNameController.dispose();
    _familyNameController.dispose();
    _facultyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _chooseAvatar() {
    showDialog<String>(
      context: context,
      builder: (context) => _AvatarChoiceDialog(
        selectedAvatar: _selectedAvatar ?? profileAvatarChoices.first,
      ),
    ).then((avatar) {
      if (avatar != null && mounted) {
        profileAvatarNotifier.select(avatar);
        setState(() => _selectedAvatar = avatar);
      }
    });
  }

  bool get _editingProfile =>
      _editingGivenName ||
      _editingFamilyName ||
      _editingFaculty ||
      _editingPhone;

  void _startEditing() {
    setState(() {
      _editingGivenName = true;
      _editingFamilyName = true;
      _editingFaculty = true;
      _editingPhone = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _givenNameController.text = _savedGivenName;
      _familyNameController.text = _savedFamilyName;
      _facultyController.text = _savedFaculty;
      _phoneController.text = _savedPhone;
      _editingGivenName = false;
      _editingFamilyName = false;
      _editingFaculty = false;
      _editingPhone = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final result = await AuthService.updateProfile(
      givenName: _givenNameController.text.trim(),
      familyName: _familyNameController.text.trim(),
      faculty: _facultyController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.user != null) {
      setState(() {
        _editingGivenName = false;
        _editingFamilyName = false;
        _editingFaculty = false;
        _editingPhone = false;
        _rememberProfileValues();
      });
      widget.onSaved?.call(result.user!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Impossible d’enregistrer le profil.'),
        ),
      );
    }
  }

  Future<void> _handleBack() async {
    if (_editingProfile) _cancelEditing();
    if (mounted) widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: PainterlyBackground()),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFFF5EBDD),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF263C3D),
                          ),
                          onPressed: _saving ? null : _handleBack,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
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
                            _ProfileAvatar(
                              initial: accountInitial(widget.user.label),
                              picture: null,
                              canEdit: true,
                              onEdit: _chooseAvatar,
                            ),
                            const SizedBox(height: 18),
                            const SizedBox(height: 24),
                            _EditableProfileField(
                              controller: _givenNameController,
                              label: 'Prénom',
                              editing: _editingGivenName,
                            ),
                            const SizedBox(height: 16),
                            _EditableProfileField(
                              controller: _familyNameController,
                              label: 'Nom',
                              editing: _editingFamilyName,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: TextEditingController(
                                text: widget.user.email,
                              ),
                              enabled: false,
                              decoration: _profileInputDecoration('E-mail'),
                            ),
                            const SizedBox(height: 16),
                            _EditableProfileField(
                              controller: _facultyController,
                              label: 'Faculté / Établissement',
                              editing: _editingFaculty,
                            ),
                            const SizedBox(height: 16),
                            _EditableProfileField(
                              controller: _phoneController,
                              label: 'Numéro de téléphone',
                              keyboardType: TextInputType.phone,
                              editing: _editingPhone,
                            ),
                            const SizedBox(height: 22),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _editingProfile
                                  ? Row(
                                      key: const ValueKey('profile-actions'),
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _saving
                                                ? null
                                                : _cancelEditing,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFF3B82C4,
                                              ),
                                              backgroundColor: Colors.white,
                                              side: const BorderSide(
                                                color: Color(0xFF3B82C4),
                                                width: 1.5,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 15,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const Text('Annuler'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: _saving
                                                ? null
                                                : _saveProfile,
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF3B82C4,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 15,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: Text(
                                              _saving
                                                  ? 'Enregistrement...'
                                                  : 'Enregistrer',
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : SizedBox(
                                      key: const ValueKey('profile-update'),
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _startEditing,
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Mettre à jour le profil',
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF3B82C4,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
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
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onBack,
    this.onSaved,
  });
  final AuthUser user;
  final VoidCallback onBack;
  final ValueChanged<AuthUser>? onSaved;

  @override
  Widget build(BuildContext context) {
    return ProfilePage(user: user, onBack: onBack, onSaved: onSaved);
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
      listenable: profileAvatarNotifier,
      builder: (context, _) {
        final imageUrl = profileAvatarNotifier.selected;
        return ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: imageUrl.startsWith('local-avatar-')
                ? _LocalAvatar(
                    avatarId: _localAvatarId(imageUrl),
                    initial: initial,
                    inverted: inverted,
                  )
                : _RemoteAvatarImage(
                    url: imageUrl,
                    fallback: _InitialAvatar(
                      initial: initial,
                      inverted: inverted,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

int _localAvatarId(String value) {
  return int.tryParse(value.replaceFirst('local-avatar-', '')) ?? 1;
}

class _LocalAvatar extends StatelessWidget {
  const _LocalAvatar({
    required this.avatarId,
    required this.initial,
    required this.inverted,
  });

  final int avatarId;
  final String initial;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/avatars/avatar-$avatarId.png',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _AvatarFallback(
        avatarId: avatarId,
        initial: initial,
        inverted: inverted,
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.avatarId,
    required this.initial,
    required this.inverted,
  });

  final int avatarId;
  final String initial;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final background = [
      const Color(0xFFB6E3F4),
      const Color(0xFFC0AEDE),
      const Color(0xFFFFD5DC),
      const Color(0xFFD1D4F9),
      const Color(0xFFFFDFBF),
      const Color(0xFFDECBE4),
      const Color(0xFFF4D150),
      const Color(0xFFA7F3D0),
    ][(avatarId - 1) % 8];
    return ColoredBox(
      color: inverted ? const Color(0xFFF5EBDD) : background,
      child: CustomPaint(
        painter: _AvatarPainter(avatarId: avatarId),
        child: Center(
          child: avatarId == 1
              ? Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE7DEFF),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 38,
          color: const Color(0xFF3B82C4).withOpacity(0.7),
        ),
      ),
    );
  }
}

class _RemoteAvatarImage extends StatelessWidget {
  const _RemoteAvatarImage({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        Image.network(
          url,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initial, required this.inverted});

  final String initial;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: inverted ? const Color(0xFFF5EBDD) : const Color(0xFF3B82C4),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: inverted ? const Color(0xFF3B82C4) : Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initial,
    required this.picture,
    required this.canEdit,
    required this.onEdit,
  });

  final String initial;
  final String? picture;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AccountAvatar(initial: initial, picture: picture, size: 126),
        if (canEdit)
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: const Color(0xFF3B82C4),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onEdit,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarChoiceDialog extends StatelessWidget {
  const _AvatarChoiceDialog({required this.selectedAvatar});

  final String selectedAvatar;

  @override
  Widget build(BuildContext context) {
    return _AvatarChoiceDialogContent(selectedAvatar: selectedAvatar);
  }
}

class _AvatarChoiceDialogContent extends StatefulWidget {
  const _AvatarChoiceDialogContent({required this.selectedAvatar});

  final String selectedAvatar;

  @override
  State<_AvatarChoiceDialogContent> createState() =>
      _AvatarChoiceDialogContentState();
}

class _AvatarChoiceDialogContentState
    extends State<_AvatarChoiceDialogContent> {
  late String selectedAvatar = widget.selectedAvatar;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF5EBDD),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text(
        'Choisir votre avatar',
        style: TextStyle(color: Color(0xFF263C3D), fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sélectionnez un style qui vous ressemble.',
                style: TextStyle(color: Color(0xFF5C7070)),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: profileAvatarChoices.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final avatar = profileAvatarChoices[index];
                  final isSelected = avatar == selectedAvatar;
                  return InkWell(
                    onTap: () => setState(() => selectedAvatar = avatar),
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: EdgeInsets.all(isSelected ? 3 : 0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE58B4A)
                                  : Colors.white.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: isSelected
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x38E58B4A),
                                        blurRadius: 12,
                                        offset: Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: _LocalAvatar(
                                avatarId: _localAvatarId(avatar),
                                initial: accountInitial(''),
                                inverted: false,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Style ${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFFB96831)
                                : const Color(0xFF5C7070),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3B82C4),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(selectedAvatar),
          child: const Text('Utiliser cet avatar'),
        ),
      ],
    );
  }
}

class _VroidAvatarGallery extends StatelessWidget {
  const _VroidAvatarGallery();

  static const _avatars = [
    'https://api.dicebear.com/9.x/notionists/png?seed=study-1&backgroundColor=b6e3f4',
    'https://api.dicebear.com/9.x/notionists/png?seed=study-2&backgroundColor=c0aede',
    'https://api.dicebear.com/9.x/notionists/png?seed=study-3&backgroundColor=ffd5dc',
    'https://api.dicebear.com/9.x/notionists/png?seed=study-4&backgroundColor=d1d4f9',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AVATARS 3D',
          style: TextStyle(
            color: Color(0xFF34565A),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _avatars.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return ClipOval(
                child: Container(
                  width: 58,
                  height: 58,
                  color: Colors.white.withOpacity(0.65),
                  child: _RemoteAvatarImage(
                    url: _avatars[index],
                    fallback: const _AvatarPlaceholder(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// 12 High-Quality Educational Avatars (Student, Graduate, Engineer, Scientist, etc.)
final List<Color> skins = [
  const Color(0xFFF5C9A5),
  const Color(0xFF9B6043),
  const Color(0xFFE8B58D),
  const Color(0xFF70432F),
  const Color(0xFFFFD7B5),
  const Color(0xFFC58B63),
  const Color(0xFFE9BC91),
  const Color(0xFF86583F),
  const Color(0xFFF2C6A0),
  const Color(0xFFAD7654),
  const Color(0xFFFCE3C2),
  const Color(0xFF613B24),
];

final List<Color> hairs = [
  const Color(0xFF38251F),
  const Color(0xFF241B18),
  const Color(0xFF7A4527),
  const Color(0xFF171719),
  const Color(0xFFDEAA42),
  const Color(0xFF493027),
  const Color(0xFF30201B),
  const Color(0xFF24202B),
  const Color(0xFFB86B32),
  const Color(0xFF35241D),
  const Color(0xFFE6C79C),
  const Color(0xFF100E13),
];

final List<Color> backgrounds = [
  const Color(0xFFE7DEFF),
  const Color(0xFFD5F5ED),
  const Color(0xFFFFE3D7),
  const Color(0xFFDCEBFF),
  const Color(0xFFFFE8AE),
  const Color(0xFFFFDDEB),
  const Color(0xFFD9F0FF),
  const Color(0xFFE8DDFB),
  const Color(0xFFFFE1C5),
  const Color(0xFFD6F4E2),
  const Color(0xFFFAD2E1),
  const Color(0xFFDFE1F5),
];

class _AdvancedAvatarSelector extends StatefulWidget {
  final ValueChanged<int>? onSelected;
  final int initialSelection;

  const _AdvancedAvatarSelector({this.onSelected, this.initialSelection = 1});

  @override
  State<_AdvancedAvatarSelector> createState() =>
      _AdvancedAvatarSelectorState();
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
                    color: isSelected
                        ? const Color(0xFF345F5A)
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: CustomPaint(painter: _AvatarPainter(avatarId: id)),
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
      Rect.fromCenter(
        center: Offset(cx - (size.width * 0.26), cy + 2),
        width: size.width * 0.1,
        height: size.height * 0.16,
      ),
      skinPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + (size.width * 0.26), cy + 2),
        width: size.width * 0.1,
        height: size.height * 0.16,
      ),
      skinPaint,
    );

    // Face
    canvas.drawOval(faceRect, skinPaint);

    // Neck & Collar
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, cy + (size.height * 0.35)),
        width: size.width * 0.22,
        height: size.height * 0.18,
      ),
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
    hairPath.addOval(
      Rect.fromCenter(
        center: Offset(cx, cy - (size.height * 0.12)),
        width: size.width * 0.54,
        height: size.height * 0.38,
      ),
    );
    canvas.drawPath(hairPath, hairPaint);

    final eyePaint = Paint()..color = const Color(0xFF263C3D);
    canvas.drawCircle(
      Offset(cx - (size.width * 0.11), cy),
      size.width * 0.045,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(cx + (size.width * 0.11), cy),
      size.width * 0.045,
      eyePaint,
    );

    final smile = Path()
      ..moveTo(cx - (size.width * 0.08), cy + (size.height * 0.14))
      ..quadraticBezierTo(
        cx,
        cy + (size.height * 0.22),
        cx + (size.width * 0.08),
        cy + (size.height * 0.14),
      );
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
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      oldDelegate.avatarId != avatarId;
}

class PainterlyBackground extends CustomPainter {
  const PainterlyBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF5EBDD));

    canvas.save();
    canvas.clipRect(rect);

    final circles = Paint()..style = PaintingStyle.fill;
    final circleData = [
      (
        Offset(size.width * 0.1, size.height * 0.2),
        size.width * 0.035,
        const Color(0xFFE8D5B8),
        0.42,
      ),
      (
        Offset(size.width * 0.9, size.height * 0.2),
        size.width * 0.028,
        const Color(0xFFD8C5A9),
        0.38,
      ),
      (
        Offset(size.width * 0.07, size.height * 0.78),
        size.width * 0.052,
        const Color(0xFFE2CDB0),
        0.34,
      ),
      (
        Offset(size.width * 0.93, size.height * 0.78),
        size.width * 0.052,
        const Color(0xFFE2CDB0),
        0.34,
      ),
      (
        Offset(size.width * 0.16, size.height * 0.86),
        size.width * 0.018,
        const Color(0xFFCDB28F),
        0.45,
      ),
      (
        Offset(size.width * 0.84, size.height * 0.86),
        size.width * 0.018,
        const Color(0xFFCDB28F),
        0.45,
      ),
    ];
    for (final (center, radius, color, opacity) in circleData) {
      circles.color = color.withOpacity(opacity);
      canvas.drawCircle(center, radius, circles);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PainterlyBackground oldDelegate) => false;
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
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = colors[i % colors.length].withOpacity(0.5),
      );
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
