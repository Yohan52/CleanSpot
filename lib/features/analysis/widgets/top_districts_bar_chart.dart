import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme_proposal.dart';
import '../models/dengue_stat.dart';

/// Top 10 Districts by dengue cases this year, rendered with fl_chart BarChart.
class TopDistrictsBarChart extends StatelessWidget {
  final List<DistrictSummary> topDistricts;
  final String selectedDistrictName;
  final ValueChanged<String> onSelectDistrict;

  const TopDistrictsBarChart({
    super.key,
    required this.topDistricts,
    required this.selectedDistrictName,
    required this.onSelectDistrict,
  });

  String _shortenName(String name) {
    if (name.length <= 4) return name;
    switch (name) {
      case 'Colombo':
        return 'Col';
      case 'Gampaha':
        return 'Gam';
      case 'Kalutara':
        return 'Kal';
      case 'Kandy':
        return 'Kan';
      case 'Galle':
        return 'Gal';
      case 'Ratnapura':
        return 'Rat';
      case 'Kurunegala':
        return 'Kur';
      case 'Matara':
        return 'Mat';
      case 'Jaffna':
        return 'Jaf';
      case 'Badulla':
        return 'Bad';
      case 'Kegalle':
        return 'Keg';
      case 'Puttalam':
        return 'Put';
      default:
        return name.substring(0, 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (topDistricts.isEmpty) {
      return const SizedBox.shrink();
    }

    final top10 = topDistricts.take(10).toList();
    double maxCases = 1000;
    for (final d in top10) {
      if (d.totalCases > maxCases) maxCases = d.totalCases.toDouble();
    }
    // 15% headroom
    maxCases = (maxCases * 1.15).ceilToDouble();

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < top10.length; i++) {
      final d = top10[i];
      final isSelected = d.name.toLowerCase() == selectedDistrictName.toLowerCase();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: d.totalCases.toDouble(),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isSelected
                    ? [AppColors.warningText, Colors.orangeAccent]
                    : [AppColors.primaryDark, AppColors.primary],
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxCases,
                color: AppColors.background,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top 10 Districts by Cases',
                      style: (textTheme.titleLarge ?? AppTypography.heading).copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Cumulative 2024 records · Tap bar to inspect',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '2024 YTD',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Bar Chart View
          SizedBox(
            height: 190,
            width: double.infinity,
            child: BarChart(
              BarChartData(
                maxY: maxCases,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = top10[group.x];
                      return BarTooltipItem(
                        '#${group.x + 1} ${item.name}\n${item.totalCases} cases',
                        const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    if (event.isInterestedForInteractions &&
                        response != null &&
                        response.spot != null) {
                      final index = response.spot!.touchedBarGroupIndex;
                      if (index >= 0 && index < top10.length) {
                        onSelectDistrict(top10[index].name);
                      }
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: (maxCases / 3).roundToDouble(),
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(0)}k'
                              : value.toInt().toString(),
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.right,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= top10.length) return const SizedBox.shrink();
                        final d = top10[idx];
                        final isSel = d.name.toLowerCase() == selectedDistrictName.toLowerCase();

                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _shortenName(d.name),
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? AppColors.warningText : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxCases / 3).roundToDouble(),
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.6),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Horizontal quick tap list of top 5
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < min(5, top10.length); i++)
                  _buildRankPill(top10[i], i + 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankPill(DistrictSummary d, int rank) {
    final isSelected = d.name.toLowerCase() == selectedDistrictName.toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => onSelectDistrict(d.name),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.warningBg : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.warningText : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.warningText : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                d.name,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.warningText : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
