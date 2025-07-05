import 'package:geocoding/geocoding.dart';
import '../models/geocoding_data.dart';

class GeocodingService {
  /// Converts latitude and longitude into structured placemark data (city, state).
  Future<GeocodingData> getPlacemarkData(double lat, double lon) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final cityName = placemark.locality ?? placemark.subAdministrativeArea ?? 'Unknown City';
        final stateName = placemark.administrativeArea ?? 'Unknown State';
        return GeocodingData(cityName: cityName, stateName: stateName);
      }
      
      return GeocodingData(cityName: 'Unnamed Area', stateName: '');

    } catch (e) {
      // Don't use print in production code
      // debugPrint("Error in GeocodingService: $e");
      // In case of error, return a specific error object
      return GeocodingData(cityName: 'N/A', stateName: 'Could not determine location');
    }
  }
} 