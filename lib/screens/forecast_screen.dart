import 'package:flutter/material.dart';

class ForecastScreen extends StatelessWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AQI Forecast'),
      ),
      body: const Center(
        child: Text('Forecast screen with graphs will be shown here.'),
        // TODO: Implement the forecast UI with charts.
      ),
    );
  }
} 