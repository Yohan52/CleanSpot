import 'package:clean_spot/features/map/models/map_report.dart';
import 'package:clean_spot/features/map/services/map_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapReport Model Tests', () {
    test('Parses from Firestore schema map correctly', () {
      final now = DateTime.now();
      final map = {
        'uid': 'user_123',
        'imageUrl': 'https://example.com/site.jpg',
        'lat': 6.9271,
        'lng': 79.8612,
        'type': 'Stagnant water',
        'description': 'Puddle in back alley',
        'status': 'valid',
        'aiReason': 'Valid: high larval risk detected.',
        'createdAt': Timestamp.fromDate(now),
      };

      final report = MapReport.fromMap('doc_1', map);

      expect(report.id, 'doc_1');
      expect(report.uid, 'user_123');
      expect(report.imageUrl, 'https://example.com/site.jpg');
      expect(report.lat, 6.9271);
      expect(report.lng, 79.8612);
      expect(report.type, 'Stagnant water');
      expect(report.description, 'Puddle in back alley');
      expect(report.status, 'valid');
      expect(report.aiReason, 'Valid: high larval risk detected.');
      expect(report.createdAt.year, now.year);
      expect(report.latLng.latitude, 6.9271);
      expect(report.latLng.longitude, 79.8612);
    });

    test('Handles GeoPoint location and alternative field names gracefully', () {
      final map = {
        'reporterId': 'user_456',
        'photoUrl': 'https://example.com/tyre.jpg',
        'location': const GeoPoint(6.9147, 79.8540),
        'type': 'Tyres',
        'description': 'Old tyre pile',
        'status': 'VALID',
        'createdAt': DateTime(2026, 10, 20).toIso8601String(),
      };

      final report = MapReport.fromMap('doc_2', map);

      expect(report.uid, 'user_456');
      expect(report.imageUrl, 'https://example.com/tyre.jpg');
      expect(report.lat, 6.9147);
      expect(report.lng, 79.8540);
      expect(report.status, 'valid');
      expect(report.type, 'Tyres');
    });

    test('Serializes to map matching Firestore schema', () {
      final now = DateTime.now();
      final report = MapReport(
        id: 'doc_3',
        uid: 'user_789',
        imageUrl: 'https://example.com/drain.jpg',
        lat: 6.9344,
        lng: 79.8510,
        type: 'Blocked drain',
        description: 'Clogged gutter',
        status: 'valid',
        aiReason: 'Severe blockage',
        createdAt: now,
      );

      final map = report.toMap();

      expect(map['uid'], 'user_789');
      expect(map['imageUrl'], 'https://example.com/drain.jpg');
      expect(map['lat'], 6.9344);
      expect(map['lng'], 79.8510);
      expect(map['type'], 'Blocked drain');
      expect(map['description'], 'Clogged gutter');
      expect(map['status'], 'valid');
      expect(map['aiReason'], 'Severe blockage');
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('Time range filtering (7d, 30d)', () {
      final now = DateTime.now();
      final reportRecent = MapReport(
        id: 'recent',
        uid: 'u1',
        imageUrl: '',
        lat: 6.9,
        lng: 79.8,
        type: 'Stagnant water',
        description: '',
        status: 'valid',
        createdAt: now.subtract(const Duration(days: 3)),
      );

      final reportMedium = MapReport(
        id: 'medium',
        uid: 'u2',
        imageUrl: '',
        lat: 6.9,
        lng: 79.8,
        type: 'Stagnant water',
        description: '',
        status: 'valid',
        createdAt: now.subtract(const Duration(days: 15)),
      );

      final reportOld = MapReport(
        id: 'old',
        uid: 'u3',
        imageUrl: '',
        lat: 6.9,
        lng: 79.8,
        type: 'Stagnant water',
        description: '',
        status: 'valid',
        createdAt: now.subtract(const Duration(days: 45)),
      );

      // Within 7 days
      expect(reportRecent.isWithinDays(7), isTrue);
      expect(reportMedium.isWithinDays(7), isFalse);
      expect(reportOld.isWithinDays(7), isFalse);

      // Within 30 days
      expect(reportRecent.isWithinDays(30), isTrue);
      expect(reportMedium.isWithinDays(30), isTrue);
      expect(reportOld.isWithinDays(30), isFalse);
    });

    test('Colombo neighborhood resolution', () {
      final fortReport = MapReport(
        id: 'fort',
        uid: 'u',
        imageUrl: '',
        lat: 6.9350,
        lng: 79.8500,
        type: 'Blocked drain',
        description: '',
        status: 'valid',
        createdAt: DateTime.now(),
      );

      expect(fortReport.locationName, contains('Pettah'));
    });
  });

  group('MapService Colombo Data Tests', () {
    test('Fallback dataset has 25 realistic reports around Colombo', () {
      final reports = MapService.fallbackColomboReports;
      expect(reports.length, 25);

      for (final r in reports) {
        // Status must be valid
        expect(r.status, 'valid');
        // Latitude should be in Greater Colombo area (approx 6.8 to 7.0)
        expect(r.lat, greaterThan(6.8));
        expect(r.lat, lessThan(7.0));
        // Longitude should be in Greater Colombo area (approx 79.8 to 80.0)
        expect(r.lng, greaterThan(79.8));
        expect(r.lng, lessThan(80.0));
        // Must have non-empty photo URL, type, and AI reason
        expect(r.imageUrl, isNotEmpty);
        expect(r.type, isNotEmpty);
        expect(r.aiReason, isNotEmpty);
      }

      // Check distribution across time ranges
      final count7d = reports.where((r) => r.isWithinDays(7)).length;
      final count30d = reports.where((r) => r.isWithinDays(30)).length;
      final countAll = reports.length;

      expect(count7d, greaterThanOrEqualTo(5));
      expect(count30d, greaterThan(count7d));
      expect(countAll, greaterThan(count30d));
    });
  });
}
