import 'package:flutter/material.dart';

import '../../core/theme/mitron_colors.dart';
import '../../models/auth_session.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_version_footer.dart';
import '../auth/login_page.dart';
import '../settings/settings_page.dart';

/// Temporary landing screen after auth succeeds. Replace with main app shell.
class PlaceholderHomePage extends StatelessWidget {
  const PlaceholderHomePage({super.key, this.session});

  static const String routeName = '/home';

  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    final user = AuthService.instance.currentUser;
    final token = AuthService.instance.token;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitron'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(
                SettingsPage.routeName,
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (user.profilePictureUrl != null)
                  CircleAvatar(
                    backgroundImage: NetworkImage(user.profilePictureUrl!),
                    radius: 24,
                  )
                else
                  const CircleAvatar(
                    child: Icon(Icons.person),
                    radius: 24,
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, ${user.displayName}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: mc.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'You’re signed in. Groups, chat, and meetups will live here as we continue development.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: mc.brandSubtitle,
                  ),
            ),
            const SizedBox(height: 16),
            if (token != null)
              SelectableText(
                'Token: $token',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: mc.textMuted,
                    ),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () async {
                await AuthService.instance.logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    LoginPage.routeName,
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: double.infinity,
              child: AppVersionFooter(),
            ),
          ],
        ),
      ),
    );
  }
}
