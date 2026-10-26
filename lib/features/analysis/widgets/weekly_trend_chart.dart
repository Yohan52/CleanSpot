import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme_proposal.dart';
import '../models/dengue_stat.dart';

/// Interactive weekly dengue cases trend line chart built with fl_chart.
class WeeklyTrendChart extends StatelessWidget {
  final DistrictSummary district;
  final int? liveCommunityReports;

  const WeeklyTrendChart({
    super.key,
    required this.district,
    this.liveCommunityReports,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final records = district.records;

    if (records.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('No data points available for this district.'),
      );
    }

    final spots = records
        .map((r) => FlSpot(r.week.toDouble(), r.cases.toDouble()))
        .toList();

    double maxY = 100;
    for (final r in records) {
      if (r.cases > maxY) maxY = r.cases.toDouble();
    }
    // Add 15% headroom
    maxY = (maxY * 1.15).ceilToDouble();

    final maxWeek = records.last.week.toDouble();

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
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${district.name} — Weekly Case Trend',
                      style: (textTheme.titleLarge ?? AppTypography.heading).copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Epidemiology Unit · 2024 (Weeks 1–${records.length})',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Peak badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warningText.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Peak: Wk ${district.peakWeek}',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warningText,
                      ),
                    ),
                    Text(
                      '${district.peakCases} cases',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10,
                        color: AppColors.warningText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Line Chart View
          SizedBox(
            height: 190,
            width: double.infinity,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: maxWeek,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: max(1, (maxY / 4).roundToDouble()),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.6),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: max(1, (maxY / 4).roundToDouble()),
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
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
                      reservedSize: 24,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        final val = value.toInt();
                        if (val < 1 || val > maxWeek) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'W$val',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textPrimary,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          'Week ${spot.x.toInt()}\n${spot.y.toInt()} cases',
                          const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) {
                        // Highlight peak spot
                        return spot.y == district.peakCases.toDouble();
                      },
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: AppColors.errorText,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.28),
                          AppColors.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Bottom Stats Footnote: Average cases & Live reports overlay
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.show_chart, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Avg: ${district.averageWeekly.toStringAsFixed(0)} cases/wk',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (liveCommunityReports != null && liveCommunityReports! > 0) ...[
                  const Icon(Icons.place, size: 15, color: AppColors.primaryDark),
                  const SizedBox(width: 4),
                  Text(
                    '$liveCommunityReports active community reports',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
