import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../providers/fused_data_provider.dart';
import '../utils/aqi_utils.dart';
import '../widgets/aqi_gauge.dart';
import '../widgets/stats_card.dart';
import '../widgets/health_advisory_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fusedDataAsync = ref.watch(fusedDataNotifierProvider);

    return Scaffold(
      body: fusedDataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          debugPrintStack(stackTrace: stack, label: err.toString());
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Could not fetch AQI data. Please check your connection or try a different location.\n\nError: $err',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        data: (data) {
          final aqiDetails = AqiUtils.getAqiDetails(
              data.aqiData.source, data.aqiData.aqi.toDouble());
          final aqiValue = data.aqiData.aqi;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(fusedDataNotifierProvider.future),
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(context, data, aqiDetails),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Air Quality',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: AqiGauge(aqi: aqiValue),
                        ),
                        const SizedBox(height: 24),
                        HealthAdvisoryWidget(
                          text: aqiDetails.healthTip,
                          backgroundColor: aqiDetails.color.withValues(alpha: 0.1),
                          borderColor: aqiDetails.color,
                        ),
                        const SizedBox(height: 24),
                        _buildStatsGrid(data),
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

  SliverAppBar _buildSliverAppBar(BuildContext context, dynamic data, dynamic aqiDetails) {
    return SliverAppBar(
      expandedHeight: 250.0,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        title: Text(
          data.cityName,
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
            CachedNetworkImage(
              imageUrl: data.cityImage.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[300]),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
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
                    'Updated: ${DateFormat.jm().format(data.aqiData.recordedAt)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(dynamic data) {
    final weather = data.aqiData.weather;
    final pollutants = data.aqiData.pollutants;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        if (pollutants?['pm25'] != null)
          StatsCard(
            title: 'PM2.5',
            value: '${pollutants['pm25'].toStringAsFixed(2)} µg/m³',
          ),
        if (pollutants?['pm10'] != null)
          StatsCard(
            title: 'PM10',
            value: '${pollutants['pm10'].toStringAsFixed(2)} µg/m³',
          ),
        if (weather?['max_temp'] != null)
          StatsCard(
            title: 'Temperature',
            value: '${weather['max_temp']}°C',
          ),
        if (weather?['rainfall'] != null)
          StatsCard(
            title: 'Rainfall',
            value: '${weather['rainfall']} mm',
          ),
      ],
    );
  }
} 