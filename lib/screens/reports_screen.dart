import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final auth = context.watch<AuthProvider>();

    final assignedRoom = auth.profile?['classroom_name']?.toString() ?? auth.profile?['room']?.toString();
    final stats = data.getDashboardStats(auth.role, assignedRoom);
    final redByRoom = stats.chartByRoom;
    final trend = stats.chartByDateTime;
    final heatmap = data.buildHeatmap();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF export - coming soon')),
                );
              },
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Export weekly PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a2332),
                foregroundColor: const Color(0xFFe8edf4),
                side: const BorderSide(color: Color(0xFF2d3a4f)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Charts
          const Text('Noise trend (from noise_events)',
            style: TextStyle(color: Color(0xFFe8edf4), fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildTrendChart(trend),
          const SizedBox(height: 24),

          const Text('RED incidents per room / device',
            style: TextStyle(color: Color(0xFFe8edf4), fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildRedBarChart(redByRoom),
          const SizedBox(height: 24),

          // Heatmap
          const Text('Heatmap — RED events by weekday × hour',
            style: TextStyle(color: Color(0xFFe8edf4), fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildHeatmap(heatmap),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<DateTimeChartItem> items) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 200,
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
              color: const Color(0xFFef4444),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFef4444).withValues(alpha: 0.1),
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
                interval: items.length > 8 ? (items.length / 6).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(items[idx].label,
                      style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 8)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text('${value.toInt()}',
                  style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 10)),
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

  Widget _buildRedBarChart(List<ChartItem> items) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 200,
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
              color: const Color(0xFFef4444).withValues(alpha: 0.75),
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
                getTitlesWidget: (value, meta) => Text('${value.toInt()}',
                  style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 10)),
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

  Widget _buildHeatmap(List<HeatmapCell> cells) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    const hours = [7, 8, 9, 10, 11, 12, 13, 14];
    final maxCount = cells.isEmpty ? 1 : cells.map((c) => c.count).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2332),
        border: Border.all(color: const Color(0xFF2d3a4f)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels
              Column(
                children: dayLabels.map((d) => Container(
                  height: 24,
                  width: 30,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(d, style: const TextStyle(color: Color(0xFF8b9cb3), fontSize: 10)),
                )).toList(),
              ),
              const SizedBox(width: 4),
              // Heatmap grid
              Column(
                children: hours.map((h) => Row(
                  children: List.generate(5, (d) {
                    final cell = cells.firstWhere(
                      (c) => c.day == d + 1 && c.hour == h,
                      orElse: () => HeatmapCell(day: d + 1, dayLabel: '', hour: h, count: 0),
                    );
                    final intensity = maxCount > 0 ? cell.count / maxCount : 0.0;
                    final r = (239 * intensity + 34 * (1 - intensity)).toInt();
                    final g = (68 * intensity + 197 * (1 - intensity)).toInt();
                    return Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, r, g, 80),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      alignment: Alignment.center,
                      child: cell.count > 0
                          ? Text('${cell.count}',
                              style: const TextStyle(color: Colors.black87, fontSize: 8, fontWeight: FontWeight.w600))
                          : null,
                    );
                  }),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('7 AM', style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 10)),
              Text('10 AM', style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 10)),
              Text('1 PM', style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 10)),
              Text('2 PM', style: TextStyle(color: Color(0xFF8b9cb3), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}