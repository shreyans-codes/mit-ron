import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Shows `versionName (versionCode)` from the built app (pubspec `version:`).
class AppVersionFooter extends StatelessWidget {
  const AppVersionFooter({super.key});

  static final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Mitron',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted),
          );
        }
        if (!snapshot.hasData) {
          return Text(
            '…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted),
          );
        }
        final p = snapshot.data!;
        return Text(
          'Mitron v${p.version} (${p.buildNumber})',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted),
        );
      },
    );
  }
}
