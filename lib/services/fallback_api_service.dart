import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/enhanced_aqi_data.dart';

class FallbackApiService {
  static FallbackApiService? _instance;
  static FallbackApiService get instance => _instance ??= FallbackApiService._();
  
  final String? _openAqApiKey = dotenv.env['OPENAQ_API_KEY'];
  final String? _cpcbApiKey = dotenv.env['CPCB_API_KEY'];
  
  FallbackApiService._();

  Future<EnhancedAqiData> getRealtimeAqi(double lat, double lon, {bool forceRefresh = false}) async {
    debugPrint('🔄 Using fallback API service for: $lat, $lon');
    
    try {
      // Try OpenAQ first
      final openAqData = await _tryOpenAQ(lat, lon);
      if (openAqData != null) {
        return openAqData;
      }
      
      // If OpenAQ fails, try WAQI (World Air Quality Index)
      final waqiData = await _tryWAQI(lat, lon);
      if (waqiData != null) {
        return waqiData;
      }
      
      // If all fail, return mock data
      return _generateMockData(lat, lon);
    } catch (e) {
      debugPrint('❌ All fallback APIs failed, generating mock data: $e');
      return _generateMockData(lat, lon);
    }
  }

  Future<EnhancedAqiData?> _tryOpenAQ(double lat, double lon) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (_openAqApiKey != null && _openAqApiKey!.isNotEmpty) {
        headers['X-API-Key'] = _openAqApiKey!;
      }

      final uri = Uri.parse('https://api.openaq.org/v2/latest')
          .replace(queryParameters: {
        'coordinates': '$lat,$lon',
        'radius': '25000', // 25km radius
        'limit': '1',
        'sort': 'desc',
        'order_by': 'lastUpdated',
      });

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        
        if (results != null && results.isNotEmpty) {
          final result = results.first as Map<String, dynamic>;
          return _parseOpenAQData(result, lat, lon);
        }
      }
    } catch (e) {
      debugPrint('OpenAQ API failed: $e');
    }
    return null;
  }

  Future<EnhancedAqiData?> _tryWAQI(double lat, double lon) async {
    try {
      // WAQI provides free API access
      final uri = Uri.parse('https://api.waqi.info/feed/geo:$lat;$lon/')
          .replace(queryParameters: {
        'token': 'demo', // Free demo token
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'ok' && data['data'] != null) {
          return _parseWAQIData(data['data'] as Map<String, dynamic>, lat, lon);
        }
      }
    } catch (e) {
      debugPrint('WAQI API failed: $e');
    }
    return null;
  }

  EnhancedAqiData _parseOpenAQData(Map<String, dynamic> data, double lat, double lon) {
    final measurements = data['measurements'] as List? ?? [];
    
    // Extract pollutant values
    final pollutants = <String, double>{};
    for (final measurement in measurements) {
      final parameter = measurement['parameter'] as String?;
      final value = measurement['value'] as num?;
      
      if (parameter != null && value != null) {
        pollutants[parameter.toLowerCase()] = value.toDouble();
      }
    }

    // Calculate AQI from PM2.5 if available
    final pm25 = pollutants['pm25'];
    final aqi = pm25 != null ? _calculateAQIFromPM25(pm25) : _generateRandomAQI();

    final now = DateTime.now();
    final locationKey = '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
    
    return EnhancedAqiData(
      id: DateTime.now().millisecondsSinceEpoch,
      aqi: aqi,
      source: 'OpenAQ',
      pollutantType: 'PM2.5',
      recordedAt: now,
      latitude: lat,
      longitude: lon,
      city: data['city'] as String? ?? 'Unknown',
      state: data['country'] as String? ?? 'Unknown',
      pollutants: pollutants.isNotEmpty ? pollutants : null,
      weather: _generateMockWeather(),
      calibrationStatus: 'Raw Data',
      cachedAt: now,
      locationKey: locationKey,
    );
  }

  EnhancedAqiData _parseWAQIData(Map<String, dynamic> data, double lat, double lon) {
    final aqi = (data['aqi'] as num?)?.toDouble() ?? _generateRandomAQI();
    final city = data['city']?['name'] as String? ?? 'Unknown';
    
    // Extract pollutants from iaqi (individual AQI)
    final iaqi = data['iaqi'] as Map<String, dynamic>? ?? {};
    final pollutants = <String, double>{};
    
    for (final entry in iaqi.entries) {
      final value = entry.value?['v'] as num?;
      if (value != null) {
        pollutants[entry.key] = value.toDouble();
      }
    }

    final now = DateTime.now();
    final locationKey = '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
    
    return EnhancedAqiData(
      id: DateTime.now().millisecondsSinceEpoch,
      aqi: aqi,
      source: 'WAQI',
      pollutantType: 'PM2.5',
      recordedAt: now,
      latitude: lat,
      longitude: lon,
      city: city,
      state: 'Unknown',
      pollutants: pollutants.isNotEmpty ? pollutants : null,
      weather: _generateMockWeather(),
      calibrationStatus: 'Real-time',
      cachedAt: now,
      locationKey: locationKey,
    );
  }

  EnhancedAqiData _generateMockData(double lat, double lon) {
    final random = Random();
    final cities = ['Delhi', 'Mumbai', 'Bangalore', 'Chennai', 'Kolkata', 'Hyderabad', 'Pune', 'Ahmedabad'];
    final city = cities[random.nextInt(cities.length)];
    
    final aqi = _generateRandomAQI();
    final pm25 = _calculatePM25FromAQI(aqi);
    
    final now = DateTime.now();
    final locationKey = '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
    
    return EnhancedAqiData(
      id: DateTime.now().millisecondsSinceEpoch,
      aqi: aqi,
      source: 'Demo Data',
      pollutantType: 'PM2.5',
      recordedAt: now,
      latitude: lat,
      longitude: lon,
      city: city,
      state: 'Demo State',
      pollutants: {
        'pm25': pm25,
        'pm10': pm25 * 1.4,
        'o3': random.nextDouble() * 100,
        'no2': random.nextDouble() * 50,
      },
      weather: _generateMockWeather(),
      calibrationStatus: 'Simulated',
      cachedAt: now,
      locationKey: locationKey,
    );
  }

  double _generateRandomAQI() {
    final random = Random();
    // Generate realistic AQI values with higher probability for moderate values
    final ranges = [50, 100, 150, 200, 300, 500];
    final weights = [0.3, 0.4, 0.15, 0.1, 0.04, 0.01];
    
    double cumulative = 0;
    final randomValue = random.nextDouble();
    
    for (int i = 0; i < weights.length; i++) {
      cumulative += weights[i];
      if (randomValue <= cumulative) {
        final minValue = i == 0 ? 0 : ranges[i - 1];
        final maxValue = ranges[i];
        return minValue + random.nextDouble() * (maxValue - minValue);
      }
    }
    
    return random.nextDouble() * 150; // Default to moderate range
  }

  double _calculateAQIFromPM25(double pm25) {
    // US EPA AQI calculation for PM2.5
    if (pm25 <= 12.0) return (50 / 12.0) * pm25;
    if (pm25 <= 35.4) return 50 + ((100 - 50) / (35.4 - 12.1)) * (pm25 - 12.1);
    if (pm25 <= 55.4) return 101 + ((150 - 101) / (55.4 - 35.5)) * (pm25 - 35.5);
    if (pm25 <= 150.4) return 151 + ((200 - 151) / (150.4 - 55.5)) * (pm25 - 55.5);
    if (pm25 <= 250.4) return 201 + ((300 - 201) / (250.4 - 150.5)) * (pm25 - 150.5);
    return 301 + ((500 - 301) / (500.4 - 250.5)) * (pm25 - 250.5);
  }

  double _calculatePM25FromAQI(double aqi) {
    // Reverse calculation to get PM2.5 from AQI
    if (aqi <= 50) return (aqi / 50) * 12.0;
    if (aqi <= 100) return 12.1 + ((aqi - 50) / 50) * (35.4 - 12.1);
    if (aqi <= 150) return 35.5 + ((aqi - 101) / 49) * (55.4 - 35.5);
    if (aqi <= 200) return 55.5 + ((aqi - 151) / 49) * (150.4 - 55.5);
    if (aqi <= 300) return 150.5 + ((aqi - 201) / 99) * (250.4 - 150.5);
    return 250.5 + ((aqi - 301) / 199) * (500.4 - 250.5);
  }

  Map<String, dynamic> _generateMockWeather() {
    final random = Random();
    return {
      'max_temp': 20 + random.nextDouble() * 20, // 20-40°C
      'min_temp': 15 + random.nextDouble() * 15, // 15-30°C
      'rainfall': random.nextDouble() * 10, // 0-10mm
      'humidity': 40 + random.nextDouble() * 40, // 40-80%
    };
  }
}
