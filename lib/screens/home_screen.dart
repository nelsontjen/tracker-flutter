import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/add_expense_form.dart';
import '../widgets/expense_chart.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  List<Expense> _expenses = []; 
  List<Expense> _allExpenses = []; 
  
  bool _isLoading = true;

  int _chartMonthFilter = DateTime.now().month;
  int _chartYearFilter = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    // Auto-logout timer removed in favor of silent background auto-login.
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ==== 1. AUTO LOGOUT LOGIC (Dihapus) ====
  // Timer logout otomatis telah dinonaktifkan karena kita menggunakan
  // mekanisme "Silent Auto-Login" di background menggunakan secure_storage.

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    final filtered = await _apiService.fetchExpenses(month: _chartMonthFilter, year: _chartYearFilter);
    final all = await _apiService.fetchExpenses(); 

    setState(() {
      _expenses = filtered;
      _allExpenses = all;
      _isLoading = false;
    });
  }

  Future<void> _addExpense(String description, double amount, DateTime date) async {
    final newExp = await _apiService.addExpense(description, amount, date);
    if (newExp != null) {
      await _loadAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengeluaran berhasil ditambahkan!')),
      );
    }
  }

  // ==== 2. KONFIRMASI DELETE ====
  Future<void> _confirmDelete(String id, String description) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengeluaran?'),
        content: Text('Apakah Anda yakin ingin menghapus "$description"? Aksi ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _apiService.deleteExpense(id);
      if (success) {
        setState(() {
          _expenses.removeWhere((item) => item.id == id);
          _allExpenses.removeWhere((item) => item.id == id);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengeluaran dihapus.')),
        );
      }
    }
  }

  void _openAddExpenseOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddExpenseForm(onAddExpense: _addExpense),
    );
  }

  // ==== EDIT EXPENSE ====
  void _openEditExpenseModal(Expense expense) {
    final descController = TextEditingController(text: expense.description);
    final amountController = TextEditingController(
        text: expense.amount.toStringAsFixed(0));
    DateTime selectedDate = expense.date;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Edit Pengeluaran',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'Deskripsi',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nominal (Rp)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Date picker row
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd MMMM yyyy', 'id_ID').format(selectedDate)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final desc = descController.text.trim();
                            final amt = double.tryParse(
                                amountController.text.replaceAll('.', '').replaceAll(',', ''));
                            if (desc.isEmpty || amt == null) return;

                            setModalState(() => isSaving = true);
                            final updated = await _apiService.editExpense(
                                expense.id, desc, amt, selectedDate);
                            setModalState(() => isSaving = false);

                            if (updated != null && mounted) {
                              setState(() {
                                final idx = _expenses.indexWhere((e) => e.id == expense.id);
                                if (idx != -1) _expenses[idx] = updated;
                                final idx2 = _allExpenses.indexWhere((e) => e.id == expense.id);
                                if (idx2 != -1) _allExpenses[idx2] = updated;
                              });
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pengeluaran berhasil diperbarui!')),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (ctx) => LoginScreen()),
    );
  }

  // ==== 3. ANIMASI SHIMMER ====
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
      highlightColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
          const SizedBox(height: 24),
          Container(height: 250, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 24),
          Container(height: 20, width: 150, color: Colors.white, margin: const EdgeInsets.only(right: 200)),
          const SizedBox(height: 12),
          for (int i = 0; i < 4; i++)
            Container(height: 70, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalExpense = _expenses.fold(0.0, (sum, item) => sum + item.amount);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Expense Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now()),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Dialog Logout juga sebagai praktik UX yang bagus
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Apakah Anda ingin keluar dari aplikasi?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                    ElevatedButton(onPressed: () { Navigator.pop(ctx); _handleLogout(); }, child: const Text('Keluar'))
                  ]
                )
              );
            },
            tooltip: 'Logout',
          )
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading() // Menggunakan efek shimmer!
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                   // Summary Card
                   Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Expenses',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormatter.format(totalExpense),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Filter & Chart Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Filter Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                value: _chartMonthFilter,
                                items: [
                                  const DropdownMenuItem(value: -1, child: Text("All Months")),
                                  ...List.generate(12, (index) {
                                      final str = DateFormat('MMMM', 'id_ID').format(DateTime(2000, index + 1));
                                      return DropdownMenuItem(value: index + 1, child: Text(str));
                                  })
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _chartMonthFilter = val);
                                    _loadAllData();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                value: _chartYearFilter,
                                items: List.generate(5, (index) {
                                  final y = DateTime.now().year - 2 + index;
                                  return DropdownMenuItem(value: y, child: Text(y.toString()));
                                }),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _chartYearFilter = val);
                                    _loadAllData();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 200,
                          child: ExpenseChart(
                            allExpenses: _allExpenses, 
                            selectedYear: _chartYearFilter
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // List Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Expenses (${_expenses.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Expenses List
                  ..._expenses.map((expense) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(expense.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(DateFormat('dd MMM yyyy', 'id_ID').format(expense.date)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currencyFormatter.format(expense.amount),
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            color: Colors.grey.shade400,
                            tooltip: 'Edit',
                            onPressed: () => _openEditExpenseModal(expense),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.grey.shade400,
                            tooltip: 'Hapus',
                            onPressed: () => _confirmDelete(expense.id, expense.description),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                  if (_expenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text("Belum ada pengeluaran pada periode ini.", style: TextStyle(color: Colors.grey)),
                      ),
                    )
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddExpenseOverlay,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
