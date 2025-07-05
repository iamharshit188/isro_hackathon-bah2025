import 'package:flutter/material.dart';

class HealthTipsScreen extends StatelessWidget {
  const HealthTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Recommendations'),
      ),
      body: const Center(
        child: Text('Personalized health tips will be listed here.'),
        // TODO: Implement a list of health tips based on AQI levels.
      ),
    );
  }
} 