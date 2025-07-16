import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'manual_location_screen.dart'; // Replaced location_search_screen.dart
import '../providers/location_provider.dart';
import 'main_navigation_screen.dart';

class LocationInitScreen extends ConsumerStatefulWidget {
  const LocationInitScreen({super.key});

  @override
  ConsumerState<LocationInitScreen> createState() => _LocationInitScreenState();
}

class _LocationInitScreenState extends ConsumerState<LocationInitScreen> {
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    // No automatic location initialization - let user choose
  }

  Future<void> _initializeLocation() async {
    if (_isInitializing) return;
    
    setState(() {
      _isInitializing = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      // Check for permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionPermanentlyDeniedDialog();
        return;
      }

      // Get location
      await ref.read(locationProvider.notifier).determinePosition();
      
      // Check if location was successfully obtained
      final locationState = ref.read(locationProvider);
      if (locationState.latitude != null && locationState.longitude != null) {
        // Navigate to main app
        if (mounted) {
          final navigator = Navigator.of(context);
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainNavigationScreen(),
            ),
          );
        }
      } else {
        _showLocationErrorDialog(locationState.error ?? 'Failed to get location');
      }
    } catch (e) {
      debugPrint('Location initialization error: $e');
      _showLocationErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: Icon(
                    Icons.air,
                    size: 60,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // App Title
                Text(
                  'Bharat AQI',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Air Quality Monitoring',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Status and Loading
                if (locationState.isLoading || _isInitializing) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Getting your location...',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This helps us show you accurate air quality data for your area.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else if (locationState.error != null) ...[
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Location Error',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    locationState.error!,
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _initializeLocation,
                    child: const Text('Try Again'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _showManualLocationDialog,
                    child: const Text('Enter Location Manually'),
                  ),
                ] else ...[
                  Icon(
                    Icons.location_on,
                    size: 64,
                    color: Colors.green[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose Location Method',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select how you\'d like to set your location for accurate air quality data.',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _initializeLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use My Current Location'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showManualLocationDialog,
                      icon: const Icon(Icons.edit_location),
                      label: const Text('Enter Location Manually'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Location services are disabled. Please enable them in your device settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showManualLocationDialog();
            },
            child: const Text('Enter Manually'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Geolocator.openLocationSettings();
              // Wait a bit for user to potentially enable location
              await Future.delayed(const Duration(seconds: 2));
              _initializeLocation();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'We need location permission to show you air quality data for your area. Please grant permission and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showManualLocationDialog();
            },
            child: const Text('Enter Manually'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeLocation();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Denied'),
        content: const Text(
          'Location permissions are permanently denied. Please enable them in your device settings or enter your location manually.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showManualLocationDialog();
            },
            child: const Text('Enter Manually'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showManualLocationDialog();
            },
            child: const Text('Enter Manually'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeLocation();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showManualLocationDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManualLocationScreen(),
      ),
    );
  }
}
