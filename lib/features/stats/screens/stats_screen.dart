import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/drive_session_model.dart';
import '../../../services/drive_stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _statsService = DriveStatsService();
  List<DailyAlertnessStat> _weekly = [];
  List<DriveEvent> _events = [];
  double _averagePercent = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final weekly = await _statsService.getWeeklyStats();
    final events = await _statsService.getRecentEvents();
    final avg = await _statsService.getAverageAlertnessPercent();
    if (!mounted) return;
    setState(() {
      _weekly = weekly;
      _events = events;
      _averagePercent = avg;
      _isLoading = false;
    });
  }

  Color _barColor(double percent) {
    if (percent >= 70) return AppColors.riskNormal;
    if (percent >= 50) return AppColors.riskCaution;
    if (percent >= 30) return AppColors.riskWarning;
    return AppColors.riskDanger;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สถิติการขับขี่')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '7 วันที่ผ่านมา',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                              Text('คะแนนความตื่นตัวเฉลี่ยรายวัน',
                                  style: TextStyle(fontSize: 12)),
                              Text('AI วิเคราะห์จากทุกทริป (0=แย่มาก, 100=ตื่นตัว)',
                                  style: TextStyle(
                                      fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                          Text(
                            '${_averagePercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 20,
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
                                    if (i < 0 || i >= _weekly.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        _weekly[i].dayLabel,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: [
                              for (int i = 0; i < _weekly.length; i++)
                                BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: _weekly[i].alertnessPercent,
                                      color: _barColor(
                                          _weekly[i].alertnessPercent),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('เหตุการณ์ล่าสุด',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('ดูทั้งหมด',
                        style: TextStyle(color: AppColors.primary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final event in _events) _EventCard(event: event),
              ],
            ),
    );
  }
}

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
