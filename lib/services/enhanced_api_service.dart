import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/enhanced_aqi_data.dart';
import 'fallback_api_service.dart';

class EnhancedApiService {
  static EnhancedApiService? _instance;
  static EnhancedApiService get instance => _instance ??= EnhancedApiService._();
  
  late final Dio _dio;
  late final CacheOptions _cacheOptions;

  EnhancedApiService._() {
    _initializeDio();
  }

  Future<void> _initializeDio() async {
    _dio = Dio();

    // Configure base options
    _dio.options = BaseOptions(
      baseUrl: _getBaseUrl(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    // Initialize cache
    await _initializeCache();

    // Add logging interceptor for debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }

    // Add cache interceptor
    _dio.interceptors.add(DioCacheInterceptor(options: _cacheOptions));

    // Add retry interceptor for network failures
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError) {
          
          debugPrint('Network error, attempting retry...');
          
          // Retry once after a delay
          await Future.delayed(const Duration(seconds: 2));
          try {
            final response = await _dio.request(
              error.requestOptions.path,
              data: error.requestOptions.data,
              queryParameters: error.requestOptions.queryParameters,
              options: Options(
                method: error.requestOptions.method,
                headers: error.requestOptions.headers,
              ),
            );
            handler.resolve(response);
            return;
          } catch (retryError) {
            debugPrint('Retry failed: $retryError');
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<void> _initializeCache() async {
    Directory cacheDir;
    
    if (kIsWeb) {
      _cacheOptions = CacheOptions(
        store: MemCacheStore(),
        policy: CachePolicy.forceCache,
        hitCacheOnErrorExcept: [401, 403],
        maxStale: const Duration(hours: 1),
        priority: CachePriority.normal,
        cipher: null,
        keyBuilder: CacheOptions.defaultCacheKeyBuilder,
        allowPostMethod: false,
      );
    } else {
      cacheDir = await getTemporaryDirectory();
      final hiveCacheDir = Directory('${cacheDir.path}/dio_cache');
      
      _cacheOptions = CacheOptions(
        store: HiveCacheStore(hiveCacheDir.path),
        policy: CachePolicy.forceCache,
        hitCacheOnErrorExcept: [401, 403],
        maxStale: const Duration(hours: 1),
        priority: CachePriority.normal,
        cipher: null,
        keyBuilder: CacheOptions.defaultCacheKeyBuilder,
        allowPostMethod: false,
      );
    }
  }

  String _getBaseUrl() {
    if (kIsWeb) return 'http://localhost:3001';
    if (Platform.isAndroid) return 'http://10.0.2.2:3001';
    return 'http://localhost:3001';
  }

  Future<EnhancedAqiData> getRealtimeAqi(double lat, double lon, {bool forceRefresh = false}) async {
    try {
      debugPrint('🌐 Fetching AQI data for: $lat, $lon');
      
      final response = await _dio.get(
        '/api/v1/aqi/realtime',
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
        },
        options: Options(
          extra: {
            if (forceRefresh) 'dio_cache_force_refresh': true,
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('✅ Backend API Response received: ${data['source']} - AQI: ${data['aqi']}');
        
        return EnhancedAqiData.fromJson(data, lat, lon);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to load AQI data: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ Backend API failed: ${e.message}');
      
      // Use fallback service when backend fails
      return _useFallbackService(lat, lon, forceRefresh);
    } catch (e) {
      debugPrint('❌ Unexpected error with backend: $e');
      
      // Use fallback service for any unexpected errors
      return _useFallbackService(lat, lon, forceRefresh);
    }
  }

  Future<EnhancedAqiData> _useFallbackService(double lat, double lon, bool forceRefresh) async {
    try {
      debugPrint('🔄 Backend unavailable, using fallback service...');
      return await FallbackApiService.instance.getRealtimeAqi(lat, lon, forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('❌ Fallback service also failed: $e');
      throw Exception('Unable to fetch air quality data. Please check your internet connection and try again.');
    }
  }

  Future<List<EnhancedAqiData>> getMultipleLocationsAqi(List<Map<String, double>> locations) async {
    final List<Future<EnhancedAqiData?>> futures = locations.map((location) async {
      try {
        return await getRealtimeAqi(location['lat']!, location['lon']!);
      } catch (e) {
        debugPrint('Failed to get AQI for ${location['lat']}, ${location['lon']}: $e');
        return null;
      }
    }).toList();

    final results = await Future.wait(futures);
    return results.whereType<EnhancedAqiData>().toList();
  }

  void clearCache() {
    _cacheOptions.store?.clean();
    debugPrint('🗑️ Cache cleared');
  }

  void dispose() {
    _dio.close();
    _cacheOptions.store?.close();
  }
}
