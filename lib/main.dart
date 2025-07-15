import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/maps_service.dart';
import 'services/cache_service.dart';
import 'screens/location_init_screen.dart';

Future<void> main() async {
  // Ensure widgets are initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the environment variables from the .env file
  await dotenv.load(fileName: ".env");
  
  // Initialize Google Maps with API key from .env
  try {
    final mapsInitialized = await MapsService.initialize();
    if (mapsInitialized) {
      debugPrint('✅ Google Maps initialized successfully');
    } else {
      debugPrint('⚠️ Google Maps initialization failed - maps may not work properly');
    }
  } catch (e) {
    debugPrint('❌ Failed to initialize Google Maps: $e');
    // Continue without maps if initialization fails
  }
  
  // Initialize cache service
  try {
    await CacheService.instance.initialize();
    debugPrint('✅ Cache service initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize cache service: $e');
    debugPrint('⚠️ The app will continue without caching functionality');
    // Continue without caching if initialization fails
  }
  
  runApp(
    const ProviderScope(
      child: AqiApp(),
    ),
  );
}

class AqiApp extends StatelessWidget {
  const AqiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bharat AQI',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const LocationInitScreen(),
    );
  }
} 