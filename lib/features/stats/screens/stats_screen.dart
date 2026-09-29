import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/drive_session_model.dart';
import '../../../services/drive_stats_service.dart';

/// หน้าแสดงสถิติการขับขี่
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _statsService = DriveStatsService();

  Color _barColor(double percent) {
    if (percent >= 70) return AppColors.riskNormal;
    if (percent >= 50) return AppColors.riskCaution;
    if (percent >= 30) return AppColors.riskWarning;
    return AppColors.riskDanger;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สถิติการขับขี่'),
      ),
      body: StreamBuilder<List<DailyAlertnessStat>>(
        stream: _statsService.getWeeklyStatsStream(),
        builder: (context, weeklySnapshot) {
          return StreamBuilder<List<DriveEvent>>(
            stream: _statsService.getRecentEventsStream(),
            builder: (context, eventsSnapshot) {
              if (weeklySnapshot.connectionState == ConnectionState.waiting ||
                  eventsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final weekly = weeklySnapshot.data ?? [];
              final events = eventsSnapshot.data ?? [];

              final totalMinutes = weekly.fold<double>(0, (sum, item) => sum + item.alertnessPercent);
              final averagePercent = weekly.isNotEmpty ? totalMinutes / weekly.length : 0.0;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    '7 วันที่ผ่านมา',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('เวลาขับขี่เฉลี่ยรายวัน',
                                    style: TextStyle(fontSize: 12)),
                                Text('คำนวณจากทริปในสัปดาห์นี้',
                                    style: TextStyle(
                                        fontSize: 10, color: AppColors.textMuted)),
                              ],
                            ),
                            Text(
                              '${averagePercent.toStringAsFixed(0)} นาที',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 140,
                          child: BarChart(
                            BarChartData(
                              maxY: 100,
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= weekly.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          weekly[i].dayLabel,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (int i = 0; i < weekly.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: weekly[i].alertnessPercent,
                                        color: _barColor(
                                            weekly[i].alertnessPercent),
                                        width: 16,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('ประวัติการขับขี่ล่าสุด',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  if (events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'ยังไม่มีประวัติการขับขี่',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    for (final event in events) _EventCard(event: event),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// 🟢 Class สำหรับวาดการ์ดแต่ละรายการ (อยู่ล่างสุด นอก Class _StatsScreenState)
class _EventCard extends StatelessWidget {
  final DriveEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            event.isWarning ? Icons.warning_amber_rounded : Icons.check_circle,
            color: event.isWarning ? AppColors.riskWarning : AppColors.riskNormal,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(event.subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (event.isWarning
                      ? AppColors.riskWarning
                      : AppColors.riskNormal)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              event.badgeLabel,
              style: TextStyle(
                fontSize: 11,
                color: event.isWarning
                    ? AppColors.riskWarning
                    : AppColors.riskNormal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}