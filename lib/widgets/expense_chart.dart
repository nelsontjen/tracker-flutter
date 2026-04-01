import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExpenseChart extends StatelessWidget {
  final List<Expense> allExpenses;
  final int selectedYear;

  const ExpenseChart({super.key, required this.allExpenses, required this.selectedYear});

  @override
  Widget build(BuildContext context) {
    // Kumpulkan total dana per bulan untuk tahun terpilih
    final Map<int, double> monthlyTotals = {for (var i = 1; i <= 12; i++) i: 0.0};
    
    for (final exp in allExpenses) {
      if (exp.date.year == selectedYear) {
        monthlyTotals[exp.date.month] = (monthlyTotals[exp.date.month] ?? 0) + exp.amount;
      }
    }

    final double maxVal = monthlyTotals.values.fold(0.0, (m, v) => v > m ? v : m);
    final double maxY = maxVal == 0 ? 100000 : maxVal * 1.2;

    return AspectRatio(
      aspectRatio: 1.7,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              // getTooltipColor: (group) => Colors.transparent, // Fixes deprecated style property in modern fl_chart, tapi menggunakan versi pub terbaru mungkin berbeda
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(rod.toY),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      months[value.toInt() - 1],
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: monthlyTotals.entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value,
                  color: Theme.of(context).colorScheme.primary,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
