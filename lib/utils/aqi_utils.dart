import 'package:flutter/material.dart';

class AqiUtils {
  static ({Color color, String category, String healthTip}) getAqiDetails(
      String source, double aqi) {
    if (source == 'ground') {
      // Use more granular categories for ground data
      if (aqi <= 50) {
        return (
          color: Colors.green,
          category: 'Good',
          healthTip: 'Air quality is excellent. It\'s a great day to be active outside.'
        );
      } else if (aqi <= 100) {
        return (
          color: Colors.yellow.shade700,
          category: 'Satisfactory',
          healthTip: 'Sensitive individuals should avoid heavy outdoor exertion.'
        );
      } else if (aqi <= 200) {
        return (
          color: Colors.orange,
          category: 'Moderate',
          healthTip: 'General public, especially children and the elderly, should reduce outdoor activities.'
        );
      } else if (aqi <= 300) {
        return (
          color: Colors.red,
          category: 'Poor',
          healthTip: 'Everyone should avoid outdoor exertion. People with respiratory issues should stay indoors.'
        );
      } else if (aqi <= 400) {
        return (
          color: Colors.purple,
          category: 'Very Poor',
          healthTip: 'Remain indoors and keep windows closed. Air purifiers are recommended.'
        );
      } else {
        return (
          color: const Color(0xFF800000), // Dark red for Severe
          category: 'Severe',
          healthTip: 'Stay indoors and avoid all physical activity. Serious risk of respiratory impact.'
        );
      }
    } else {
      // Use broader categories for satellite AOD data
       if (aqi <= 75) {
        return (
          color: Colors.green,
          category: 'Good',
          healthTip: 'Satellite estimates show good air quality.'
        );
      } else if (aqi <= 150) {
        return (
          color: Colors.yellow.shade700,
          category: 'Moderate',
          healthTip: 'Satellite data suggests moderate pollution. Sensitive groups take note.'
        );
      } else if (aqi <= 250) {
        return (
          color: Colors.orange,
          category: 'Poor',
          healthTip: 'Satellite estimates indicate poor air quality. Reduce outdoor activities.'
        );
      } else {
        return (
          color: Colors.red,
          category: 'Very Poor',
          healthTip: 'Satellite data indicates very poor air quality. Avoid outdoor exertion.'
        );
      }
    }
  }
} 