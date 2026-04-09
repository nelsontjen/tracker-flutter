import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/expense.dart';
import 'auth_service.dart';

class ApiService {
  final String _baseUrl = AuthService.baseUrl;
  final AuthService _authService = AuthService();

  // Memaksimalkan fitur filter bawaan di useExpenses.js
  Future<List<Expense>> fetchExpenses({int? month, int? year}) async {
    final token = await _authService.getToken();
    if (token == null) return [];

    String query = '';
    if (month != null && year != null && month != -1) { 
      // Anggap -1 adalah 'all months', karena form kita nanti mengirim value tersebut
      query = '?month=$month&year=$year';
    } 

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/expenses$query'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => Expense.fromJson(e)).toList()
          // Mengurutkan di sisi client berdasarkan tanggal mirip Next.js (DESCENDING)
          ..sort((a, b) => b.date.compareTo(a.date)); 
      }
      return [];
    } catch (e) {
      print('Fetch Expenses Error: $e');
      return [];
    }
  }

  Future<Expense?> addExpense(String description, double amount, DateTime date) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    final newExpense = Expense(
      id: '', // Diabaikan oleh Next.js backend, dibuat dinamis oleh PostgreSQL
      description: description,
      amount: amount,
      date: date,
    );

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/expenses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(newExpense.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Expense.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Add Expense Error: $e');
      return null;
    }
  }

  Future<bool> deleteExpense(String id) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/expenses/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Delete Expense Error: $e');
      return false;
    }
  }

  Future<Expense?> editExpense(String id, String description, double amount, DateTime date) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/expenses/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'description': description,
          'amount': amount,
          'date': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        }),
      );

      if (response.statusCode == 200) {
        return Expense.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Edit Expense Error: $e');
      return null;
    }
  }
}
