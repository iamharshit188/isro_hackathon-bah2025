import 'package:flutter/material.dart';

/// Extensions on [Color] to provide additional utility methods
extension ColorExtensions on Color {
  Color withValues({double? red, double? green, double? blue, double? alpha}) {
    return Color.fromRGBO(
      (red != null) ? (red * 255).round() : (toARGB32() >> 16) & 0xFF,
      (green != null) ? (green * 255).round() : (toARGB32() >> 8) & 0xFF,
      (blue != null) ? (blue * 255).round() : toARGB32() & 0xFF,
      alpha ?? ((toARGB32() >> 24) & 0xFF) / 255.0,
    );
  }

  Color withAlpha(int alpha) => withOpacity(alpha / 255);

  Color withOpacity(double opacity) => Color.fromRGBO(
        (toARGB32() >> 16) & 0xFF,
        (toARGB32() >> 8) & 0xFF,
        toARGB32() & 0xFF,
        opacity,
      );
  
  /// Returns a new color that is lighter by the given percent
  Color lighter(double percent) {
    assert(percent >= 0 && percent <= 1);
    
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + percent).clamp(0.0, 1.0));
    
    return hslLight.toColor();
  }
  
  /// Returns a new color that is darker by the given percent
  Color darker(double percent) {
    assert(percent >= 0 && percent <= 1);
    
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - percent).clamp(0.0, 1.0));
    
    return hslDark.toColor();
  }
}
