import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // TODO: Add GoogleMapController and markers logic.
  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(20.5937, 78.9629), // Centered on India
    zoom: 4.0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AQI Map View'),
      ),
      body: const GoogleMap(
        initialCameraPosition: _kInitialPosition,
        // TODO: Add markers, map type controls, etc.
      ),
    );
  }
} 