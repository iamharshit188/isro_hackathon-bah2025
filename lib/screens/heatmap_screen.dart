import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/enhanced_providers.dart';
import '../providers/location_provider.dart';
import '../models/enhanced_aqi_data.dart';
import '../utils/aqi_utils.dart';

class HeatmapScreen extends ConsumerStatefulWidget {
  const HeatmapScreen({super.key});

  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final heatmapDataAsync = ref.watch(heatmapDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AQI Heatmap'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(heatmapDataProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Legend
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AQI Scale',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem('Good', Colors.green, '0-50'),
                    _buildLegendItem('Moderate', Colors.yellow, '51-100'),
                    _buildLegendItem('Unhealthy', Colors.orange, '101-150'),
                    _buildLegendItem('Very Unhealthy', Colors.red, '151-200'),
                    _buildLegendItem('Hazardous', Colors.purple, '201+'),
                  ],
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: heatmapDataAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading heatmap data...'),
                  ],
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load heatmap data',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error: $err',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(heatmapDataProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (heatmapData) {
                _updateMarkers(heatmapData);
                
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: locationState.latitude != null && locationState.longitude != null
                            ? LatLng(locationState.latitude!, locationState.longitude!)
                            : const LatLng(28.6139, 77.2090), // Default to Delhi
                        zoom: 8,
                      ),
                      markers: _markers,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String range) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
        Text(
          range,
          style: TextStyle(fontSize: 8, color: Colors.grey[600]),
        ),
      ],
    );
  }

  void _updateMarkers(List<EnhancedAqiData> heatmapData) {
    final newMarkers = <Marker>{};

    for (int i = 0; i < heatmapData.length; i++) {
      final data = heatmapData[i];
      final aqiDetails = AqiUtils.getAqiDetails(data.source, data.aqi);

      newMarkers.add(
        Marker(
          markerId: MarkerId('aqi_marker_$i'),
          position: LatLng(data.latitude, data.longitude),
          infoWindow: InfoWindow(
            title: data.city,
            snippet: 'AQI: ${data.aqi.toInt()} (${aqiDetails.category})',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(data.aqi),
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  double _getMarkerHue(double aqi) {
    if (aqi <= 50) {
      return BitmapDescriptor.hueGreen;
    } else if (aqi <= 100) {
      return BitmapDescriptor.hueYellow;
    } else if (aqi <= 150) {
      return BitmapDescriptor.hueOrange;
    } else if (aqi <= 200) {
      return BitmapDescriptor.hueRed;
    } else {
      return BitmapDescriptor.hueViolet;
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
