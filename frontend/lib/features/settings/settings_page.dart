import 'package:flutter/material.dart';

import '../../core/theme/mitron_colors.dart';
import '../../models/auth_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/theme_picker_button.dart';
import '../auth/login_page.dart';
import 'update_profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static const String routeName = '/settings';

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AuthUser _user;

  @override
  void initState() {
    super.initState();
    _user = AuthService.instance.currentUser!;
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.instance.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          LoginPage.routeName,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _SectionHeader(title: 'Appearance', mc: mc),
          ListTile(
            onTap: () => ThemePickerButton.openThemePicker(context),
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Change Theme'),
            subtitle: const Text('Switch between light, dark, and acadamia themes'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const Divider(height: 32),
          _SectionHeader(title: 'Account', mc: mc),
          ListTile(
            onTap: () async {
              final updatedUser = await Navigator.of(context).pushNamed(
                UpdateProfilePage.routeName,
              );
              
              if (updatedUser != null && updatedUser is AuthUser && mounted) {
                setState(() {
                  _user = updatedUser;
                });
              }
            },
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Update Profile'),
            subtitle: const Text('Change name and profile picture'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const Divider(height: 32),
          _SectionHeader(title: 'Session', mc: mc),
          ListTile(
            onTap: _logout,
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.mc});

  final String title;
  final MitronColors mc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: mc.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
