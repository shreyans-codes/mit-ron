import 'package:flutter/material.dart';

import '../core/utils/platform_image_provider.dart';
import '../models/group.dart';
import '../services/auth_service.dart';

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.group,
    this.radius = 24,
    this.fontSize,
  });

  final Group group;
  final double radius;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<String?>(
      future: AuthService.instance.resolveGroupImageUrl(
        groupId: group.id,
        groupImageUrl: group.groupImageUrl,
      ),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;
        final provider = platformImageProvider(imageUrl);

        if (provider != null) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: scheme.surfaceContainerHighest,
            backgroundImage: provider,
          );
        }

        final initial = group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G';
        return CircleAvatar(
          radius: radius,
          backgroundColor: scheme.primary.withValues(alpha: 0.15),
          child: Text(
            initial,
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: fontSize ?? radius * 0.85,
            ),
          ),
        );
      },
    );
  }
}
