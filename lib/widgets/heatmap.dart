import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CustomHeatmap extends StatelessWidget {
  final Set<Circle> circles;
  final CameraPosition initialCameraPosition;
  final Function(GoogleMapController) onMapCreated;

  const CustomHeatmap({
    super.key,
    required this.circles,
    required this.initialCameraPosition,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      circles: circles,
      initialCameraPosition: initialCameraPosition,
      onMapCreated: onMapCreated,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}

