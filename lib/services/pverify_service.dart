import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PVerifyService {
  static const String _baseUrl = 'https://api.pverify.com/test';
  static const String _tokenUrl = '$_baseUrl/Token';
  
  // OAuth2 credentials (in production, these should be stored securely)
  static const String _clientId = 'c4cc14d3-e602-4755-91c0-4dcd611752d9';
  static const String _clientSecret = 'lvePnzOp9q8zs3xTeJ52tGwt77IDw';
  
  // Token storage keys
  static const String _tokenKey = 'pverify_access_token';
  static const String _expiryKey = 'pverify_token_expiry';
  
  // In-memory cache
  static String? _accessToken;
  static DateTime? _tokenExpiry;
  
  /// Singleton instance
  static final PVerifyService _instance = PVerifyService._internal();
  factory PVerifyService() => _instance;
  PVerifyService._internal();
  
  /// Get a valid access token (generates new one if expired or doesn't exist)
  Future<String?> getAccessToken() async {
    // Load from persistent storage if not in memory
    if (_accessToken == null) {
      await _loadTokenFromStorage();
    }
    
    if (_isTokenValid()) {
      return _accessToken;
    }
    
    return await _generateToken();
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
      print('🗑️ Cleared pVerify token from storage');
    } catch (e) {
      print('⚠️ Error clearing token from storage: $e');
    }
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
}
