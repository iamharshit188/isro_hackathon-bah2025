import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/enhanced_providers.dart';
import '../utils/aqi_utils.dart';
import '../widgets/aqi_gauge.dart';
import '../widgets/stats_card.dart';
import '../widgets/health_advisory_widget.dart';
import '../models/enhanced_aqi_data.dart';

class EnhancedHomeScreen extends ConsumerStatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  ConsumerState<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends ConsumerState<EnhancedHomeScreen> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final fusedDataAsync = ref.watch(enhancedFusedDataProvider);

    return Scaffold(
      body: fusedDataAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading air quality data...'),
            ],
          ),
        ),
        error: (err, stack) {
          debugPrintStack(stackTrace: stack, label: err.toString());
          return Center(
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
                    'Could not fetch AQI data',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection or try a different location.\n\nError: $err',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(enhancedFusedDataProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (data) {
          final aqiData = data['aqiData'] as EnhancedAqiData;
          final cityName = data['cityName'] as String;
          final cityImage = data['cityImage'];

          final aqiDetails = AqiUtils.getAqiDetails(
            aqiData.source,
            aqiData.aqi,
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(enhancedFusedDataProvider);
            },
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(context, aqiData, cityName, cityImage, aqiDetails),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAqiSection(context, aqiData, aqiDetails),
                        const SizedBox(height: 24),
                        _buildWeatherSection(context, aqiData),
                        const SizedBox(height: 24),
                        _buildMapSection(context, aqiData),
                        const SizedBox(height: 24),
                        _buildStatsGrid(aqiData),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    EnhancedAqiData aqiData,
    String cityName,
    dynamic cityImage,
    dynamic aqiDetails,
  ) {
    return SliverAppBar(
      expandedHeight: 250.0,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        title: Text(
          cityName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 24,
            shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (cityImage?.imageUrl != null)
              CachedNetworkImage(
                imageUrl: cityImage.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              )
            else
              Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    aqiDetails.category,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                    ),
                  ),
                  Text(
                    'Updated: ${aqiData.formattedTime}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(enhancedFusedDataProvider);
          },
        ),
      ],
    );
  }

  Widget _buildAqiSection(BuildContext context, EnhancedAqiData aqiData, dynamic aqiDetails) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overall Air Quality',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: AqiGauge(aqi: aqiData.aqi.toInt()),
        ),
        const SizedBox(height: 16),
        HealthAdvisoryWidget(
          text: aqiDetails.healthTip,
          backgroundColor: aqiDetails.color.withValues(alpha: 0.1),
          borderColor: aqiDetails.color,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.source, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Data Source: ${aqiData.source}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            if (aqiData.calibrationStatus != null) ...[
              const SizedBox(width: 16),
              Icon(Icons.tune, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                aqiData.calibrationStatus!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildWeatherSection(BuildContext context, EnhancedAqiData aqiData) {
    if (aqiData.weather == null) return const SizedBox.shrink();

    final weather = aqiData.weather!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weather Conditions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (weather['max_temp'] != null) ...[
              Icon(Icons.thermostat, color: Colors.orange[600]),
              const SizedBox(width: 8),
              Text('${weather['max_temp']}°C'),
              const SizedBox(width: 24),
            ],
            if (weather['rainfall'] != null) ...[
              Icon(Icons.water_drop, color: Colors.blue[600]),
              const SizedBox(width: 8),
              Text('${weather['rainfall']} mm'),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMapSection(BuildContext context, EnhancedAqiData aqiData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Map',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
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
                target: LatLng(aqiData.latitude, aqiData.longitude),
                zoom: 12,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('aqi_location'),
                  position: LatLng(aqiData.latitude, aqiData.longitude),
                  infoWindow: InfoWindow(
                    title: aqiData.city,
                    snippet: 'AQI: ${aqiData.aqi.toInt()}',
                  ),
                ),
              },
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(EnhancedAqiData aqiData) {
    final List<Widget> statCards = [];

    // Pollutants
    if (aqiData.pollutants != null) {
      final pollutants = aqiData.pollutants!;
      if (pollutants['pm25'] != null) {
        statCards.add(StatsCard(
          title: 'PM2.5',
          value: '${pollutants['pm25'].toStringAsFixed(2)} µg/m³',
        ));
      }
      if (pollutants['pm10'] != null) {
        statCards.add(StatsCard(
          title: 'PM10',
          value: '${pollutants['pm10'].toStringAsFixed(2)} µg/m³',
        ));
      }
    }

    // Weather data
    if (aqiData.weather != null) {
      final weather = aqiData.weather!;
      if (weather['max_temp'] != null) {
        statCards.add(StatsCard(
          title: 'Temperature',
          value: '${weather['max_temp']}°C',
        ));
      }
      if (weather['rainfall'] != null) {
        statCards.add(StatsCard(
          title: 'Rainfall',
          value: '${weather['rainfall']} mm',
        ));
      }
    }

    if (statCards.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: statCards,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
