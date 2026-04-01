import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Ganti dengan domain Vercel Anda, contoh: 'https://nama-proyek-anda.vercel.app/api'
  static const String baseUrl = 'https://tracker-nextjs-klug.vercel.app/api';

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'), // Sesuaikan dengan route API login Anda
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token']; // Pastikan sesuai respons backend Next.js

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error during login: $e');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      // Decode JWT untuk cek expired (sama dengan logic di Next.js)
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payloadStr = _decodeBase64(parts[1]);
      final payloadMap = jsonDecode(payloadStr);

      if (payloadMap is! Map<String, dynamic>) return false;
      if (!payloadMap.containsKey('exp')) return true;

      final expTime = DateTime.fromMillisecondsSinceEpoch(
        payloadMap['exp'] * 1000,
      );
      return expTime.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!"');
    }
    return utf8.decode(base64Url.decode(output));
  }
}
