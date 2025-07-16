import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/heatmap_service.dart';
import '../widgets/interactive_heatmap.dart';

class HeatmapScreen extends ConsumerWidget {
  const HeatmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Air Quality Heatmap'),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showHeatmapInfo(context),
          ),
        ],
      ),
      body: InteractiveHeatmapWidget(
        onPointTapped: (point) => _showPointDetails(context, point),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "heatmap_fab",
        onPressed: () => _showFilterOptions(context, ref),
        tooltip: 'Filter Options',
        child: const Icon(Icons.filter_alt),
      ),
    );
  }

  void _showPointDetails(BuildContext context, HeatmapPoint point) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _getAQIColor(point.aqiValue),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'AQI: ${point.aqiValue.toInt()}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Location', '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}'),
            _buildDetailRow('Data Source', point.source == 'cpcb_ground' ? 'Ground Station' : 'Satellite'),
            _buildDetailRow('Last Updated', point.timestamp.toIso8601String()),
            _buildDetailRow('Health Impact', _getHealthMessage(point.aqiValue)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _getAQIColor(double aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown; // Hazardous
  }

  String _getHealthMessage(double aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  void _showHeatmapInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Air Quality Heatmap'),
        content: const Text(
          'This heatmap shows real-time air quality data across India. '
          'Green areas indicate good air quality, while red and purple areas '
          'indicate unhealthy conditions. Data is collected from both ground '
          'stations and ISRO satellites to provide comprehensive coverage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions(BuildContext context, WidgetRef ref) {
    // Implementation for filtering options
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filter Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Ground Stations'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Satellite Data'),
              value: true,
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
