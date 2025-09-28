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
  Map<String, dynamic> _airQualityData = {};
  DateTime? _lastUpdated;
  String? _selectedTreatment;

  // Replace with your actual Google API key
  static const String _apiKey = 'AIzaSyD1IWIMTxQDLW-XIrOAfTidlo4iEezZb3Q';

  // Default location (San Francisco) - you can make this dynamic later
  // final double _lat = 37.7749;
  // final double _lng = -122.4194;
//Location changed to Oklahoma City for testing
  final double _lat = 35.4676;
  final double _lng = -97.5164;

  // Treatment types for immunotherapy patients
  final List<String> _treatmentTypes = [
    'Select Treatment Type',
    'Grass Pollen Immunotherapy',
    'Tree Pollen Immunotherapy', 
    'Ragweed Immunotherapy',
    'Dust Mite Immunotherapy',
    'Pet Dander Immunotherapy',
    'Mold Immunotherapy',
    'Multiple Allergen Therapy',
  ];

  @override
  void initState() {
    super.initState();
    print('🚀 Environmental Data Page initialized - starting API calls');
    _selectedTreatment = _treatmentTypes.first;
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Fetch pollen data first (required)
      await _fetchPollenData();
      
      // Try to fetch air quality data, but don't fail if it's not available
      try {
        await _fetchAirQualityData();
      } catch (aqiError) {
        print('⚠️ Air Quality API not available: $aqiError');
        // Set empty air quality data but continue with pollen data
        _airQualityData = {};
      }

      setState(() {
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error fetching pollen data: $e';
      });
    }
  }

  Future<void> _fetchPollenData() async {
    try {
      final base = Uri.parse('https://pollen.googleapis.com/v1/forecast:lookup');
      final uri = base.replace(
        queryParameters: {
          'key': _apiKey,
          'location.latitude': _lat.toString(),
          'location.longitude': _lng.toString(),
          'days': '1',
        },
      );

      final res = await http.get(uri);
      
      if (res.statusCode == 200) {
        _pollenData = json.decode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception('Pollen API Error: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch pollen data: $e');
    }
  }

  Future<void> _fetchAirQualityData() async {
    try {
      final base = Uri.parse('https://airquality.googleapis.com/v1/currentConditions:lookup');
      final requestBody = {
        'location': {
          'latitude': _lat,
          'longitude': _lng,
        },
      };

      final res = await http.post(
        base.replace(queryParameters: {'key': _apiKey}),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (res.statusCode == 200) {
        _airQualityData = json.decode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception('Air Quality API Error: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch air quality data: $e');
    }
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
      case 'GOOD':
        return Colors.lightGreen;
      case 'MODERATE':
        return Colors.orange;
      case 'HIGH':
      case 'UNHEALTHY_FOR_SENSITIVE_GROUPS':
        return Colors.redAccent;
      case 'VERY_HIGH':
      case 'UNHEALTHY':
        return Colors.red[700]!;
      case 'VERY_UNHEALTHY':
        return Colors.purple;
      case 'HAZARDOUS':
        return Colors.purple[900]!;
      default:
        return Colors.blueGrey;
    }
  }

  Color _getAQIColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow[700]!;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.purple[900]!;
  }

  String _getAQICategory(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  Map<String, dynamic> _getTreatmentSuggestions() {
    if (_selectedTreatment == null || _selectedTreatment == _treatmentTypes.first) {
      return {
        'canGoOut': true,
        'recommendation': 'Please select your treatment type for personalized recommendations.',
        'precautions': [],
      };
    }

    final pollenLevels = _getHighestPollenLevel();
    final aqiLevel = _getCurrentAQI();
    final hasAirQualityData = _hasAirQualityData();
    
    bool canGoOut = true;
    List<String> precautions = [];
    String recommendation = '';

    // High-risk conditions - prioritize pollen data if air quality is unavailable
    if (hasAirQualityData) {
      // Use both pollen and air quality data
      if (aqiLevel > 150 || (pollenLevels['highest'] ?? 0) >= 4) {
        canGoOut = false;
        recommendation = 'Stay indoors today. Air quality and/or pollen levels are too high for safe outdoor activities during your immunotherapy treatment.';
      } else if (aqiLevel > 100 || (pollenLevels['highest'] ?? 0) >= 3) {
        recommendation = 'Limited outdoor activity recommended. Take extra precautions if you must go outside.';
      } else {
        recommendation = 'Good conditions for outdoor activities. Continue your normal routine with basic precautions.';
      }
    } else {
      // Use only pollen data when air quality is unavailable
      if ((pollenLevels['highest'] ?? 0) >= 4) {
        canGoOut = false;
        recommendation = 'Stay indoors today. Pollen levels are very high for safe outdoor activities during your immunotherapy treatment. (Air quality data unavailable)';
      } else if ((pollenLevels['highest'] ?? 0) >= 3) {
        recommendation = 'Limited outdoor activity recommended due to high pollen levels. Take extra precautions if you must go outside. (Air quality data unavailable)';
      } else if ((pollenLevels['highest'] ?? 0) >= 2) {
        recommendation = 'Moderate pollen conditions. Continue normal activities with basic precautions. (Air quality data unavailable)';
      } else {
        recommendation = 'Low pollen conditions for outdoor activities. Continue your normal routine. (Air quality data unavailable)';
      }
    }

    // Treatment-specific precautions
    if (_selectedTreatment!.contains('Grass') && (pollenLevels['grass'] ?? 0) >= 2) {
      precautions.add('Avoid grassy areas and parks');
      precautions.add('Shower immediately after being outdoors');
    }
    if (_selectedTreatment!.contains('Tree') && (pollenLevels['tree'] ?? 0) >= 2) {
      precautions.add('Avoid wooded areas and tree-lined streets');
      precautions.add('Keep car windows closed while driving');
    }
    if (_selectedTreatment!.contains('Ragweed') && (pollenLevels['weed'] ?? 0) >= 2) {
      precautions.add('Avoid rural areas and vacant lots');
      precautions.add('Wear sunglasses to protect eyes');
    }

    // General precautions based on available data
    if (hasAirQualityData) {
      // Use both pollen and air quality for precautions
      if (aqiLevel > 50 || (pollenLevels['highest'] ?? 0) >= 2) {
        precautions.addAll([
          'Wear an N95 mask when outdoors',
          'Take antihistamines 30 minutes before going out',
          'Keep windows closed, use air conditioning',
          'Check with your allergist about adjusting medication timing',
        ]);
      }
    } else {
      // Use only pollen data for precautions
      if ((pollenLevels['highest'] ?? 0) >= 2) {
        precautions.addAll([
          'Wear an N95 mask when outdoors (for pollen protection)',
          'Take antihistamines 30 minutes before going out',
          'Keep windows closed, use air conditioning',
          'Check with your allergist about adjusting medication timing',
          'Monitor air quality separately if possible',
        ]);
      }
    }

    return {
      'canGoOut': canGoOut,
      'recommendation': recommendation,
      'precautions': precautions,
      'treatmentType': _selectedTreatment,
      'hasAirQualityData': hasAirQualityData,
    };
  }

  Map<String, int> _getHighestPollenLevel() {
    int grassLevel = 0, treeLevel = 0, weedLevel = 0;
    
    if (_pollenData['dailyInfo'] != null && _pollenData['dailyInfo'].isNotEmpty) {
      final pollenTypes = _pollenData['dailyInfo'][0]['pollenTypeInfo'] as List?;
      if (pollenTypes != null) {
        for (var pollen in pollenTypes) {
          final code = pollen['code']?.toString().toUpperCase() ?? '';
          final value = pollen['indexInfo']?['value'] ?? 0;
          
          if (code == 'GRASS') grassLevel = value;
          if (code == 'TREE') treeLevel = value;
          if (code == 'WEED') weedLevel = value;
        }
      }
    }
    
    return {
      'grass': grassLevel,
      'tree': treeLevel,
      'weed': weedLevel,
      'highest': [grassLevel, treeLevel, weedLevel].reduce((a, b) => a > b ? a : b),
    };
  }

  int _getCurrentAQI() {
    if (_airQualityData['indexes'] != null && _airQualityData['indexes'].isNotEmpty) {
      return _airQualityData['indexes'][0]['aqi'] ?? 0;
    }
    return 0;
  }

  bool _hasAirQualityData() {
    return _airQualityData.isNotEmpty && _airQualityData['indexes'] != null;
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oklahoma, USA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Today, ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Last updated: ${_formatLastUpdated()}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _fetchAllData,
                icon: Icon(Icons.refresh, color: Colors.grey[700], size: 24),
                tooltip: 'Refresh data',
              ),
            ],
          ),
        ),
        // Treatment dropdown
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTreatment,
              isExpanded: true,
              hint: const Text('Select Treatment Type'),
              items: _treatmentTypes.map((String treatment) {
                return DropdownMenuItem<String>(
                  value: treatment,
                  child: Text(
                    treatment,
                    style: TextStyle(
                      fontSize: 14,
                      color: treatment == _treatmentTypes.first 
                        ? Colors.grey[600] 
                        : Colors.grey[800],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTreatment = newValue;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAirQualityCard() {
    final aqi = _getCurrentAQI();
    final category = _getAQICategory(aqi);
    final color = _getAQIColor(aqi);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
            child: Icon(Icons.air, size: 32, color: color),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Air Quality Index',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current air quality conditions',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AQI: $aqi',
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
          _buildAQIIndicator(aqi, color),
        ],
      ),
    );
  }

  Widget _buildAirQualityUnavailableCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
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
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber, size: 32, color: Colors.orange[700]),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Air Quality Data Unavailable',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your API key needs Air Quality API access. Please enable it in Google Cloud Console.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.3),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Text(
                    'API ACCESS REQUIRED',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAQIIndicator(int aqi, Color color) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: (aqi / 300.0).clamp(0.0, 1.0),
              strokeWidth: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Center(
            child: Text(
              '$aqi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentSuggestions() {
    final suggestions = _getTreatmentSuggestions();
    final canGoOut = suggestions['canGoOut'] as bool;
    final recommendation = suggestions['recommendation'] as String;
    final precautions = suggestions['precautions'] as List<String>;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: canGoOut ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  canGoOut ? Icons.check_circle : Icons.warning,
                  size: 28,
                  color: canGoOut ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canGoOut ? 'Safe to Go Out' : 'Stay Indoors',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: canGoOut ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Immunotherapy Recommendation',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            recommendation,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (precautions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Precautions:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...precautions.map((precaution) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16, color: Colors.orange)),
                  Expanded(
                    child: Text(
                      precaution,
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Environmental Health',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF0d6efd),
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                  Text('Loading environmental data...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
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
                  
                  // Treatment Suggestions
                  if (_selectedTreatment != _treatmentTypes.first)
                    _buildTreatmentSuggestions(),
                  
                  // Air Quality Section
                  const Text(
                    'Air Quality Index',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _hasAirQualityData() 
                    ? _buildAirQualityCard()
                    : _buildAirQualityUnavailableCard(),
                  
                  // Pollen Section
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
            'Health Index Guide',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Pollen Level Guide
          const Text(
            'Pollen Levels:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _buildLegendItem(
            'Low (1-2)',
            Colors.lightGreen,
            'Minimal symptoms for most people',
          ),
          _buildLegendItem(
            'Moderate (3)',
            Colors.orange,
            'Some symptoms for sensitive people',
          ),
          _buildLegendItem('High (4)', Colors.redAccent, 'Symptoms for most people'),
          _buildLegendItem(
            'Very High (5)',
            Colors.purple,
            'Severe symptoms for most people',
          ),
          
          const SizedBox(height: 16),
          
          // AQI Guide
          const Text(
            'Air Quality Index (AQI):',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _buildLegendItem(
            'Good (0-50)',
            Colors.green,
            'Air quality is satisfactory',
          ),
          _buildLegendItem(
            'Moderate (51-100)',
            Colors.yellow[700]!,
            'Acceptable for most people',
          ),
          _buildLegendItem(
            'Unhealthy for Sensitive (101-150)',
            Colors.orange,
            'Sensitive groups may experience symptoms',
          ),
          _buildLegendItem(
            'Unhealthy (151-200)',
            Colors.red,
            'Everyone may experience symptoms',
          ),
          _buildLegendItem(
            'Very Unhealthy (201-300)',
            Colors.purple,
            'Health alert for everyone',
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
