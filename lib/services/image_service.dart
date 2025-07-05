import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/city_image.dart';

class ImageService {
  // Read the API key from the environment variables
  final String? _apiKey = dotenv.env['PEXELS_API_KEY'];
  final String _baseUrl = "https://api.pexels.com/v1/search";

  Future<CityImage> getCityImage(String cityName) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return _getDefaultImage(cityName);
    }

    // Simple approach: search directly by city name (most effective)
    final uri = Uri.parse('$_baseUrl?query=$cityName&per_page=1');
    
    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': _apiKey!},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final photos = data['photos'] as List;
        
        if (photos.isNotEmpty) {
          return CityImage.fromJson(data);
        }
      }
    } catch (e) {
      // Silently fall back to default image on any error
    }
    
    return _getDefaultImage(cityName);
  }

  CityImage _getDefaultImage(String cityName) {
    // Region-specific default images based on city characteristics
    final defaultImages = [
      const CityImage(
        imageUrl: 'https://images.pexels.com/photos/1007657/pexels-photo-1007657.jpeg', // Delhi India Gate
        photographerName: 'Ganesh Jhunjhunwala'
      ),
      const CityImage(
        imageUrl: 'https://images.pexels.com/photos/789750/pexels-photo-789750.jpeg', // Mumbai marine drive
        photographerName: 'Pixabay'
      ),
      const CityImage(
        imageUrl: 'https://images.pexels.com/photos/1534394/pexels-photo-1534394.jpeg', // Traditional Indian architecture
        photographerName: 'Abhishek Gaurav'
      ),
      const CityImage(
        imageUrl: 'https://images.pexels.com/photos/2889728/pexels-photo-2889728.jpeg', // Hawa Mahal Jaipur
        photographerName: 'Suraphat Nuea-on'
      ),
      const CityImage(
        imageUrl: 'https://images.pexels.com/photos/1098460/pexels-photo-1098460.jpeg', // South Indian temple architecture
        photographerName: 'Suraphat Nuea-on'
      ),
      const CityImage(
        imageUrl: 'https://images.pexels.com/photos/1591447/pexels-photo-1591447.jpeg', // Indian riverside city
        photographerName: 'Naveen Annam'
      ),
      const CityImage(
        imageUrl: 'https://images.pexels.com/photos/161963/city-skyline-skyscraper-tower-161963.jpeg', // Modern IT city
        photographerName: 'Pixabay'
      ),
      const CityImage(
        imageUrl: 'https://images.pexels.com/photos/1105766/pexels-photo-1105766.jpeg', // Coastal Indian city
        photographerName: 'Aleksandar Pasaric'
      ),
    ];
    
    // Use city name hash to consistently select the same image for the same city
    final index = cityName.hashCode.abs() % defaultImages.length;
    return defaultImages[index];
  }
}
