import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/heatmap_service.dart';

final heatmapServiceProvider = Provider((ref) => HeatmapService());

final heatmapDataProvider = StateNotifierProvider<HeatmapNotifier, HeatmapState>(
  (ref) => HeatmapNotifier(ref.watch(heatmapServiceProvider)),
);

class HeatmapNotifier extends StateNotifier<HeatmapState> {
  final HeatmapService _heatmapService;

  HeatmapNotifier(this._heatmapService) : super(HeatmapState.loading());

  Future<void> loadHeatmapData({
    required LatLngBounds bounds,
    required double zoomLevel,
  }) async {
    state = HeatmapState.loading();

    try {
      final points = await _heatmapService.getHeatmapData(
        bounds: bounds,
        zoomLevel: zoomLevel,
      );

      // Convert to circle overlays for heatmap effect
      final circles = _createHeatmapCircles(points);

      state = HeatmapState.loaded(
        points: points,
        circles: circles,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = HeatmapState.error(e.toString());
    }
  }

  Set<Circle> _createHeatmapCircles(List<HeatmapPoint> points) {
    return points.map((point) {
      return Circle(
        circleId: CircleId('heatmap_${point.latitude}_${point.longitude}'),
        center: LatLng(point.latitude, point.longitude),
        radius: _calculateRadius(point.intensity),
        fillColor: _getAQIColor(point.aqiValue).withAlpha(77),
        strokeColor: _getAQIColor(point.aqiValue),
        strokeWidth: 2,
      );
    }).toSet();
  }

  double _calculateRadius(double intensity) {
    // Radius based on intensity and zoom level
    return 1000 * intensity; // Base radius in meters
  }

  Color _getAQIColor(double aqi) {
    // WHO AQI color standards
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown; // Hazardous
  }
}

class HeatmapState {
  final List<HeatmapPoint> points;
  final Set<Circle> circles;
  final DateTime? lastUpdated;
  final bool isLoading;
  final String? error;

  HeatmapState({
    required this.points,
    required this.circles,
    this.lastUpdated,
    this.isLoading = false,
    this.error,
  });

  factory HeatmapState.loading() => HeatmapState(
        points: [],
        circles: {},
        isLoading: true,
      );

  factory HeatmapState.loaded({
    required List<HeatmapPoint> points,
    required Set<Circle> circles,
    required DateTime lastUpdated,
  }) =>
      HeatmapState(
        points: points,
        circles: circles,
        lastUpdated: lastUpdated,
      );

  factory HeatmapState.error(String error) => HeatmapState(
        points: [],
        circles: {},
        error: error,
      );
}

