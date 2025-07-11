import 'package:flutter/material.dart';

/// Extensions on [Color] to provide additional utility methods
extension ColorExtensions on Color {
  /// Returns a new color with the specified alpha value
  /// 
  /// [alpha] should be between 0.0 and 1.0, where 0.0 is completely transparent
  /// and 1.0 is completely opaque.
  Color withValues({double? red, double? green, double? blue, double? alpha}) {
    return Color.fromRGBO(
      (red != null) ? (red * 255).round() : this.red,
      (green != null) ? (green * 255).round() : this.green,
      (blue != null) ? (blue * 255).round() : this.blue,
      alpha ?? this.opacity,
    );
  }
  
  /// Returns a new color with the alpha channel set to the given value
  Color withAlpha(int alpha) => this.withOpacity(alpha / 255);
  
  /// Returns a new color with the opacity set to the given value
  Color withOpacity(double opacity) => Color.fromRGBO(
    this.red,
    this.green,
    this.blue,
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
