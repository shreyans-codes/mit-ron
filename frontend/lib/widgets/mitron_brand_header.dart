import 'package:flutter/material.dart';

import '../core/theme/mitron_colors.dart';

class MitronBrandHeader extends StatelessWidget {
  const MitronBrandHeader({
    super.key,
    this.subtitle = 'Groups, chat, and meetups in one place.',
  });

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mc = MitronColors.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.groups_rounded,
            size: 44,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Mitron',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: mc.brandTitle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: mc.brandSubtitle,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
