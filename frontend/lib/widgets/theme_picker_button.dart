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
              final grouped = <String, List<AppThemeVariant>>{};
              for (final v in AppThemeVariant.values) {
                grouped.putIfAbsent(v.colorFamily, () => []).add(v);
              }

              return SingleChildScrollView(
                child: Column(
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
                    ...grouped.entries.expand(
                      (entry) => [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                          child: Text(
                            '${entry.key} Themes',
                            style: Theme.of(sheetContext).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    sheetContext,
                                  ).colorScheme.primary,
                                ),
                          ),
                        ),
                        ...entry.value.map(
                          (v) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ListTile(
                              title: Text(v.label),
                              subtitle: Text(
                                v.description,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(sheetContext)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: v.isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade400,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  v.isDark ? 'Dark' : 'Light',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: v.isDark
                                        ? Theme.of(sheetContext)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7)
                                        : Theme.of(sheetContext)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
