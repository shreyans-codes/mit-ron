import 'package:flutter/material.dart';

import '../core/theme/app_theme_scope.dart';
import '../core/theme/theme_variant.dart';

class ThemePickerButton extends StatelessWidget {
  const ThemePickerButton({super.key, this.icon = Icons.palette_outlined});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: 'Theme',
      onPressed: () => openThemePicker(context),
    );
  }

  static void openThemePicker(BuildContext context) {
    final controller = AppThemeScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListenableBuilder(
            listenable: controller,
            builder: (_, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text(
                      'Appearance',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'Brown Themes',
                      style: Theme.of(sheetContext).textTheme.labelLarge
                          ?.copyWith(
                            color: Theme.of(sheetContext).colorScheme.primary,
                          ),
                    ),
                  ),
                  for (final v in AppThemeVariant.values)
                    ListTile(
                      title: Text(v.label),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: v.isDark
                              ? Colors.brown.withValues(alpha: 0.2)
                              : Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: v.isDark
                                ? Colors.brown.withValues(alpha: 0.4)
                                : Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          v.isDark ? 'Dark' : 'Light',
                          style: TextStyle(
                            fontSize: 12,
                            color: v.isDark
                                ? Colors.brown.shade700
                                : Colors.amber.shade800,
                          ),
                        ),
                      ),
                      leading: Icon(
                        v == controller.variant
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: v == controller.variant
                            ? Theme.of(sheetContext).colorScheme.primary
                            : null,
                      ),
                      selected: v == controller.variant,
                      onTap: () async {
                        await controller.setVariant(v);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
