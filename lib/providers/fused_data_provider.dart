import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fused_data.dart';
import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../services/image_service.dart';
import 'location_provider.dart';

// Service Providers
final aqiServiceProvider = Provider((ref) => AqiService());
final geocodingServiceProvider = Provider((ref) => GeocodingService());
final imageServiceProvider = Provider((ref) => ImageService());

// The main data provider for the Home Screen
final fusedDataNotifierProvider =
    FutureProvider.autoDispose<FusedData>((ref) async {
  // Depend on the locationProvider to get lat/lon
  final locationState = ref.watch(locationProvider);
  final lat = locationState.latitude;
  final lon = locationState.longitude;

  // If we don't have a location yet, we can't proceed.
  if (lat == null || lon == null) {
    throw Exception('Location not available yet.');
  }

  // Fetch all data in parallel
  final aqiFuture = ref.watch(aqiServiceProvider).getRealtimeAqi(lat, lon);
  final geocodingFuture =
      ref.watch(geocodingServiceProvider).getPlacemarkData(lat, lon);

  // Await the results
  final aqiData = await aqiFuture;
  final geocodingData = await geocodingFuture;

  // Fetch the city image based on the city name
  final cityImage = await ref
      .watch(imageServiceProvider)
      .getCityImage(geocodingData.cityName);

  // Combine everything into a single FusedData object
  return FusedData(
    aqiData: aqiData,
    cityName: geocodingData.cityName,
    stateName: geocodingData.stateName,
    cityImage: cityImage,
  );
}); 