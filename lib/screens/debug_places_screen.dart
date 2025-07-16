import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DebugPlacesScreen extends StatefulWidget {
  const DebugPlacesScreen({super.key});

  @override
  State<DebugPlacesScreen> createState() => _DebugPlacesScreenState();
}

class _DebugPlacesScreenState extends State<DebugPlacesScreen> {
  String? _apiKey;
  String? _testResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
  }

  Future<void> _testApiKey() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      setState(() {
        _testResult = 'API Key is not configured';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Delhi&key=$_apiKey'
      );
      
      final response = await http.get(url);
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        if (data['status'] == 'OK') {
          setState(() {
            _testResult = 'API Key is working! Found ${data['predictions'].length} suggestions for "Delhi"';
          });
        } else {
          setState(() {
            _testResult = 'API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}';
          });
        }
      } else {
        setState(() {
          _testResult = 'HTTP Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _testResult = 'Network Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Google Places API'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API Key Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _apiKey?.isNotEmpty == true
                    ? 'API Key loaded: ${_apiKey!.substring(0, 20)}...'
                    : 'API Key not found or empty',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _testApiKey,
              child: _isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Testing...'),
                      ],
                    )
                  : const Text('Test API Key'),
            ),
            const SizedBox(height: 20),
            if (_testResult != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testResult!.contains('working')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  border: Border.all(
                    color: _testResult!.contains('working')
                        ? Colors.green
                        : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testResult!.contains('working')
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Troubleshooting Tips:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Make sure your API key is in the .env file\n'
              '2. Restart your app after adding the API key\n'
              '3. Check that Places API is enabled in Google Cloud Console\n'
              '4. Verify billing is enabled for your Google Cloud project\n'
              '5. Check API key restrictions in Google Cloud Console',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
