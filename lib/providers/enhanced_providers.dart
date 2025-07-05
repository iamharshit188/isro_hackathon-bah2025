import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/enhanced_aqi_data.dart';
import '../services/enhanced_api_service.dart';
import '../services/cache_service.dart';
import '../services/geocoding_service.dart';
import '../services/image_service.dart';
import 'location_provider.dart';

// Service Providers
final enhancedApiServiceProvider = Provider<EnhancedApiService>((ref) {
  return EnhancedApiService.instance;
});

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService.instance;
});

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService();
});

final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageService();
});

// Enhanced AQI Data Provider with Caching
final enhancedAqiDataProvider = FutureProvider.family<EnhancedAqiData, Map<String, dynamic>>((ref, params) async {
  final lat = params['lat'] as double;
  final lon = params['lon'] as double;
  final forceRefresh = params['forceRefresh'] as bool? ?? false;

  final apiService = ref.read(enhancedApiServiceProvider);
  final cacheService = ref.read(cacheServiceProvider);

  // Try cache first if not forcing refresh
  if (!forceRefresh) {
    final cachedData = cacheService.getCachedAqiData(lat, lon);
    if (cachedData != null) {
      debugPrint('📱 Using cached data for ${cachedData.city}');
      return cachedData;
    }
  }

  // Fetch from API
  debugPrint('🌐 Fetching fresh data from API');
  final freshData = await apiService.getRealtimeAqi(lat, lon, forceRefresh: forceRefresh);
  
  // Cache the fresh data
  await cacheService.cacheAqiData(freshData);
  
  return freshData;
});

// Main Fused Data Provider
final enhancedFusedDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final locationState = ref.watch(locationProvider);
  final lat = locationState.latitude;
  final lon = locationState.longitude;

  // Auto-initialize location if not available and not already loading
  if (lat == null || lon == null) {
    if (!locationState.isLoading && locationState.error == null) {
      // Try to get location automatically
      ref.read(locationProvider.notifier).determinePosition();
    }
    
    if (locationState.isLoading) {
      throw Exception('Getting your location...');
    } else if (locationState.error != null) {
      throw Exception('Location error: ${locationState.error}');
    } else {
      throw Exception('Location not available. Please enable location services or enter your location manually.');
    }
  }

  // Fetch AQI data
  final aqiData = await ref.watch(enhancedAqiDataProvider({
    'lat': lat,
    'lon': lon,
    'forceRefresh': false,
  }).future);

  // Fetch geocoding data
  final geocodingService = ref.read(geocodingServiceProvider);
  final geocodingData = await geocodingService.getPlacemarkData(lat, lon);

  // Fetch city image
  final imageService = ref.read(imageServiceProvider);
  final cityImage = await imageService.getCityImage(geocodingData.cityName);

  // Add to history
  final cacheService = ref.read(cacheServiceProvider);
  await cacheService.addToHistory(aqiData, '${geocodingData.cityName}, ${geocodingData.stateName}');

  return {
    'aqiData': aqiData,
    'cityName': geocodingData.cityName,
    'stateName': geocodingData.stateName,
    'cityImage': cityImage,
  };
});

// History Provider
final historyProvider = StateNotifierProvider<HistoryNotifier, List<AqiHistoryEntry>>((ref) {
  return HistoryNotifier(ref.read(cacheServiceProvider));
});

class HistoryNotifier extends StateNotifier<List<AqiHistoryEntry>> {
  final CacheService _cacheService;

  HistoryNotifier(this._cacheService) : super([]) {
    _loadHistory();
  }

  void _loadHistory() {
    state = _cacheService.getHistory();
  }

  void refresh() {
    _loadHistory();
  }

  Future<void> toggleFavorite(String historyEntryId) async {
    await _cacheService.toggleFavorite(historyEntryId);
    _loadHistory(); // Refresh state
  }

  Future<void> deleteEntry(String historyEntryId) async {
    await _cacheService.deleteHistoryEntry(historyEntryId);
    _loadHistory(); // Refresh state
  }

  Future<void> clearHistory() async {
    await _cacheService.clearHistory();
    state = [];
  }

  bool isFavorite(String historyEntryId) {
    return _cacheService.isFavorite(historyEntryId);
  }
}

// Favorites Provider
final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<AqiHistoryEntry>>((ref) {
  return FavoritesNotifier(ref.read(cacheServiceProvider));
});

class FavoritesNotifier extends StateNotifier<List<AqiHistoryEntry>> {
  final CacheService _cacheService;

  FavoritesNotifier(this._cacheService) : super([]) {
    _loadFavorites();
  }

  void _loadFavorites() {
    state = _cacheService.getFavorites();
  }

  void refresh() {
    _loadFavorites();
  }
}

// Recent Searches Provider
final recentSearchesProvider = StateNotifierProvider<RecentSearchesNotifier, List<AqiHistoryEntry>>((ref) {
  return RecentSearchesNotifier(ref.read(cacheServiceProvider));
});

class RecentSearchesNotifier extends StateNotifier<List<AqiHistoryEntry>> {
  final CacheService _cacheService;

  RecentSearchesNotifier(this._cacheService) : super([]) {
    _loadRecentSearches();
  }

  void _loadRecentSearches() {
    state = _cacheService.getRecentSearches();
  }

  void refresh() {
    _loadRecentSearches();
  }
}

// Analytics Provider
final analyticsProvider = Provider<Map<String, dynamic>>((ref) {
  final cacheService = ref.read(cacheServiceProvider);
  final cityVisitCount = cacheService.getCityVisitCount();
  final cacheStats = cacheService.getCacheStats();
  
  return {
    'city_visit_count': cityVisitCount,
    'cache_stats': cacheStats,
    'most_visited_cities': _getMostVisitedCities(cityVisitCount),
  };
});

List<Map<String, dynamic>> _getMostVisitedCities(Map<String, int> cityVisitCount) {
  final sortedCities = cityVisitCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  return sortedCities.take(5).map((entry) => {
    'city': entry.key,
    'visit_count': entry.value,
  }).toList();
}

// Heatmap Data Provider
final heatmapDataProvider = FutureProvider<List<EnhancedAqiData>>((ref) async {
  final cacheService = ref.read(cacheServiceProvider);
  return cacheService.getAllCachedAqiData();
});

// Force Refresh Provider
final forceRefreshProvider = StateNotifierProvider<ForceRefreshNotifier, bool>((ref) {
  return ForceRefreshNotifier();
});

class ForceRefreshNotifier extends StateNotifier<bool> {
  ForceRefreshNotifier() : super(false);

  void toggleRefresh() {
    state = !state;
  }

  void setRefresh(bool value) {
    state = value;
  }
}
