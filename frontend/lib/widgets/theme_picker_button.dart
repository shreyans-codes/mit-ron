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
                  for (final v in AppThemeVariant.values)
                    ListTile(
                      title: Text(v.label),
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
