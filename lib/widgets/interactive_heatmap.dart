import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/heatmap_provider.dart';
import '../providers/location_provider.dart';
import '../services/heatmap_service.dart';

class InteractiveHeatmapWidget extends ConsumerStatefulWidget {
  final Function(HeatmapPoint)? onPointTapped;

  const InteractiveHeatmapWidget({
    super.key,
    this.onPointTapped,
  });

  @override
  ConsumerState<InteractiveHeatmapWidget> createState() => _InteractiveHeatmapWidgetState();
}

class _InteractiveHeatmapWidgetState extends ConsumerState<InteractiveHeatmapWidget> {
  GoogleMapController? _mapController;
  bool _isHeatmapVisible = true;

  @override
  Widget build(BuildContext context) {
    final heatmapState = ref.watch(heatmapDataProvider);
    final currentLocation = ref.watch(locationProvider);

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(currentLocation.latitude ?? 20.5937, currentLocation.longitude ?? 78.9629),
            zoom: 6.0,
          ),
          circles: _isHeatmapVisible ? heatmapState.circles : {},
          onCameraMove: (CameraPosition position) {
            _onCameraMove(position);
          },
          onTap: (LatLng position) {
            _onMapTap(position);
          },
          mapType: MapType.normal,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          padding: const EdgeInsets.only(bottom: 60),
        ),

        // Heatmap Controls
        Positioned(
          top: 16,
          right: 16,
          child: _buildHeatmapControls(),
        ),

        // Legend
        Positioned(
          bottom: 100,
          left: 16,
          child: _buildHeatmapLegend(),
        ),

        // Loading indicator
        if (heatmapState.isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildHeatmapControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isHeatmapVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _isHeatmapVisible = !_isHeatmapVisible;
              });
            },
            tooltip: _isHeatmapVisible ? 'Hide Heatmap' : 'Show Heatmap',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshHeatmap(),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'AQI Levels',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _buildLegendItem('Good (0-50)', Colors.green),
          _buildLegendItem('Moderate (51-100)', Colors.yellow),
          _buildLegendItem('Unhealthy for Sensitive (101-150)', Colors.orange),
          _buildLegendItem('Unhealthy (151-200)', Colors.red),
          _buildLegendItem('Very Unhealthy (201-300)', Colors.purple),
          _buildLegendItem('Hazardous (301+)', Colors.brown),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  void _onCameraMove(CameraPosition position) {
    // Throttle API calls during camera movement
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_mapController != null) {
        _refreshHeatmap();
      }
    });
  }

  void _onMapTap(LatLng position) {
    // Find nearest heatmap point
    final heatmapState = ref.read(heatmapDataProvider);
    if (heatmapState.points.isNotEmpty) {
      final nearestPoint = _findNearestPoint(position, heatmapState.points);
      if (nearestPoint != null && widget.onPointTapped != null) {
        widget.onPointTapped!(nearestPoint);
      }
    }
  }

  HeatmapPoint? _findNearestPoint(LatLng tappedPosition, List<HeatmapPoint> points) {
    double minDistance = double.infinity;
    HeatmapPoint? nearestPoint;

    for (final point in points) {
      final distance = _calculateDistance(
        tappedPosition.latitude,
        tappedPosition.longitude,
        point.latitude,
        point.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = point;
      }
    }

    return nearestPoint;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  Future<void> _refreshHeatmap() async {
    if (_mapController == null) return;

    final bounds = await _mapController!.getVisibleRegion();
    final zoomLevel = await _mapController!.getZoomLevel();

    ref.read(heatmapDataProvider.notifier).loadHeatmapData(
          bounds: bounds,
          zoomLevel: zoomLevel,
        );
  }
}

