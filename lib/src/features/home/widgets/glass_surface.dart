import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowOpacity),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: FakeGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        settings: LiquidGlassSettings(
          blur: 18,
          thickness: 8,
          glassColor: tint,
          lightIntensity: 0.45,
          ambientStrength: 0.18,
          saturation: 1.18,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
