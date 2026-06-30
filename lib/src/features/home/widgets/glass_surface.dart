import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.tint = const Color(0x33FFFFFF),
    this.borderOpacity = 0.5,
    this.shadowOpacity = 0.05,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color tint;
  final double borderOpacity;
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final theme = Theme.of(context);
    final surfaceColor = _surfaceColor(theme);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: surfaceColor,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: borderOpacity.clamp(0.06, 0.34),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowOpacity),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Color _surfaceColor(ThemeData theme) {
    final isWhiteOverlay = tint.r == 1.0 && tint.g == 1.0 && tint.b == 1.0;
    if (!isWhiteOverlay) {
      return tint;
    }

    final alpha = tint.a.clamp(0.0, 0.92);
    return Color.alphaBlend(
      theme.colorScheme.surfaceContainerHighest.withValues(alpha: alpha),
      theme.colorScheme.surface,
    );
  }
}
