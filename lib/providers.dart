import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'models/aqi_data.dart';
import 'models/city_image.dart';
import 'services/api_service.dart';
import 'services/geocoding_service.dart';
import 'services/image_service.dart';
import 'services/location_service.dart';

// 1. Simple Service Providers
// These expose the service instances themselves.

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
final apiServiceProvider = Provider<AqiService>((ref) => AqiService());
final geocodingServiceProvider = Provider<GeocodingService>((ref) => GeocodingService());
final imageServiceProvider = Provider<ImageService>((ref) => ImageService());


// 2. Data Provider Chains
// These providers depend on other providers to fetch data in a sequence.

// Provider to get the current device position
final positionProvider = FutureProvider<Position>((ref) {
  return ref.read(locationServiceProvider).getCurrentPosition();
});

// Combined provider that fetches AQI data based on the current position
final aqiDataProvider = FutureProvider<AqiData>((ref) async {
  // Wait for the positionProvider to complete
  final position = await ref.watch(positionProvider.future);
  // Then, use the coordinates to fetch AQI data
  return ref.read(apiServiceProvider).getRealtimeAqi(position.latitude, position.longitude);
});

// Combined provider that fetches City and Image data
final cityInfoProvider = FutureProvider<({String cityName, CityImage cityImage})>((ref) async {
  // Wait for the position
  final position = await ref.watch(positionProvider.future);
  
  // Get the city name from geocoding data
  final geocodingData = await ref.read(geocodingServiceProvider).getPlacemarkData(position.latitude, position.longitude);
  final cityName = geocodingData.cityName;
  
  // Get the city image
  final cityImage = await ref.read(imageServiceProvider).getCityImage(cityName);
  
  return (cityName: cityName, cityImage: cityImage);
});
