import 'package:flutter/material.dart';

enum MitronButtonType { primary, secondary, text, destructive, icon }

class MitronButton extends StatelessWidget {
  final MitronButtonType type;
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool fullWidth;

  const MitronButton({
    super.key,
    required this.type,
    this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildButton(Widget button) {
      if (fullWidth) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(width: double.infinity, child: button),
        );
      }
      return button;
    }

    if (type == MitronButtonType.icon) {
      return IconButton(
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Icon(icon ?? Icons.circle),
        onPressed: isLoading ? null : onPressed,
      );
    }

    if (label == null) {
      throw ArgumentError('MitronButton requires label for non-icon types');
    }

    if (type == MitronButtonType.destructive) {
      final button = OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.error,
                ),
              )
            : (icon != null ? Icon(icon) : const SizedBox.shrink()),
        label: Text(label ?? ''),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          side: BorderSide(color: theme.colorScheme.error),
        ),
      );
      return buildButton(button);
    }

    if (type == MitronButtonType.secondary) {
      final button = OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : (icon != null ? Icon(icon) : const SizedBox.shrink()),
        label: Text(label ?? ''),
      );
      return buildButton(button);
    }

    if (type == MitronButtonType.text) {
      final button = TextButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : (icon != null ? Icon(icon) : const SizedBox.shrink()),
        label: Text(label ?? ''),
      );
      return buildButton(button);
    }

    final button = FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : (icon != null ? Icon(icon) : const SizedBox.shrink()),
      label: Text(label ?? ''),
    );

    return buildButton(button);
  }
}

class MitronIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;

  const MitronIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      icon: Icon(icon, color: color),
      onPressed: onPressed,
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
