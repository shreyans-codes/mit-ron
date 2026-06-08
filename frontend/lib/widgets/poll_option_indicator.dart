import 'package:flutter/material.dart';

/// Shape-based poll indicator — no icon font, works on web.
class PollOptionIndicator extends StatelessWidget {
  const PollOptionIndicator({
    super.key,
    required this.selected,
    required this.multiple,
    required this.color,
  });

  final bool selected;
  final bool multiple;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (multiple) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: selected ? color.withValues(alpha: 0.85) : Colors.transparent,
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.85 : 0.45),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: selected
            ? Text(
                '✓',
                style: TextStyle(
                  color: _checkmarkColor(color),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              )
            : null,
      );
    }

    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.85 : 0.45),
                width: 1.5,
              ),
            ),
          ),
          if (selected)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    );
  }

  Color _checkmarkColor(Color base) {
    final luminance = base.computeLuminance();
    return luminance > 0.55 ? const Color(0xFF2C2416) : Colors.white;
  }
}
