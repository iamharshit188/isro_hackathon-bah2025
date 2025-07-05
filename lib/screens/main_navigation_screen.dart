import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'enhanced_home_screen.dart';
import 'heatmap_screen.dart';
import 'profile_screen.dart';
import '../providers/location_provider.dart';

final currentIndexProvider = StateNotifierProvider<CurrentIndexNotifier, int>((ref) {
  return CurrentIndexNotifier();
});

class CurrentIndexNotifier extends StateNotifier<int> {
  CurrentIndexNotifier() : super(0);

  void setIndex(int index) {
    state = index;
  }
}

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  static final List<Widget> _screens = [
    const EnhancedHomeScreen(),
    const HeatmapScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showLocationOptions(context, ref),
              child: const Icon(Icons.add_location_alt),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context,
                  ref,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  index: 0,
                  isActive: currentIndex == 0,
                ),
                _buildNavItem(
                  context,
                  ref,
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  label: 'Heatmap',
                  index: 1,
                  isActive: currentIndex == 1,
                ),
                _buildNavItem(
                  context,
                  ref,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  index: 2,
                  isActive: currentIndex == 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => ref.read(currentIndexProvider.notifier).setIndex(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? colorScheme.primary : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? colorScheme.primary : Colors.grey[600],
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationOptions(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Options'),
        content: const Text('Choose how to set your location:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _getCurrentLocation(context, ref);
            },
            child: const Text('Use Current Location'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showManualLocationDialog(context, ref);
            },
            child: const Text('Enter Manually'),
          ),
        ],
      ),
    );
  }

  void _getCurrentLocation(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(locationProvider.notifier).determinePosition();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }

  void _showManualLocationDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController latController = TextEditingController();
    final TextEditingController lonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Location Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g., 28.6139',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lonController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g., 77.2090',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Text(
              'You can find your coordinates by searching "my coordinates" in Google.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final lat = double.tryParse(latController.text);
              final lon = double.tryParse(lonController.text);
              
              if (lat != null && lon != null && 
                  lat >= -90 && lat <= 90 && 
                  lon >= -180 && lon <= 180) {
                Navigator.of(context).pop();
                
                await ref.read(locationProvider.notifier).setManualLocation(lat, lon);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location set successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid coordinates'),
                  ),
                );
              }
            },
            child: const Text('Set Location'),
          ),
        ],
      ),
    );
  }
}
