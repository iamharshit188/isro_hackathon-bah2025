import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:google_maps_webservice/places.dart';
import 'dart:developer' as developer;

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Location'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                GooglePlacesAutoCompleteTextFormField(
                  textEditingController: _controller,
                  googleAPIKey: dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '',
                  debounceTime: 400,
                  countries: const ['in'],
                  onSuggestionClicked: (prediction) {
                    _controller.text = prediction.description ?? '';
                    _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: prediction.description?.length ?? 0));
                  },
                  onPlaceDetailsWithCoordinatesReceived: (prediction) {
                    if (prediction.lat != null && prediction.lng != null) {
                      final result = {
                        'name': prediction.description,
                        'latitude': double.tryParse(prediction.lat ?? '0'),
                        'longitude': double.tryParse(prediction.lng ?? '0'),
                      };
                      Navigator.pop(context, result);
                    }
                  },
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(77),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

