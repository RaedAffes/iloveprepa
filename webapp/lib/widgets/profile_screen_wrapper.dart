import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../services/auth_user.dart';

/// A wrapper to keep the original API expected by the rest of the app 
/// while using the new ProfileLift implementation.
class ProfileScreenWrapper extends StatelessWidget {
  final AuthUser user;
  final VoidCallback onBack;

  const ProfileScreenWrapper({super.key, required this.user, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ProfileScreen(user: user, onBack: onBack);
  }
}
