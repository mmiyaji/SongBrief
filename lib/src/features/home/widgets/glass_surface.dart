import 'package:flutter/foundation.dart';
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
  }) : section = false;

  /// A grouping on the page itself. Overlays can still use a raised surface.
  const GlassSurface.section({
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
    super.key,
  }) : section = true,
       radius = 0,
       tint = Colors.transparent,
       borderOpacity = 0,
       shadowOpacity = 0;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color tint;
  final double borderOpacity;
  final double shadowOpacity;
  final bool section;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final theme = Theme.of(context);
    if (section) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      );
    }
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
        // CanvasKit must prepare blur shaders for each cold Web context.
        // The existing surface tint and border provide separation without it.
        boxShadow: kIsWeb
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: shadowOpacity),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
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
