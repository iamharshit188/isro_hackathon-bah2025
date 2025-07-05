import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/enhanced_aqi_data.dart';

class CacheService {
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();

  late Box<EnhancedAqiData> _aqiCacheBox;
  late Box<AqiHistoryEntry> _historyBox;
  late Box<String> _favoritesBox;

  static const String aqiCacheBoxName = 'aqi_cache';
  static const String historyBoxName = 'aqi_history';
  static const String favoritesBoxName = 'favorites';

  CacheService._();

  Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      
      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(EnhancedAqiDataAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(AqiHistoryEntryAdapter());
      }

      // Open boxes
      _aqiCacheBox = await Hive.openBox<EnhancedAqiData>(aqiCacheBoxName);
      _historyBox = await Hive.openBox<AqiHistoryEntry>(historyBoxName);
      _favoritesBox = await Hive.openBox<String>(favoritesBoxName);

      debugPrint('✅ Cache service initialized');
      
      // Clean up old data on startup
      await _cleanupOldData();
      
    } catch (e) {
      debugPrint('❌ Failed to initialize cache service: $e');
      rethrow;
    }
  }

  // AQI Data Caching
  Future<void> cacheAqiData(EnhancedAqiData data) async {
    try {
      await _aqiCacheBox.put(data.locationKey, data);
      debugPrint('💾 Cached AQI data for ${data.city}');
    } catch (e) {
      debugPrint('❌ Failed to cache AQI data: $e');
    }
  }

  EnhancedAqiData? getCachedAqiData(double lat, double lon) {
    try {
      final locationKey = '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
      final cachedData = _aqiCacheBox.get(locationKey);
      
      if (cachedData != null && !cachedData.isStale) {
        debugPrint('📱 Using cached AQI data for ${cachedData.city}');
        return cachedData;
      } else if (cachedData != null && cachedData.isStale) {
        debugPrint('⏰ Cached data is stale for ${cachedData.city}');
        _aqiCacheBox.delete(locationKey); // Remove stale data
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get cached AQI data: $e');
      return null;
    }
  }

  List<EnhancedAqiData> getAllCachedAqiData() {
    try {
      final allData = _aqiCacheBox.values.toList();
      // Filter out stale data
      return allData.where((data) => !data.isStale).toList();
    } catch (e) {
      debugPrint('❌ Failed to get all cached AQI data: $e');
      return [];
    }
  }

  // History Management
  Future<void> addToHistory(EnhancedAqiData aqiData, String searchLocation) async {
    try {
      final id = '${aqiData.locationKey}_${DateTime.now().millisecondsSinceEpoch}';
      final historyEntry = AqiHistoryEntry(
        id: id,
        aqiData: aqiData,
        searchLocation: searchLocation,
        timestamp: DateTime.now(),
      );

      await _historyBox.put(id, historyEntry);
      debugPrint('📝 Added to history: $searchLocation');

      // Keep only last 100 entries
      await _limitHistorySize();
    } catch (e) {
      debugPrint('❌ Failed to add to history: $e');
    }
  }

  List<AqiHistoryEntry> getHistory({int limit = 50}) {
    try {
      final allHistory = _historyBox.values.toList();
      allHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return allHistory.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Failed to get history: $e');
      return [];
    }
  }

  List<AqiHistoryEntry> getFavorites() {
    try {
      final favoriteIds = _favoritesBox.values.toSet();
      final allHistory = _historyBox.values.toList();
      return allHistory.where((entry) => favoriteIds.contains(entry.id)).toList();
    } catch (e) {
      debugPrint('❌ Failed to get favorites: $e');
      return [];
    }
  }

  Future<void> toggleFavorite(String historyEntryId) async {
    try {
      if (_favoritesBox.values.contains(historyEntryId)) {
        // Remove from favorites
        final keyToDelete = _favoritesBox.keys.firstWhere(
          (key) => _favoritesBox.get(key) == historyEntryId,
        );
        await _favoritesBox.delete(keyToDelete);
        debugPrint('❤️ Removed from favorites: $historyEntryId');
      } else {
        // Add to favorites
        await _favoritesBox.add(historyEntryId);
        debugPrint('💖 Added to favorites: $historyEntryId');
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle favorite: $e');
    }
  }

  bool isFavorite(String historyEntryId) {
    return _favoritesBox.values.contains(historyEntryId);
  }

  Future<void> clearHistory() async {
    try {
      await _historyBox.clear();
      await _favoritesBox.clear();
      debugPrint('🗑️ History cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear history: $e');
    }
  }

  Future<void> deleteHistoryEntry(String id) async {
    try {
      await _historyBox.delete(id);
      
      // Also remove from favorites if it exists
      final favoriteKey = _favoritesBox.keys.firstWhere(
        (key) => _favoritesBox.get(key) == id,
        orElse: () => null,
      );
      if (favoriteKey != null) {
        await _favoritesBox.delete(favoriteKey);
      }
      
      debugPrint('🗑️ Deleted history entry: $id');
    } catch (e) {
      debugPrint('❌ Failed to delete history entry: $e');
    }
  }

  // Analytics & Insights
  Map<String, int> getCityVisitCount() {
    try {
      final allHistory = _historyBox.values.toList();
      final cityCount = <String, int>{};
      
      for (final entry in allHistory) {
        final city = entry.aqiData.city;
        cityCount[city] = (cityCount[city] ?? 0) + 1;
      }
      
      return cityCount;
    } catch (e) {
      debugPrint('❌ Failed to get city visit count: $e');
      return {};
    }
  }

  List<AqiHistoryEntry> getRecentSearches({int limit = 10}) {
    try {
      final recentEntries = getHistory(limit: limit);
      final uniqueLocations = <String, AqiHistoryEntry>{};
      
      for (final entry in recentEntries) {
        final key = entry.aqiData.locationKey;
        if (!uniqueLocations.containsKey(key)) {
          uniqueLocations[key] = entry;
        }
      }
      
      return uniqueLocations.values.toList();
    } catch (e) {
      debugPrint('❌ Failed to get recent searches: $e');
      return [];
    }
  }

  // Maintenance
  Future<void> _limitHistorySize() async {
    try {
      const maxHistorySize = 100;
      if (_historyBox.length > maxHistorySize) {
        final allHistory = _historyBox.values.toList();
        allHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        final entriesToDelete = allHistory.take(_historyBox.length - maxHistorySize);
        for (final entry in entriesToDelete) {
          await _historyBox.delete(entry.id);
        }
        
        debugPrint('🧹 Trimmed history to $maxHistorySize entries');
      }
    } catch (e) {
      debugPrint('❌ Failed to limit history size: $e');
    }
  }

  Future<void> _cleanupOldData() async {
    try {
      // Remove AQI data older than 24 hours
      final staleKeys = <String>[];
      for (final key in _aqiCacheBox.keys) {
        final data = _aqiCacheBox.get(key);
        if (data != null && data.isStale) {
          staleKeys.add(key);
        }
      }
      
      for (final key in staleKeys) {
        await _aqiCacheBox.delete(key);
      }
      
      if (staleKeys.isNotEmpty) {
        debugPrint('🧹 Cleaned up ${staleKeys.length} stale cache entries');
      }
      
      // Remove history older than 30 days
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final oldHistoryKeys = <String>[];
      
      for (final key in _historyBox.keys) {
        final entry = _historyBox.get(key);
        if (entry != null && entry.timestamp.isBefore(cutoffDate)) {
          oldHistoryKeys.add(key);
        }
      }
      
      for (final key in oldHistoryKeys) {
        await _historyBox.delete(key);
      }
      
      if (oldHistoryKeys.isNotEmpty) {
        debugPrint('🧹 Cleaned up ${oldHistoryKeys.length} old history entries');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to cleanup old data: $e');
    }
  }

  Future<void> clearAllCache() async {
    try {
      await _aqiCacheBox.clear();
      await _historyBox.clear();
      await _favoritesBox.clear();
      debugPrint('🗑️ All cache cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear all cache: $e');
    }
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_aqi_count': _aqiCacheBox.length,
      'history_count': _historyBox.length,
      'favorites_count': _favoritesBox.length,
      'total_cache_size': _aqiCacheBox.length + _historyBox.length + _favoritesBox.length,
    };
  }

  Future<void> dispose() async {
    try {
      await _aqiCacheBox.close();
      await _historyBox.close();
      await _favoritesBox.close();
      debugPrint('📦 Cache service disposed');
    } catch (e) {
      debugPrint('❌ Failed to dispose cache service: $e');
    }
  }
}
