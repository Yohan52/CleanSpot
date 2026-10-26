import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/map_report.dart';

/// Service responsible for streaming valid dengue breeding reports from Firestore
/// and providing seed / demo data around Colombo, Sri Lanka.
class MapService {
  final FirebaseFirestore _firestore;

  MapService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream valid reports from Firestore `reports` collection.
  Stream<List<MapReport>> streamValidReports() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: 'valid')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(MapReport.fromFirestore).toList();
      // Sort newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Check whether Firestore reports collection has any valid reports.
  Future<int> getValidReportsCount() async {
    try {
      final snap = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'valid')
          .get();
      return snap.docs.length;
    } catch (e) {
      debugPrint('MapService: Error getting reports count: $e');
      return 0;
    }
  }

  /// Seeds 25 authentic demo reports across Colombo for testing the heatmap and markers.
  /// As specified in Task Brief:
  /// "Until Maduranga's upload is merged, add 20–30 fake valid reports around Colombo by hand in the Firestore console to test."
  Future<int> seedColomboReports({bool force = false}) async {
    try {
      if (!force) {
        final existingCount = await getValidReportsCount();
        if (existingCount >= 15) {
          debugPrint('MapService: Already has $existingCount valid reports. Skipping seed.');
          return existingCount;
        }
      }

      final batch = _firestore.batch();
      final collection = _firestore.collection('reports');
      final reports = fallbackColomboReports;

      for (final r in reports) {
        final docRef = collection.doc('demo_colombo_${r.id}');
        batch.set(docRef, r.toMap(), SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('MapService: Successfully seeded ${reports.length} demo reports to Firestore.');
      return reports.length;
    } catch (e) {
      debugPrint('MapService: Seed failed ($e). Local fallback remains active.');
      rethrow;
    }
  }

  /// Realistic, curated dataset of 25 dengue breeding sites across Colombo.
  /// Dates span the last 35 days so the filter chips (7 days / 30 days / all time)
  /// behave dynamically and visibly change the report counts and clusters.
  static List<MapReport> get fallbackColomboReports {
    final now = DateTime.now();

    return [
      // --- Last 7 Days (Recent hotspots) ---
      MapReport(
        id: 'col-01',
        uid: 'user_col_01',
        imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=500&auto=format&fit=crop&q=80',
        lat: 6.9271,
        lng: 79.8612,
        type: 'Stagnant water',
        description: 'Large puddle formed near construction ditch along main walkway.',
        status: 'valid',
        aiReason: 'Valid: High risk stagnant puddle with visible mosquito breeding risk.',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      MapReport(
        id: 'col-02',
        uid: 'user_col_02',
        imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500&auto=format&fit=crop&q=80',
        lat: 6.9344,
        lng: 79.8510,
        type: 'Blocked drain',
        description: 'Roadside drainage clogged with debris and black water in Pettah.',
        status: 'valid',
        aiReason: 'Valid: Severe storm drain blockage with stagnant organic water.',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      MapReport(
        id: 'col-03',
        uid: 'user_col_03',
        imageUrl: 'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?w=500&auto=format&fit=crop&q=80',
        lat: 6.9147,
        lng: 79.8540,
        type: 'Containers',
        description: 'Discarded plastic bottles and food boxes accumulating rain in alley.',
        status: 'valid',
        aiReason: 'Valid: Open receptacles with trapped rainwater.',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      MapReport(
        id: 'col-04',
        uid: 'user_col_04',
        imageUrl: 'https://images.unsplash.com/photo-1578844251758-2f71da64c96f?w=500&auto=format&fit=crop&q=80',
        lat: 6.9180,
        lng: 79.8720,
        type: 'Tyres',
        description: 'Stack of 5 old tyres behind automobile workshop in Borella.',
        status: 'valid',
        aiReason: 'Valid: Exposed outdoor tyres holding rainwater.',
        createdAt: now.subtract(const Duration(days: 3, hours: 5)),
      ),
      MapReport(
        id: 'col-05',
        uid: 'user_col_05',
        imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=500&auto=format&fit=crop&q=80',
        lat: 6.9110,
        lng: 79.8650,
        type: 'Stagnant water',
        description: 'Uncovered ornamental garden fountain in residential premises.',
        status: 'valid',
        aiReason: 'Valid: Neglected stagnant water vessel.',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      MapReport(
        id: 'col-06',
        uid: 'user_col_06',
        imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500&auto=format&fit=crop&q=80',
        lat: 6.8990,
        lng: 79.8580,
        type: 'Blocked drain',
        description: 'School perimeter culvert backed up with silt and leaves.',
        status: 'valid',
        aiReason: 'Valid: Drainage blockage causing surface pooling.',
        createdAt: now.subtract(const Duration(days: 5, hours: 8)),
      ),
      MapReport(
        id: 'col-07',
        uid: 'user_col_07',
        imageUrl: 'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?w=500&auto=format&fit=crop&q=80',
        lat: 6.9050,
        lng: 79.8920,
        type: 'Containers',
        description: 'Cut plastic drums left open behind commercial warehouse.',
        status: 'valid',
        aiReason: 'Valid: Large volume container holding uncovered water.',
        createdAt: now.subtract(const Duration(days: 6)),
      ),

      // --- Last 30 Days (8 to 30 days ago) ---
      MapReport(
        id: 'col-08',
        uid: 'user_col_08',
        imageUrl: 'https://images.unsplash.com/photo-1578844251758-2f71da64c96f?w=500&auto=format&fit=crop&q=80',
        lat: 6.9290,
        lng: 79.8660,
        type: 'Tyres',
        description: 'Old truck tyres stored outdoors near rail yard.',
        status: 'valid',
        aiReason: 'Valid: Mosquito breeding hotspot detected.',
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      MapReport(
        id: 'col-09',
        uid: 'user_col_09',
        imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=500&auto=format&fit=crop&q=80',
        lat: 6.8830,
        lng: 79.8620,
        type: 'Stagnant water',
        description: 'Basement sump pump runoff creating green standing pool.',
        status: 'valid',
        aiReason: 'Valid: Stagnant pool with algae.',
        createdAt: now.subtract(const Duration(days: 11)),
      ),
      MapReport(
        id: 'col-10',
        uid: 'user_col_10',
        imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500&auto=format&fit=crop&q=80',
        lat: 6.8770,
        lng: 79.8680,
        type: 'Blocked drain',
        description: 'Canal exit culvert choked with plastic bags in Wellawatte.',
        status: 'valid',
        aiReason: 'Valid: Blocked wastewater drain.',
        createdAt: now.subtract(const Duration(days: 13)),
      ),
      MapReport(
        id: 'col-11',
        uid: 'user_col_11',
        imageUrl: 'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?w=500&auto=format&fit=crop&q=80',
        lat: 6.8520,
        lng: 79.8710,
        type: 'Containers',
        description: 'Discarded coconut shells and tins in empty property in Dehiwala.',
        status: 'valid',
        aiReason: 'Valid: Natural breeding containers holding rainwater.',
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      MapReport(
        id: 'col-12',
        uid: 'user_col_12',
        imageUrl: 'https://images.unsplash.com/photo-1578844251758-2f71da64c96f?w=500&auto=format&fit=crop&q=80',
        lat: 6.8450,
        lng: 79.8780,
        type: 'Tyres',
        description: 'Boat bumper tyres on seaside yard with pool inside rims.',
        status: 'valid',
        aiReason: 'Valid: Tyres holding rainwater near residential quarter.',
        createdAt: now.subtract(const Duration(days: 17)),
      ),
      MapReport(
        id: 'col-13',
        uid: 'user_col_13',
        imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=500&auto=format&fit=crop&q=80',
        lat: 6.9080,
        lng: 79.9010,
        type: 'Stagnant water',
        description: 'Water accumulation in vacant construction foundation in Rajagiriya.',
        status: 'valid',
        aiReason: 'Valid: Foundation pool exposed to monsoon rain.',
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      MapReport(
        id: 'col-14',
        uid: 'user_col_14',
        imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500&auto=format&fit=crop&q=80',
        lat: 6.8720,
        lng: 79.8950,
        type: 'Blocked drain',
        description: 'Covered slab broken and silt blocked in Nugegoda.',
        status: 'valid',
        aiReason: 'Valid: High larval risk drain blockage.',
        createdAt: now.subtract(const Duration(days: 22)),
      ),
      MapReport(
        id: 'col-15',
        uid: 'user_col_15',
        imageUrl: 'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?w=500&auto=format&fit=crop&q=80',
        lat: 6.9210,
        lng: 79.8830,
        type: 'Containers',
        description: 'Discarded paint buckets and metal drums on vacant lot.',
        status: 'valid',
        aiReason: 'Valid: Multiple open artificial receptacles.',
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      MapReport(
        id: 'col-16',
        uid: 'user_col_16',
        imageUrl: 'https://images.unsplash.com/photo-1578844251758-2f71da64c96f?w=500&auto=format&fit=crop&q=80',
        lat: 6.9380,
        lng: 79.8590,
        type: 'Tyres',
        description: 'Tire repair shop scrap piles along Kotahena border.',
        status: 'valid',
        aiReason: 'Valid: Dense tire cluster with trapped rainwater.',
        createdAt: now.subtract(const Duration(days: 28)),
      ),
      MapReport(
        id: 'col-17',
        uid: 'user_col_17',
        imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=500&auto=format&fit=crop&q=80',
        lat: 6.9420,
        lng: 79.8700,
        type: 'Stagnant water',
        description: 'Low-lying ground depression water accumulation in Grandpass.',
        status: 'valid',
        aiReason: 'Valid: Stagnant ponding in residential precinct.',
        createdAt: now.subtract(const Duration(days: 29)),
      ),

      // --- All Time (Over 30 days ago, for historical comparisons) ---
      MapReport(
        id: 'col-18',
        uid: 'user_col_18',
        imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500&auto=format&fit=crop&q=80',
        lat: 6.9250,
        lng: 79.8750,
        type: 'Blocked drain',
        description: 'Old masonry drainage blocked during road paving works.',
        status: 'valid',
        aiReason: 'Valid: Historic clogged drain site.',
        createdAt: now.subtract(const Duration(days: 35)),
      ),
      MapReport(
        id: 'col-19',
        uid: 'user_col_19',
        imageUrl: 'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?w=500&auto=format&fit=crop&q=80',
        lat: 6.9020,
        lng: 79.8710,
        type: 'Containers',
        description: 'Abandoned roof gutter collector in Cinnamon Gardens.',
        status: 'valid',
        aiReason: 'Valid: Open water collector with stagnant water.',
        createdAt: now.subtract(const Duration(days: 38)),
      ),
      MapReport(
        id: 'col-20',
        uid: 'user_col_20',
        imageUrl: 'https://images.unsplash.com/photo-1578844251758-2f71da64c96f?w=500&auto=format&fit=crop&q=80',
        lat: 6.8920,
        lng: 79.8820,
        type: 'Tyres',
        description: 'Scrap vehicle yard tyres in Kirulapone.',
        status: 'valid',
        aiReason: 'Valid: Open air tyre storage.',
        createdAt: now.subtract(const Duration(days: 42)),
      ),
      MapReport(
        id: 'col-21',
        uid: 'user_col_21',
        imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=500&auto=format&fit=crop&q=80',
        lat: 6.9160,
        lng: 79.8600,
        type: 'Stagnant water',
        description: 'Air conditioner condensation overflow puddle in Kollupitiya lane.',
        status: 'valid',
        aiReason: 'Valid: Persistent clear water pooling.',
        createdAt: now.subtract(const Duration(days: 45)),
      ),
      MapReport(
        id: 'col-22',
        uid: 'user_col_22',
        imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500&auto=format&fit=crop&q=80',
        lat: 6.9320,
        lng: 79.8480,
        type: 'Blocked drain',
        description: 'Harbour road gutter with solid waste accumulation.',
        status: 'valid',
        aiReason: 'Valid: Solid waste blocking water outflow.',
        createdAt: now.subtract(const Duration(days: 50)),
      ),
      MapReport(
        id: 'col-23',
        uid: 'user_col_23',
        imageUrl: 'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?w=500&auto=format&fit=crop&q=80',
        lat: 6.8850,
        lng: 79.8860,
        type: 'Containers',
        description: 'Polyethylene tanks left open on demolition site in Narahenpita.',
        status: 'valid',
        aiReason: 'Valid: Open industrial container.',
        createdAt: now.subtract(const Duration(days: 55)),
      ),
      MapReport(
        id: 'col-24',
        uid: 'user_col_24',
        imageUrl: 'https://images.unsplash.com/photo-1578844251758-2f71da64c96f?w=500&auto=format&fit=crop&q=80',
        lat: 6.8610,
        lng: 79.8730,
        type: 'Tyres',
        description: 'Plant nursery boundary tyres filled with muddy water.',
        status: 'valid',
        aiReason: 'Valid: Submerged debris inside tyre hollows.',
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      MapReport(
        id: 'col-25',
        uid: 'user_col_25',
        imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=500&auto=format&fit=crop&q=80',
        lat: 6.9450,
        lng: 79.8650,
        type: 'Stagnant water',
        description: 'Flooded vacant compound near Kelani river flood gate.',
        status: 'valid',
        aiReason: 'Valid: High severity seasonal stagnant water.',
        createdAt: now.subtract(const Duration(days: 65)),
      ),
    ];
  }
}
