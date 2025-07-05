import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';
import '../screens/home_screen.dart';

class ManualLocationScreen extends ConsumerStatefulWidget {
  const ManualLocationScreen({super.key});

  @override
  ConsumerState<ManualLocationScreen> createState() => _ManualLocationScreenState();
}

class _ManualLocationScreenState extends ConsumerState<ManualLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  bool _isLoading = false;

  String? _validateCoordinate(String? value, bool isLatitude) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    try {
      final double coord = double.parse(value);
      if (isLatitude && (coord < -90 || coord > 90)) {
        return 'Latitude must be between -90 and 90';
      }
      if (!isLatitude && (coord < -180 || coord > 180)) {
        return 'Longitude must be between -180 and 180';
      }
      return null;
    } catch (e) {
      return 'Please enter a valid number';
    }
  }

  Future<void> _submitLocation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final lat = double.parse(_latController.text);
      final lon = double.parse(_lonController.text);
      
      // Update the location in the provider
      await ref.read(locationProvider.notifier).setManualLocation(lat, lon);

      if (!mounted) return;
      
      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Location'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'Enter latitude (e.g., 28.6139)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => _validateCoordinate(value, true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lonController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'Enter longitude (e.g., 77.2090)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => _validateCoordinate(value, false),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitLocation,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Get AQI Data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 