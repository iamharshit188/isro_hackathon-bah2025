import 'package:flutter_dotenv/flutter_dotenv.dart';

/// A service class for managing Google Maps-related functionality
class MapsService {
  /// Initialize Google Maps with the API key from environment variables
  static Future<bool> initialize() async {
    try {
      // Get the API key from .env file
      final apiKey = dotenv.env['MAPS_API_KEY'] ?? 'AIzaSyBxLdoiWYjunuqTYTAU8ZeRYnFpzPwXCIQ';
      
      // For now, just check if we have an API key
      // In a real app, you would configure this in the native iOS/Android code
      if (apiKey.isNotEmpty) {
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Get the current Google Maps API key
  static String getApiKey() {
    return dotenv.env['MAPS_API_KEY'] ?? 'AIzaSyBxLdoiWYjunuqTYTAU8ZeRYnFpzPwXCIQ';
  }
}
