import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationState {
  final double? latitude;
  final double? longitude;
  final String? error;
  final bool isLoading;
  final bool isManualLocation;

  LocationState({
    this.latitude,
    this.longitude,
    this.error,
    this.isLoading = false,
    this.isManualLocation = false,
  });

  LocationState copyWith({
    double? latitude,
    double? longitude,
    String? error,
    bool? isLoading,
    bool? isManualLocation,
  }) {
    return LocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      isManualLocation: isManualLocation ?? this.isManualLocation,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(LocationState());

  Future<void> determinePosition() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          error: 'Location services are disabled',
          isLoading: false,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            error: 'Location permissions are denied',
            isLoading: false,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          error: 'Location permissions are permanently denied',
          isLoading: false,
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      debugPrint('📍 Got location: ${position.latitude}, ${position.longitude}');
      
      state = state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        isLoading: false,
        isManualLocation: false,
      );
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      state = state.copyWith(
        error: 'Failed to get location: $e',
        isLoading: false,
      );
    }
  }

  Future<void> setManualLocation(double lat, double lon) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      debugPrint('📍 Setting manual location: $lat, $lon');
      state = state.copyWith(
        latitude: lat,
        longitude: lon,
        isLoading: false,
        isManualLocation: true,
      );
    } catch (e) {
      debugPrint('❌ Error setting manual location: $e');
      state = state.copyWith(
        error: 'Failed to set location: $e',
        isLoading: false,
      );
    }
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
); 