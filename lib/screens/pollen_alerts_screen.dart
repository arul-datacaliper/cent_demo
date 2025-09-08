import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PollenAlertPage extends StatefulWidget {
  const PollenAlertPage({Key? key}) : super(key: key);

  @override
  State<PollenAlertPage> createState() => _PollenAlertPageState();
}

class _PollenAlertPageState extends State<PollenAlertPage> {
  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic> _pollenData = {};
  DateTime? _lastUpdated;

  // Replace with your actual Google Pollen API key
  static const String _apiKey = 'AIzaSyD1IWIMTxQDLW-XIrOAfTidlo4iEezZb3Q';

  // Default location (San Francisco) - you can make this dynamic later
  final double _lat = 37.7749;
  final double _lng = -122.4194;

  // final double _lat = 35.4676;
  // final double _lng = -97.5164;

  @override
  void initState() {
    super.initState();
    print('🚀 PollenAlertPage initialized - starting API call');
    _fetchPollenData();
  }

  Future<void> _fetchPollenData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Build the URL in a way that preserves the colon in forecast:lookup
      final base = Uri.parse(
        'https://pollen.googleapis.com/v1/forecast:lookup',
      );
      final uri = base.replace(
        queryParameters: {
          'key': _apiKey,
          'location.latitude': _lat.toString(),
          'location.longitude': _lng.toString(),
          'days': '1',
          // 'languageCode': 'en',
          // 'plantsDescription': 'false',
        },
      );

      debugPrint('🌐 Requesting: $uri');

      final res = await http.get(uri);
      debugPrint('📡 Status: ${res.statusCode}');
      debugPrint('🔎 Final URL (after redirects): ${res.request?.url}');
      debugPrint('📄 Body: ${res.body}');

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        setState(() {
          _pollenData = data;
          _lastUpdated = DateTime.now();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'API ${res.statusCode}: ${res.body}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _tryQueryParamApiKey() async {
    try {
      final url =
          'https://pollen.googleapis.com/v1/forecast:lookup?key=$_apiKey';
      print('🔄 Retrying with query param: $url');

      final requestBody = {
        'location': {'longitude': _lng, 'latitude': _lat},
        'days': 1,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('🔄 Retry response status: ${response.statusCode}');
      print('🔄 Retry response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _pollenData = data;
          _lastUpdated = DateTime.now();
          _isLoading = false;
        });
        print('✅ Successfully fetched real pollen data with query param');
      } else {
        setState(() {
          _pollenData = _getMockData();
          _lastUpdated = DateTime.now();
          _isLoading = false;
          _error =
              'API Error (${response.statusCode}): Please check if Pollen API is enabled in Google Cloud Console. Using demo data.';
        });
      }
    } catch (e) {
      setState(() {
        _pollenData = _getMockData();
        _lastUpdated = DateTime.now();
        _isLoading = false;
        _error = 'API Error: $e - Using demo data';
      });
    }
  }

  Map<String, dynamic> _getMockData() {
    return {
      'dailyInfo': [
        {
          'date': {'year': 2025, 'month': 9, 'day': 4},
          'pollenTypeInfo': [
            {
              'code': 'GRASS',
              'displayName': 'Grass',
              'indexInfo': {
                'code': 'UPI',
                'displayName': 'Universal Pollen Index',
                'value': 3,
                'category': 'MODERATE',
                'indexDescription': 'Moderate pollen levels',
              },
            },
            {
              'code': 'TREE',
              'displayName': 'Tree',
              'indexInfo': {
                'code': 'UPI',
                'displayName': 'Universal Pollen Index',
                'value': 4,
                'category': 'HIGH',
                'indexDescription': 'High pollen levels',
              },
            },
            {
              'code': 'WEED',
              'displayName': 'Weed',
              'indexInfo': {
                'code': 'UPI',
                'displayName': 'Universal Pollen Index',
                'value': 2,
                'category': 'LOW',
                'indexDescription': 'Low pollen levels',
              },
            },
          ],
        },
      ],
    };
  }

  String _formatLastUpdated() {
    if (_lastUpdated == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(_lastUpdated!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${_lastUpdated!.day}/${_lastUpdated!.month}/${_lastUpdated!.year} at ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}';
    }
  }

  Color _getColorForCategory(String category) {
    switch (category.toUpperCase()) {
      case 'LOW':
      case 'VERY_LOW':
      case 'NONE':
        return Colors.lightGreen; // instead of grey
      case 'MODERATE':
        return Colors.orange;
      case 'HIGH':
        return Colors.redAccent;
      case 'VERY_HIGH':
        return Colors.purple;
      default:
        return Colors.blueGrey; // fallback still has a tint
    }
  }

  IconData _getIconForPollenType(String type) {
    switch (type.toUpperCase()) {
      case 'GRASS':
        return Icons.grass;
      case 'TREE':
        return Icons.park;
      case 'WEED':
        return Icons.eco;
      default:
        return Icons.nature;
    }
  }

  Widget _buildPollenCard(Map<String, dynamic> pollenInfo) {
    final code = pollenInfo['code'] ?? '';
    final displayName = pollenInfo['displayName'] ?? code;
    final indexInfo = pollenInfo['indexInfo'] ?? {};
    final value = indexInfo['value'] ?? 0;
    final category = indexInfo['category'] ?? 'UNKNOWN';
    final description = indexInfo['indexDescription'] ?? 'No data';

    final color = _getColorForCategory(category);
    final icon = _getIconForPollenType(code);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // changed from color.withOpacity(0.08) to white
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Level: $value',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildLevelIndicator(value, color),
        ],
      ),
    );
  }

  Widget _buildLevelIndicator(int value, Color color) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: value / 5.0, // Assuming max value is 5
              strokeWidth: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pollen Alert',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: _fetchPollenData,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'San Francisco, CA',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Today, ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
            style: const TextStyle(fontSize: 14, color: Colors.white60),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.white60),
              const SizedBox(width: 4),
              Text(
                'Last updated: ${_formatLastUpdated()}',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pollen Alert'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading pollen data...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  if (_error.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        border: Border.all(color: Colors.amber),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber[800]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error,
                              style: TextStyle(color: Colors.amber[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    'Current Pollen Levels',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_pollenData['dailyInfo'] != null)
                    ...(_pollenData['dailyInfo'][0]['pollenTypeInfo'] as List)
                        .map<Widget>(
                          (pollenInfo) => _buildPollenCard(pollenInfo),
                        )
                        .toList()
                  else
                    const Center(
                      child: Text(
                        'No pollen data available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _buildLegend(),
                ],
              ),
            ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pollen Level Guide',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildLegendItem(
            'Low (1-2)',
            Colors.green,
            'Minimal symptoms for most people',
          ),
          _buildLegendItem(
            'Moderate (3)',
            Colors.orange,
            'Some symptoms for sensitive people',
          ),
          _buildLegendItem('High (4)', Colors.red, 'Symptoms for most people'),
          _buildLegendItem(
            'Very High (5)',
            Colors.purple,
            'Severe symptoms for most people',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String level, Color color, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
