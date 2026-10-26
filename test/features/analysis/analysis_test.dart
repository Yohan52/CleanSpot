import 'package:clean_spot/features/analysis/models/dengue_stat.dart';
import 'package:clean_spot/features/analysis/services/analysis_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DengueStatRecord Model Tests', () {
    test('Parses CSV line correctly', () {
      const line = 'Colombo,2024,24,1388';
      final record = DengueStatRecord.fromCsvLine(line);

      expect(record.district, 'Colombo');
      expect(record.year, 2024);
      expect(record.week, 24);
      expect(record.cases, 1388);
    });

    test('Serializes to map matching Firestore dengue_stats schema', () {
      const record = DengueStatRecord(
        district: 'Gampaha',
        year: 2024,
        week: 12,
        cases: 450,
      );

      final map = record.toMap();

      expect(map['district'], 'Gampaha');
      expect(map['year'], 2024);
      expect(map['week'], 12);
      expect(map['cases'], 450);

      final fromMap = DengueStatRecord.fromMap(map);
      expect(fromMap.district, 'Gampaha');
      expect(fromMap.year, 2024);
      expect(fromMap.week, 12);
      expect(fromMap.cases, 450);
    });
  });

  group('DistrictSummary Aggregation Tests', () {
    test('Calculates total, peak, and average correctly', () {
      final records = [
        const DengueStatRecord(district: 'Colombo', year: 2024, week: 1, cases: 100),
        const DengueStatRecord(district: 'Colombo', year: 2024, week: 2, cases: 350),
        const DengueStatRecord(district: 'Colombo', year: 2024, week: 3, cases: 150),
      ];

      final summary = DistrictSummary.fromRecords('Colombo', records);

      expect(summary.name, 'Colombo');
      expect(summary.totalCases, 600);
      expect(summary.peakWeek, 2);
      expect(summary.peakCases, 350);
      expect(summary.averageWeekly, 200.0);
    });
  });

  group('AnalysisService Data Processing Tests', () {
    test('Loads records from bundled CSV asset', () async {
      final service = AnalysisService();
      final records = await service.loadRecordsFromCsvAsset();

      expect(records, isNotEmpty);
      expect(records.length, 800); // 25 districts * 32 weeks

      final summaries = service.getDistrictSummaries(records);
      expect(summaries.length, 25);
      expect(summaries.containsKey('Colombo'), isTrue);
      expect(summaries.containsKey('Kandy'), isTrue);
      expect(summaries.containsKey('Jaffna'), isTrue);

      final top10 = service.getTop10Districts(records);
      expect(top10.length, 10);
      expect(top10.first.name, 'Colombo'); // Colombo is #1 in dengue cases
      expect(top10.first.totalCases, greaterThan(top10[1].totalCases));
    });

    test('Curated insights include sources and garbage disruption note', () {
      final insights = AnalysisService.getCuratedInsights();
      expect(insights.length, 6);

      final garbageInsight = insights.firstWhere((i) => i.id == 'ins-02');
      expect(garbageInsight.title, contains('Garbage Disruption'));
      expect(garbageInsight.description, contains('1,388 cases'));
      expect(garbageInsight.source, contains('Colombo Municipal Council'));
      expect(garbageInsight.sourceUrl, isNotEmpty);

      for (final ins in insights) {
        expect(ins.title, isNotEmpty);
        expect(ins.area, isNotEmpty);
        expect(ins.source, isNotEmpty);
        expect(ins.sourceUrl, isNotEmpty);
      }
    });
  });
}
