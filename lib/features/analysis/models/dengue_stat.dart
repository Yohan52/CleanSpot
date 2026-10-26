import 'package:flutter/material.dart';

/// Represents a single historical weekly dengue case report.
/// Matches Firestore collection `dengue_stats` schema:
/// fields: `district`, `year`, `week`, `cases`
class DengueStatRecord {
  final String district;
  final int year;
  final int week;
  final int cases;

  const DengueStatRecord({
    required this.district,
    required this.year,
    required this.week,
    required this.cases,
  });

  factory DengueStatRecord.fromCsvLine(String line) {
    final parts = line.split(',');
    if (parts.length < 4) {
      throw FormatException('Invalid CSV line: $line');
    }
    return DengueStatRecord(
      district: parts[0].trim(),
      year: int.tryParse(parts[1].trim()) ?? 2024,
      week: int.tryParse(parts[2].trim()) ?? 1,
      cases: int.tryParse(parts[3].trim()) ?? 0,
    );
  }

  factory DengueStatRecord.fromMap(Map<String, dynamic> map) {
    return DengueStatRecord(
      district: map['district'] as String? ?? '',
      year: (map['year'] as num?)?.toInt() ?? 2024,
      week: (map['week'] as num?)?.toInt() ?? 1,
      cases: (map['cases'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'district': district,
      'year': year,
      'week': week,
      'cases': cases,
    };
  }
}

/// Aggregated yearly metrics for a specific district.
class DistrictSummary {
  final String name;
  final int totalCases;
  final List<DengueStatRecord> records;
  final int peakWeek;
  final int peakCases;
  final double averageWeekly;

  const DistrictSummary({
    required this.name,
    required this.totalCases,
    required this.records,
    required this.peakWeek,
    required this.peakCases,
    required this.averageWeekly,
  });

  factory DistrictSummary.fromRecords(String name, List<DengueStatRecord> records) {
    // Sort chronologically by week
    final sorted = List<DengueStatRecord>.from(records)
      ..sort((a, b) => a.week.compareTo(b.week));

    int total = 0;
    int maxCases = 0;
    int peakW = 1;

    for (final r in sorted) {
      total += r.cases;
      if (r.cases > maxCases) {
        maxCases = r.cases;
        peakW = r.week;
      }
    }

    final avg = sorted.isEmpty ? 0.0 : total / sorted.length;

    return DistrictSummary(
      name: name,
      totalCases: total,
      records: sorted,
      peakWeek: peakW,
      peakCases: maxCases,
      averageWeekly: avg,
    );
  }
}

/// Curated expert insight on dengue spikes, weather patterns,
/// and municipal service disruptions, with verifiable sources.
class AnalysisInsight {
  final String id;
  final String title;
  final String area;
  final String timeframe;
  final String description;
  final String impactBadge; // 'High Impact' | 'Monsoon Pattern' | 'Intervention'
  final Color badgeColor;
  final String source;
  final String sourceUrl;

  const AnalysisInsight({
    required this.id,
    required this.title,
    required this.area,
    required this.timeframe,
    required this.description,
    required this.impactBadge,
    required this.badgeColor,
    required this.source,
    required this.sourceUrl,
  });
}
