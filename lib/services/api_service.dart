import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/aqi_data.dart';

class AqiService {
  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3001';
    if (Platform.isAndroid) return 'http://10.0.2.2:3001';
    return 'http://localhost:3001';
  }

  Future<AqiData> getRealtimeAqi(double lat, double lon) async {
    final uri = Uri.parse('$_baseUrl/api/v1/aqi/realtime').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
      },
    );

    try {
      debugPrint('Fetching AQI data from: $uri');
      final response = await http.get(uri);
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return AqiData.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('No air quality data available for this location.');
      } else {
        // Parse error message from response if available
        String errorMessage;
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          errorMessage = errorData['error'] ?? 'Unknown error occurred';
        } catch (_) {
          errorMessage = 'Failed to load AQI data';
        }
        throw Exception('$errorMessage (Status: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching AQI data: $e');
      rethrow;
    }
  }
}
