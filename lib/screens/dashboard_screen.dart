import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();

    if (data.events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, color: Color(0xFF8b9cb3), size: 48),
            SizedBox(height: 16),
            Text('Loading from database…', style: TextStyle(color: Color(0xFF8b9cb3))),
          ],
        ),
      );
    }

    final assignedRoom = auth.profile?['classroom_name']?.toString() ?? auth.profile?['room']?.toString();
    final stats = data.getDashboardStats(auth.role, assignedRoom);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats grid
          Row(
            children: [
              Expanded(child: _statCard('Noise incidents today', '${stats.incidentsToday}', null)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Red alerts this week', '${stats.redAlertsWeek}', const Color(0xFFef4444))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('Most noisy room', stats.mostNoisyRoom, null, subtitle: '${stats.mostNoisyCount} incidents')),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Peak noise time', stats.peakTime, const Color(0xFF22c55e))),
            ],
          ),
          if (auth.isAdmin) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('Supabase errors', '${data.supabaseErrorCount}', const Color(0xFFef4444))),
                const SizedBox(width: 12),
                Expanded(child: _statCard('API failures', '${data.apiFailCount}', const Color(0xFFef4444))),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Charts
          const Text('Noise incidents per room / device',
            style: TextStyle(color: Color(0xFFe8edf4), fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildRoomChart(stats.chartByRoom),
          const SizedBox(height: 24),

          const Text('Incidents by date & time',
            style: TextStyle(color: Color(0xFFe8edf4), fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildTimeChart(stats.chartByDateTime),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color? valueColor, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2332),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 11, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFFe8edf4),
              fontSize: 24, fontWeight: FontWeight.w700,
            )),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomChart(List<ChartItem> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No data', style: TextStyle(color: Color(0xFF8b9cb3)))),
      );
    }

    final labels = items.map((e) => e.room).toList();
    final values = items.map((e) => e.count.toDouble()).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2332),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
          barGroups: List.generate(items.length, (i) => BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(
              toY: values[i],
              color: const Color(0xFF38bdf8),
              width: items.length > 4 ? 12 : 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(4),
              ),
            )],
          )),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      labels[idx].length > 12 ? '${labels[idx].substring(0, 10)}…' : labels[idx],
                      style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 10),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: maxVal > 10 ? (maxVal / 4).ceilToDouble() : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xFF2d3a4f).withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildTimeChart(List<DateTimeChartItem> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No data', style: TextStyle(color: Color(0xFF8b9cb3)))),
      );
    }

    final maxVal = items.map((e) => e.count).reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2332),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (items.length - 1).toDouble(),
          minY: 0,
          maxY: maxVal * 1.3,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(items.length, (i) => FlSpot(i.toDouble(), items[i].count.toDouble())),
              color: const Color(0xFF38bdf8),
              barWidth: 2,
              dotData: FlDotData(
                show: items.length < 30,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3,
                  color: const Color(0xFF38bdf8),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF38bdf8).withValues(alpha: 0.1),
              ),
              isCurved: true,
              curveSmoothness: 0.25,
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: items.length > 12 ? (items.length / 6).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      items[idx].label,
                      style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 8),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 10),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: maxVal > 10 ? (maxVal / 4).ceilToDouble() : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xFF2d3a4f).withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: const Color(0xFF2d3a4f).withValues(alpha: 0.1),
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}