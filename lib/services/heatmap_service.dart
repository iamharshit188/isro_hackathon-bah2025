import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HeatmapService {
  static const String baseUrl = 'http://localhost:3001/api/v1';

  Future<List<HeatmapPoint>> getHeatmapData({
    required LatLngBounds bounds,
    required double zoomLevel,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/heatmap-data').replace(queryParameters: {
          'bounds': json.encode({
            'northeast': {'lat': bounds.northeast.latitude, 'lng': bounds.northeast.longitude},
            'southwest': {'lat': bounds.southwest.latitude, 'lng': bounds.southwest.longitude},
          }),
          'zoom_level': zoomLevel.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['points'] as List)
            .map((point) => HeatmapPoint.fromJson(point))
            .toList();
      }

      throw Exception('Failed to load heatmap data');
    } catch (e) {
      return [];
    }
  }
}

class HeatmapPoint {
  final double latitude;
  final double longitude;
  final double intensity;
  final double aqiValue;
  final String source;
  final DateTime timestamp;

  HeatmapPoint({
    required this.latitude,
    required this.longitude,
    required this.intensity,
    required this.aqiValue,
    required this.source,
    required this.timestamp,
  });

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    return HeatmapPoint(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      intensity: json['intensity'].toDouble(),
      aqiValue: json['aqi_value'].toDouble(),
      source: json['source'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
