import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/theme_proposal.dart';

/// Represents a mosquito breeding site report displayed on the Risk Map.
///
/// Matches the CleanSpot Firestore schema:
/// `reports/{id}`: uid, imageUrl, lat, lng, type, description, status, aiReason, createdAt
class MapReport {
  final String id;
  final String uid;
  final String imageUrl;
  final double lat;
  final double lng;
  final String type;
  final String description;
  final String status; // 'valid' | 'pending' | 'rejected'
  final String? aiReason;
  final DateTime createdAt;

  const MapReport({
    required this.id,
    required this.uid,
    required this.imageUrl,
    required this.lat,
    required this.lng,
    required this.type,
    required this.description,
    required this.status,
    this.aiReason,
    required this.createdAt,
  });

  /// Google Maps LatLng coordinate
  LatLng get latLng => LatLng(lat, lng);

  /// Helper to check if report is within [days] from now
  bool isWithinDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return createdAt.isAfter(cutoff);
  }

  /// Human-readable date text (e.g. '24 Oct 2026 · 2:30 PM')
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes.clamp(1, 60);
      return '$mins min ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hr${hours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days day${days > 1 ? 's' : ''} ago';
    }

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[createdAt.month - 1];
    final hour = createdAt.hour % 12 == 0 ? 12 : createdAt.hour % 12;
    final ampm = createdAt.hour >= 12 ? 'PM' : 'AM';
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '${createdAt.day} $m ${createdAt.year} · $hour:$minute $ampm';
  }

  /// Approximate Colombo neighborhood or formatted coordinates
  String get locationName {
    // Known landmark / neighborhood approximate bounds for Colombo
    if (lat >= 6.930 && lat <= 6.945 && lng >= 79.840 && lng <= 79.855) {
      return 'Colombo Fort / Pettah';
    } else if (lat >= 6.910 && lat <= 6.930 && lng >= 79.845 && lng <= 79.860) {
      return 'Kollupitiya / Galle Face';
    } else if (lat >= 6.895 && lat <= 6.915 && lng >= 79.850 && lng <= 79.865) {
      return 'Bambalapitiya';
    } else if (lat >= 6.870 && lat <= 6.895 && lng >= 79.855 && lng <= 79.870) {
      return 'Wellawatte';
    } else if (lat >= 6.900 && lat <= 6.920 && lng >= 79.865 && lng <= 79.880) {
      return 'Cinnamon Gardens (Colombo 7)';
    } else if (lat >= 6.910 && lat <= 6.935 && lng >= 79.870 && lng <= 79.890) {
      return 'Borella / Maradana';
    } else if (lat >= 6.890 && lat <= 6.920 && lng >= 79.880 && lng <= 79.910) {
      return 'Rajagiriya';
    } else if (lat >= 6.860 && lat <= 6.890 && lng >= 79.880 && lng <= 79.910) {
      return 'Nugegoda';
    } else if (lat >= 6.830 && lat <= 6.865 && lng >= 79.860 && lng <= 79.885) {
      return 'Dehiwala / Mount Lavinia';
    }
    return '${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E';
  }

  /// Icon representative of the breeding site type
  IconData get typeIcon {
    final lower = type.toLowerCase();
    if (lower.contains('water') || lower.contains('puddle')) {
      return Icons.water_drop_outlined;
    } else if (lower.contains('tyre') || lower.contains('tire')) {
      return Icons.album_outlined;
    } else if (lower.contains('drain') || lower.contains('gutter')) {
      return Icons.waves_outlined;
    } else if (lower.contains('container') || lower.contains('bottle') || lower.contains('bucket')) {
      return Icons.delete_outline;
    }
    return Icons.warning_amber_rounded;
  }

  /// Color associated with breeding site type
  Color get typeColor {
    final lower = type.toLowerCase();
    if (lower.contains('water')) {
      return Colors.blue.shade700;
    } else if (lower.contains('tyre')) {
      return Colors.brown.shade700;
    } else if (lower.contains('drain')) {
      return Colors.deepOrange.shade700;
    } else if (lower.contains('container')) {
      return Colors.purple.shade700;
    }
    return AppColors.warningText;
  }

  /// Factory parser supporting both clean schema and potential field variances
  factory MapReport.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MapReport.fromMap(doc.id, data);
  }

  factory MapReport.fromMap(String id, Map<String, dynamic> data) {
    // Lat / Lng parsing (handles doubles, ints, or GeoPoint)
    double parsedLat = 6.9271;
    double parsedLng = 79.8612;

    if (data['lat'] != null && data['lng'] != null) {
      parsedLat = (data['lat'] as num).toDouble();
      parsedLng = (data['lng'] as num).toDouble();
    } else if (data['location'] is GeoPoint) {
      final geo = data['location'] as GeoPoint;
      parsedLat = geo.latitude;
      parsedLng = geo.longitude;
    }

    // CreatedAt parsing (handles Timestamp, int ms, or ISO String)
    DateTime parsedDate = DateTime.now();
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      parsedDate = rawCreated.toDate();
    } else if (rawCreated is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else if (rawCreated is String) {
      parsedDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
    }

    return MapReport(
      id: id,
      uid: data['uid'] as String? ?? data['reporterId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? data['photoUrl'] as String? ?? '',
      lat: parsedLat,
      lng: parsedLng,
      type: data['type'] as String? ?? 'Stagnant water',
      description: data['description'] as String? ?? '',
      status: (data['status'] as String? ?? 'valid').toLowerCase(),
      aiReason: data['aiReason'] as String?,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'imageUrl': imageUrl,
      'lat': lat,
      'lng': lng,
      'type': type,
      'description': description,
      'status': status,
      if (aiReason != null) 'aiReason': aiReason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
