import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/noise_event.dart';
import '../config/app_config.dart';

class PdfReportService {
  static Future<void> generateAndOpenWeeklyReport(
    AuthProvider auth,
    DataProvider data,
  ) async {
    final pdf = await _buildReport(auth, data);
    final bytes = await pdf.save();

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/noise_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes);

    await OpenFile.open(file.path);
  }

  static Future<pw.Document> _buildReport(
    AuthProvider auth,
    DataProvider data,
  ) async {
    final pdf = pw.Document();

    final role = auth.role;
    final assignedDeviceId = auth.profile?['device_id']?.toString();
    final events = data.filterForRole(role, assignedDeviceId);
    final stats = data.getDashboardStats(role, assignedDeviceId);
    final heatmap = data.buildHeatmap(events: events);
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final weekEvents = events.where((e) {
      final d = DateTime.tryParse(e.datetime);
      return d != null && !d.isBefore(weekAgo);
    }).toList();

    final redWeek = weekEvents.where((e) => e.status == 'red').length;
    final yellowWeek = weekEvents.where((e) => e.status == 'yellow').length;
    final greenWeek = weekEvents.where((e) => e.status == 'green').length;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Weekly Noise Monitoring Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated: ${now.toLocal().toString().substring(0, 19)}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.Text(
                'User: ${auth.name} (${role.toUpperCase()})',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 20),

              // Summary stats
              pw.Header(level: 1, child: pw.Text('Summary Statistics')),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _statBox('Total Events', '${events.length}'),
                  _statBox('This Week', '${weekEvents.length}'),
                  _statBox('RED', '$redWeek', PdfColors.red),
                  _statBox('YELLOW', '$yellowWeek', PdfColors.orange),
                  _statBox('GREEN', '$greenWeek', PdfColors.green),
                ],
              ),
              pw.SizedBox(height: 16),

              // Today's stats
              pw.Header(level: 1, child: pw.Text('Today\'s Overview')),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _statBox('Incidents Today', '${stats.incidentsToday}'),
                  _statBox('RED Alerts (7d)', '${stats.redAlertsWeek}'),
                  _statBox('Peak Time', stats.peakTime),
                ],
              ),
              pw.SizedBox(height: 16),

              // Most noisy room
              if (stats.mostNoisyRoom != '—')
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Most Noisy Room:',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        '${stats.mostNoisyRoom} (${stats.mostNoisyCount} events)',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              pw.SizedBox(height: 20),

              // Room distribution chart (text-based bar chart)
              if (stats.chartByRoom.isNotEmpty) ...[
                pw.Header(level: 1, child: pw.Text('Noise Incidents by Room')),
                pw.SizedBox(height: 8),
                ...stats.chartByRoom.map((item) {
                  final maxCount = stats.chartByRoom.first.count.toDouble();
                  final barWidth = (item.count / maxCount * 200).toDouble();
                  return pw.Row(
                    children: [
                      pw.SizedBox(
                        width: 120,
                        child: pw.Text(
                          item.room.length > 14
                              ? '${item.room.substring(0, 12)}...'
                              : item.room,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Container(
                        width: barWidth,
                        height: 12,
                        color: PdfColors.blue,
                        alignment: pw.Alignment.centerRight,
                        padding: const pw.EdgeInsets.only(right: 4),
                        child: pw.Text(
                          '${item.count}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                pw.SizedBox(height: 20),
              ],

              // Heatmap
              if (heatmap.isNotEmpty) ...[
                pw.Header(
                  level: 1,
                  child: pw.Text('RED Events Heatmap (Weekday × Hour)'),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Day',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        ...const [7, 8, 9, 10, 11, 12, 13, 14]
                            .map(
                              (h) => pw.Padding(
                                padding: const pw.EdgeInsets.all(2),
                                child: pw.Text(
                                  '$h',
                                  style: const pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            )
                            .toList(),
                      ],
                    ),
                    ...['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((dayLabel) {
                      final dayIndex =
                          [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                          ].indexOf(dayLabel) +
                          1;
                      final cells = heatmap
                          .where((c) => c.dayLabel == dayLabel)
                          .toList();
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              dayLabel,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          ...const [7, 8, 9, 10, 11, 12, 13, 14].map((hour) {
                            final cell = cells.firstWhere(
                              (c) => c.hour == hour,
                              orElse: () => HeatmapCell(
                                day: dayIndex,
                                dayLabel: dayLabel,
                                hour: hour,
                                count: 0,
                              ),
                            );
                            final intensity = cell.count > 0
                                ? (cell.count /
                                      (heatmap
                                          .map((c) => c.count)
                                          .reduce((a, b) => a > b ? a : b)
                                          .toDouble()))
                                : 0.0;
                            final gray = (255 * (1 - intensity)).toInt();
                            return pw.Container(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text(
                                cell.count > 0 ? '${cell.count}' : '',
                                style: const pw.TextStyle(fontSize: 7),
                                textAlign: pw.TextAlign.center,
                              ),
                              color: PdfColor(
                                gray / 255,
                                gray / 255,
                                gray / 255,
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],

              // Recent RED events table
              if (weekEvents.isNotEmpty) ...[
                pw.Header(
                  level: 1,
                  child: pw.Text('Recent RED Events (This Week)'),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(2),
                    2: pw.FlexColumnWidth(1),
                    3: pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        _tableHeader('Date/Time'),
                        _tableHeader('Room'),
                        _tableHeader('dB'),
                        _tableHeader('Subject/Teacher'),
                      ],
                    ),
                    ...weekEvents.where((e) => e.status == 'red').take(20).map((
                      e,
                    ) {
                      return pw.TableRow(
                        children: [
                          _tableCell('${e.date} ${e.time}'),
                          _tableCell(e.room),
                          _tableCell('${e.db}'),
                          _tableCell('${e.subject} · ${e.teacher}'),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],

              pw.SizedBox(height: 20),
              pw.Text(
                'Report generated by Smart Classroom Noise Monitor',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _statBox(String label, String value, [PdfColor? color]) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color ?? PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
    );
  }
}
