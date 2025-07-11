import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// A service class for managing Google Maps-related functionality
class MapsService {
  /// Method channel for native communication
  static const MethodChannel _channel = MethodChannel('com.example.airQualityApp/maps');

  /// Initialize Google Maps with the API key from environment variables
  static Future<bool> initialize() async {
    try {
      // Get the API key from .env file
      final apiKey = dotenv.env['MAPS_API_KEY'] ?? 'AIzaSyBxLdoiWYjunuqTYTAU8ZeRYnFpzPwXCIQ';
      
      // On iOS, pass the API key to the native side
      if (apiKey.isNotEmpty) {
        final result = await _channel.invokeMethod<bool>(
          'getMapsApiKey',
          {'key': apiKey},
        );
        
        return result ?? false;
      }
      
      return false;
    } catch (e) {
      print('Failed to initialize Google Maps: $e');
      return false;
    }
  }
}
