import 'package:flutter/material.dart';
import '../../core/theme/mitron_colors.dart';
import '../../services/notification_service.dart';
import '../shell/placeholder_home_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const String routeName = '/onboarding';

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _loading = false;

  Future<void> _enableNotifications() async {
    setState(() => _loading = true);
    await NotificationService.instance.requestNotificationPermission();
    await NotificationService.instance.setOnboardingComplete();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PlaceholderHomePage()),
      );
    }
  }

  Future<void> _skip() async {
    await NotificationService.instance.setOnboardingComplete();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PlaceholderHomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mc = MitronColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: mc.authBackgroundGradient()),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 80,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Stay Connected',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enable notifications to receive updates about friend requests, group messages, and more.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: mc.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(flex: 2),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _enableNotifications,
                        child: _loading
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : const Text('Enable Notifications'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading ? null : _skip,
                      child: const Text('Maybe Later'),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
