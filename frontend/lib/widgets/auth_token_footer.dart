import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

/// Bottom-of-screen token preview; copy matches [AuthService.authorizationHeaderValue].
class AuthTokenFooter extends StatelessWidget {
  const AuthTokenFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final header = AuthService.instance.authorizationHeaderValue;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    if (header == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Authorization (as sent to API)',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SelectableText(
                header,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(
                            alpha: 0.85,
                          ),
                    ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: 'Copy Authorization header value',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: header));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied exact Authorization header value'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
