import 'package:flutter/material.dart';

/// App bar that always shows an explicit back control when the route can pop.
///
/// On web, [AppBar]'s default leading widget is sometimes omitted; this avoids
/// that by setting [leading] explicitly from [Navigator.canPop].
class MitronAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MitronAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.bottom,
    this.centerTitle,
  });

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      centerTitle: centerTitle,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: titleWidget ?? (title != null ? Text(title!) : null),
      actions: actions,
      bottom: bottom,
    );
  }
}
