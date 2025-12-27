import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/srs_service.dart';
import '../services/progress_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  SRSStats? _srsStats;
  ProgressStats? _progressStats;
  
  // Mock weekly data
  final List<double> _weeklyActivity = [20, 45, 10, 60, 35, 80, 50];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final srsStats = await SRSService.getStats();
    final progressStats = await ProgressService.getStats();

    if (mounted) {
      setState(() {
        _srsStats = srsStats;
        _progressStats = progressStats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İstatistikler'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.darkGradient,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SRS Dağılımı (Pie Chart)
                    _buildSectionTitle('Öğrenme Durumu'),
                    const SizedBox(height: 16),
                    _buildPieChartCard(),
                    
                    const SizedBox(height: 32),
                    
                    // Haftalık Aktivite (Bar Chart)
                    _buildSectionTitle('Haftalık Aktivite (XP)'),
                    const SizedBox(height: 16),
                    _buildBarChartCard(),
                    
                    const SizedBox(height: 32),
                    
                    // Detaylı İstatistikler (List)
                    _buildSectionTitle('Detaylar'),
                    const SizedBox(height: 16),
                    _buildDetailsCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPieChartCard() {
    // SRS Stats: dueToday, totalWords, reviewedWords
    final total = _srsStats?.totalWords ?? 0;
    final reviewed = _srsStats?.reviewedWords ?? 0;
    final due = _srsStats?.dueToday ?? 0;
    final newWords = total - reviewed;

    // Pie Chart Data
    final List<PieChartSectionData> sections = [
      PieChartSectionData(
        color: AppTheme.accentGreen,
        value: (reviewed as num).toDouble(),
        title: '$reviewed',
        radius: 50,
        titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: AppTheme.accentRed, // Due
        value: (due as num).toDouble(),
        title: '$due',
        radius: 60,
        titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: AppTheme.accentBlue, // New
        value: newWords.toDouble(),
        title: '$newWords',
        radius: 40,
        titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];

    return Card(
      color: AppTheme.darkSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(AppTheme.accentGreen, 'Öğrenilen'),
                _buildLegendItem(AppTheme.accentRed, 'Tekrar'),
                _buildLegendItem(AppTheme.accentBlue, 'Yeni'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard() {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.darkSurfaceVariant,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      rod.toY.round().toString() + ' XP',
                      const TextStyle(color: AppTheme.textPrimary),
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
                      const days = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];
                      if (value.toInt() >= 0 && value.toInt() < days.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            days[value.toInt()],
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: _weeklyActivity.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value,
                      color: AppTheme.primaryPurple,
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 100,
                        color: AppTheme.darkSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      color: AppTheme.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow('Toplam XP', '${_progressStats?.totalXp ?? 0}'),
            const Divider(color: Colors.white10),
            _buildDetailRow('Level', '${_progressStats?.level ?? 1}'),
            const Divider(color: Colors.white10),
            _buildDetailRow('En Uzun Seri', '${_progressStats?.longestStreak ?? 0} gün'),
            const Divider(color: Colors.white10),
            _buildDetailRow('Toplam Kelime', '${_srsStats?.totalWords ?? 0}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
