import 'package:flutter/material.dart';

import '../../../app/theme_proposal.dart';

/// Floating or docked risk legend displaying color indicators for risk levels & breeding types.
class RiskLegend extends StatelessWidget {
  final bool isHeatmap;

  const RiskLegend({
    super.key,
    required this.isHeatmap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isHeatmap ? _buildHeatmapLegend() : _buildMarkerLegend(),
    );
  }

  Widget _buildHeatmapLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Risk Density:',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        // Gradient color bar
        Container(
          width: 80,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [
                Colors.green,
                Colors.yellow,
                Colors.orange,
                Colors.red,
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Low',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const Text(
          ' → ',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const Text(
          'High',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.errorText,
          ),
        ),
      ],
    );
  }

  Widget _buildMarkerLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendDot(Colors.blue.shade700, 'Water'),
        const SizedBox(width: 10),
        _buildLegendDot(Colors.brown.shade700, 'Tyres'),
        const SizedBox(width: 10),
        _buildLegendDot(Colors.deepOrange.shade700, 'Drains'),
        const SizedBox(width: 10),
        _buildLegendDot(Colors.purple.shade700, 'Containers'),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
