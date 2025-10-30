import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PVerifyService {
  static const String _baseUrl = 'https://api.pverify.com/';
  static const String _tokenUrl = '$_baseUrl/Token';
  static const String _eligibilityUrl = '$_baseUrl/api/EligibilitySummary';
  
  // OAuth2 credentials (in production, these should be stored securely)
  static const String _clientId = '4f1efc7e-8102-4815-b6cc-09b890acb91e';
  static const String _clientSecret = '0zxranEQiQZRWwq2iACkgvdy7Z60YQ';
  
  // Production API requires username (typically email or user ID)
  // This should be provided during token generation for production
  static const String _username = 'AGurunathan'; // UPDATE THIS with your pVerify username/email
  
  // Token storage keys
  static const String _tokenKey = 'pverify_access_token';
  static const String _expiryKey = 'pverify_token_expiry';
  static const String _clientIdKey = 'pverify_client_id'; // Track which client ID generated the token
  
  // In-memory cache
  static String? _accessToken;
  static DateTime? _tokenExpiry;
  
  /// Singleton instance
  static final PVerifyService _instance = PVerifyService._internal();
  factory PVerifyService() => _instance;
  PVerifyService._internal();
  
  /// Get a valid access token (generates new one if expired or doesn't exist)
  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    // If force refresh requested, clear existing token
    if (forceRefresh) {
      print('🔄 Force refresh requested - clearing cached token');
      await clearToken();
    }
    
    // Load from persistent storage if not in memory
    if (_accessToken == null) {
      await _loadTokenFromStorage();
    }
    
    // Check if client ID has changed (environment switch)
    if (_accessToken != null && !await _isTokenForCurrentClient()) {
      print('⚠️ Client ID changed - clearing old token');
      await clearToken();
    }
    
    if (_isTokenValid()) {
      return _accessToken;
    }
    
    return await _generateToken();
  }
  
  /// Check if stored token was generated for current client ID
  Future<bool> _isTokenForCurrentClient() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedClientId = prefs.getString(_clientIdKey);
      return storedClientId == _clientId;
    } catch (e) {
      return false;
    }
  }
  
  /// Load token from persistent storage
  Future<void> _loadTokenFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_tokenKey);
      
      final expiryMillis = prefs.getInt(_expiryKey);
      if (expiryMillis != null) {
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      }
      
      if (_accessToken != null && _tokenExpiry != null) {
        print('🔄 Loaded pVerify token from storage');
        print('Token expires at: $_tokenExpiry');
      }
    } catch (e) {
      print('⚠️ Error loading token from storage: $e');
      _accessToken = null;
      _tokenExpiry = null;
    }
  }
  
  /// Save token to persistent storage
  Future<void> _saveTokenToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_accessToken != null && _tokenExpiry != null) {
        await prefs.setString(_tokenKey, _accessToken!);
        await prefs.setInt(_expiryKey, _tokenExpiry!.millisecondsSinceEpoch);
        await prefs.setString(_clientIdKey, _clientId); // Store which client ID generated this token
        print('💾 Saved pVerify token to storage');
      }
    } catch (e) {
      print('⚠️ Error saving token to storage: $e');
    }
  }
  
  /// Check if current token is valid and not expired
  bool _isTokenValid() {
    if (_accessToken == null || _tokenExpiry == null) {
      return false;
    }
    
    // Check if token expires in the next 5 minutes (buffer time)
    final now = DateTime.now();
    final bufferTime = _tokenExpiry!.subtract(const Duration(minutes: 5));
    
    return now.isBefore(bufferTime);
  }
  
  /// Generate a new OAuth2 token from pVerify
  Future<String?> _generateToken() async {
    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'Client_Id': _clientId,
          'Client_Secret': _clientSecret,
          'grant_type': 'client_credentials',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int? ?? 3600; // Default 1 hour
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        
        // Save to persistent storage
        await _saveTokenToStorage();
        
        print('✅ pVerify token generated successfully');
        print('Token expires at: $_tokenExpiry');
        
        return _accessToken;
      } else {
        print('❌ Failed to generate pVerify token');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error generating pVerify token: $e');
      return null;
    }
  }
  
  /// Clear stored token (useful for logout or force refresh)
  Future<void> clearToken() async {
    _accessToken = null;
    _tokenExpiry = null;
    
    // Clear from persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_expiryKey);
      await prefs.remove(_clientIdKey);
      print('🗑️ Cleared pVerify token from storage');
    } catch (e) {
      print('⚠️ Error clearing token from storage: $e');
    }
  }
  
  /// Force refresh the access token (clears cache and generates new token)
  Future<String?> refreshToken() async {
    print('🔄 Refreshing pVerify access token...');
    return await getAccessToken(forceRefresh: true);
  }
  
  /// Get token info for debugging
  String getTokenInfo() {
    if (_accessToken == null) {
      return 'No token available';
    }
    
    final isValid = _isTokenValid();
    final expiryStr = _tokenExpiry?.toLocal().toString() ?? 'Unknown';
    
    return 'Token: ${_accessToken?.substring(0, 20)}...\n'
           'Valid: $isValid\n'
           'Expires: $expiryStr\n'
           'Storage: Persistent (SharedPreferences)';
  }
  
  /// Get detailed storage info for debugging
  Future<String> getStorageInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(_tokenKey);
      final storedExpiry = prefs.getInt(_expiryKey);
      
      final memoryInfo = _accessToken != null ? 'Has token' : 'No token';
      final storageInfo = storedToken != null ? 'Has token' : 'No token';
      final expiryInfo = storedExpiry != null 
          ? DateTime.fromMillisecondsSinceEpoch(storedExpiry).toLocal().toString()
          : 'No expiry';
      
      return 'Memory: $memoryInfo\n'
             'Storage: $storageInfo\n'
             'Stored Expiry: $expiryInfo';
    } catch (e) {
      return 'Error reading storage: $e';
    }
  }

  /// Get eligibility summary from pVerify API
  Future<Map<String, dynamic>?> getEligibilitySummary({
    String? payerCode,
    String? payerName,
    String? memberID,
    String? firstName,
    String? lastName,
    String? dob,
    String? providerNPI,
    String? providerLastName,
    bool isRetry = false,
  }) async {
    try {
      // Get valid access token
      final token = await getAccessToken();
      if (token == null) {
        throw Exception('Unable to get access token');
      }

      // Use current date for DOS (Date of Service)
      final now = DateTime.now();
      final dosDate = "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}";

      // Build request body with actual provided values
      final requestBody = {
        "payerCode": payerCode ?? "00192",
        "payerName": payerName ?? "UHC",
        "provider": {
          "firstName": "",
          "middleName": "",
          "lastName": providerLastName ?? "Provider",
          "npi": providerNPI ?? "1467560003" // Valid NPI format
        },
        "subscriber": {
          "firstName": firstName ?? "",  // Empty string if not provided
          "dob": dob ?? "01/01/1980",
          "lastName": lastName ?? "",    // Empty string if not provided
          "memberID": memberID ?? "1234567890"
        },
        "dependent": null,
        "isSubscriberPatient": "True",
        "doS_StartDate": dosDate,
        "doS_EndDate": dosDate,
        "PracticeTypeCode": "3",
        "referenceId": "Pat MRN",
        "Location": "Test Location",
        "IncludeTextResponse": "false",
        "RequestSource": "API"
      };

      print('🔍 Making eligibility request to pVerify...');
      print('📋 Request Details:');
      print('  - Payer Code: ${payerCode ?? "00192"}');
      print('  - Payer Name: ${payerName ?? "UHC"}');
      print('  - Member ID: ${memberID ?? "1234567890"}');
      print('  - First Name: ${firstName ?? "(empty)"}');
      print('  - Last Name: ${lastName ?? "(empty)"}');
      print('  - DOB: ${dob ?? "01/01/1980"}');
      print('  - DOS Date: $dosDate');
      print('  - Provider NPI: ${providerNPI ?? "1467560003"}');
      print('📦 Full Request Body:');
      print(json.encode(requestBody));

      final response = await http.post(
        Uri.parse(_eligibilityUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Client-API-Id': _clientId,
          'Username': _username, // Production requires username header
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📋 Response Status: ${response.statusCode}');
      print('📋 Response Body: ${response.body}');
      
      // Also log to a more readable format if possible
      try {
        final prettyData = json.decode(response.body);
        print('📋 Formatted Response:');
        print(json.encode(prettyData).toString().replaceAll(',', ',\n  '));
      } catch (e) {
        print('📋 Raw response (not JSON): ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Eligibility request successful');
        return data;
      } else if (response.statusCode == 401 && !isRetry) {
        // Token is invalid - refresh and retry once
        print('⚠️ Got 401 error - token may be invalid. Refreshing token and retrying...');
        await refreshToken();
        
        // Retry the request with fresh token
        return await getEligibilitySummary(
          payerCode: payerCode,
          payerName: payerName,
          memberID: memberID,
          firstName: firstName,
          lastName: lastName,
          dob: dob,
          isRetry: true, // Prevent infinite retry loop
        );
      } else {
        print('❌ Eligibility request failed');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error in eligibility request: $e');
      return null;
    }
  }
}
