import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Ganti dengan domain Vercel Anda, contoh: 'https://nama-proyek-anda.vercel.app/api'
  static const String baseUrl = 'https://tracker-nextjs-klug.vercel.app/api';
  
  // Instance untuk penyimpanan aman
  final _secureStorage = const FlutterSecureStorage();

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
          
          // Simpan kredensial secara aman untuk Silent Auto-Login
          await _secureStorage.write(key: 'saved_username', value: username);
          await _secureStorage.write(key: 'saved_password', value: password);
          
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error during login: $e');
      return false;
    }
  }

  // Kembalikan null jika sukses, atau pesan error jika gagal
  Future<String?> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 201) {
        return null; // sukses, tidak ada error
      }

      final data = jsonDecode(response.body);
      return data['error'] ?? 'Registrasi gagal. Coba lagi.';
    } catch (e) {
      return 'Tidak dapat terhubung ke server.';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    
    // Hapus kredensial saat logout manual
    await _secureStorage.delete(key: 'saved_username');
    await _secureStorage.delete(key: 'saved_password');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    bool isTokenValid = false;

    if (token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payloadStr = _decodeBase64(parts[1]);
          final payloadMap = jsonDecode(payloadStr);

          if (payloadMap is Map<String, dynamic>) {
            if (!payloadMap.containsKey('exp')) {
               isTokenValid = true;
            } else {
               final expTime = DateTime.fromMillisecondsSinceEpoch(
                 payloadMap['exp'] * 1000,
               );
               isTokenValid = expTime.isAfter(DateTime.now());
            }
          }
        }
      } catch (e) {
        // Abaikan error format, token dianggap tidak valid
      }
    }

    if (isTokenValid) {
      return true;
    }

    // SILENT RE-LOGIN: Jika token hangus / kosong, coba login pakai password tersimpan
    final savedUsername = await _secureStorage.read(key: 'saved_username');
    final savedPassword = await _secureStorage.read(key: 'saved_password');
    
    if (savedUsername != null && savedPassword != null) {
      // Coba re-login secara diam-diam
      final success = await login(savedUsername, savedPassword);
      return success;
    }

    return false;
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
        throw Exception('Illegal base64url string!');
    }
    return utf8.decode(base64Url.decode(output));
  }
}
