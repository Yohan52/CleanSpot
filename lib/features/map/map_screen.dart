import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/theme_proposal.dart';
import '../profile/widgets/widgets.dart';
import 'models/map_report.dart';
import 'services/map_service.dart';
import 'widgets/report_detail_sheet.dart';
import 'widgets/risk_legend.dart';

/// CleanSpot Live Risk Map Screen
///
/// Features:
/// - Real Google Maps integration with Colombo center
/// - Live stream of valid reports from Firestore (`reports` collection where `status == "valid"`)
/// - Heatmap layer with custom gradient & radius
/// - Density circles fallback / enhancement
/// - Interactive Markers with bottom sheet detail viewer
/// - Time filter chips (Last 7 days / 30 days / All time)
/// - One-tap Colombo demo data seed tool for testing
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapService _mapService = MapService();
  GoogleMapController? _mapController;

  static const LatLng _colomboCenter = LatLng(6.9271, 79.8612);

  String _viewMode = 'heatmap'; // 'heatmap' | 'markers'
  String _timeRange = '7d'; // '7d' | '30d' | 'all'
  MapReport? _selectedReport;
  bool _isSeeding = false;

  StreamSubscription<List<MapReport>>? _reportsSub;
  List<MapReport> _liveReports = [];
  bool _hasLoadedFromFirestore = false;

  @override
  void initState() {
    super.initState();
    _subscribeToReports();
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _subscribeToReports() {
    _reportsSub = _mapService.streamValidReports().listen(
      (reports) {
        if (mounted) {
          setState(() {
            _liveReports = reports;
            _hasLoadedFromFirestore = true;
            if (_selectedReport == null && reports.isNotEmpty) {
              _selectedReport = reports.first;
            }
          });
        }
      },
      onError: (err) {
        debugPrint('MapScreen: Firestore stream error ($err). Using fallback.');
        if (mounted) {
          setState(() {
            _hasLoadedFromFirestore = true;
          });
        }
      },
    );
  }

  /// Active list of reports: uses live Firestore reports when available,
  /// otherwise seamlessly falls back to 25 curated Colombo reports.
  List<MapReport> get _effectiveReports {
    if (_liveReports.isNotEmpty) {
      return _liveReports;
    }
    return MapService.fallbackColomboReports;
  }

  /// Reports filtered by the active time range (7d, 30d, all)
  List<MapReport> get _filteredReports {
    final all = _effectiveReports;
    switch (_timeRange) {
      case '7d':
        return all.where((r) => r.isWithinDays(7)).toList();
      case '30d':
        return all.where((r) => r.isWithinDays(30)).toList();
      case 'all':
      default:
        return all;
    }
  }

  Future<void> _seedDemoData() async {
    setState(() => _isSeeding = true);
    try {
      final count = await _mapService.seedColomboReports(force: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully seeded $count Colombo reports into Firestore!'),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to seed: $e'),
            backgroundColor: AppColors.errorText,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  void _onMarkerTapped(MapReport report) {
    setState(() {
      _selectedReport = report;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(report.latLng),
    );
    ReportDetailSheet.show(context, report);
  }

  /// Builds native Google Maps Heatmap set
  Set<Heatmap> _buildHeatmaps(List<MapReport> reports) {
    if (reports.isEmpty || _viewMode != 'heatmap') {
      return {};
    }

    final points = reports
        .map((r) => WeightedLatLng(r.latLng, weight: 1.0))
        .toList();

    return {
      Heatmap(
        heatmapId: const HeatmapId('dengue_risk_heatmap'),
        data: points,
        radius: const HeatmapRadius.fromPixels(45),
        gradient: const HeatmapGradient(
          [
            HeatmapGradientColor(Colors.green, 0.2),
            HeatmapGradientColor(Colors.yellow, 0.45),
            HeatmapGradientColor(Colors.orange, 0.7),
            HeatmapGradientColor(Colors.red, 0.95),
          ],
        ),
        opacity: 0.8,
      ),
    };
  }

  /// Builds density circles layer as visual enhancement & fallback
  /// sized and colored according to report clustering density
  Set<Circle> _buildDensityCircles(List<MapReport> reports) {
    if (_viewMode != 'heatmap') return {};

    final circles = <Circle>{};
    for (int i = 0; i < reports.length; i++) {
      final r = reports[i];

      // Estimate density: count neighbors within ~0.005 degrees (~500m)
      int clusterCount = 0;
      for (final other in reports) {
        final dLat = (r.lat - other.lat).abs();
        final dLng = (r.lng - other.lng).abs();
        if (dLat < 0.004 && dLng < 0.004) {
          clusterCount++;
        }
      }

      Color circleColor;
      double radius;
      if (clusterCount >= 3) {
        circleColor = Colors.red.withValues(alpha: 0.35);
        radius = 350;
      } else if (clusterCount == 2) {
        circleColor = Colors.orange.withValues(alpha: 0.30);
        radius = 260;
      } else {
        circleColor = Colors.teal.withValues(alpha: 0.22);
        radius = 180;
      }

      circles.add(
        Circle(
          circleId: CircleId('density_${r.id}'),
          center: r.latLng,
          radius: radius,
          fillColor: circleColor,
          strokeColor: circleColor.withValues(alpha: 0.75),
          strokeWidth: 1,
        ),
      );
    }
    return circles;
  }

  /// Builds interactive markers for marker view
  Set<Marker> _buildMarkers(List<MapReport> reports) {
    if (_viewMode != 'markers') return {};

    final markers = <Marker>{};
    for (final report in reports) {
      final isSelected = report.id == _selectedReport?.id;

      // Color coding marker pin by breeding site type
      double hue = BitmapDescriptor.hueRed;
      final lower = report.type.toLowerCase();
      if (lower.contains('water')) {
        hue = BitmapDescriptor.hueAzure;
      } else if (lower.contains('tyre')) {
        hue = BitmapDescriptor.hueOrange;
      } else if (lower.contains('drain')) {
        hue = BitmapDescriptor.hueRose;
      } else if (lower.contains('container')) {
        hue = BitmapDescriptor.hueViolet;
      }

      markers.add(
        Marker(
          markerId: MarkerId(report.id),
          position: report.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          zIndexInt: isSelected ? 2 : 1,
          infoWindow: InfoWindow(
            title: report.type,
            snippet: '${report.locationName} · ${report.formattedDate}',
            onTap: () => ReportDetailSheet.show(context, report),
          ),
          onTap: () => _onMarkerTapped(report),
        ),
      );
    }
    return markers;
  }

  Widget _buildViewModeToggle() {
    final isHeatmap = _viewMode == 'heatmap';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _viewMode = 'heatmap'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isHeatmap ? AppColors.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.blur_on,
                      size: 18,
                      color: isHeatmap ? AppColors.primaryDark : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Heatmap',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        fontWeight: isHeatmap ? FontWeight.bold : FontWeight.w500,
                        color: isHeatmap ? AppColors.primaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _viewMode = 'markers'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isHeatmap ? AppColors.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 18,
                      color: !isHeatmap ? AppColors.primaryDark : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Markers',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        fontWeight: !isHeatmap ? FontWeight.bold : FontWeight.w500,
                        color: !isHeatmap ? AppColors.primaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterChip(String label, String value, int count) {
    final isSelected = _timeRange == value;

    return InkWell(
      onTap: () => setState(() => _timeRange = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, MapReport report) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => ReportDetailSheet.show(context, report),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle pill
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 74,
                    height: 74,
                    color: AppColors.primaryLight,
                    child: report.imageUrl.isNotEmpty
                        ? Image.network(
                            report.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              report.typeIcon,
                              size: 32,
                              color: AppColors.primaryDark,
                            ),
                          )
                        : Icon(
                            report.typeIcon,
                            size: 32,
                            color: AppColors.primaryDark,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              report.type,
                              style: (textTheme.titleMedium ?? AppTypography.heading).copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.locationName,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.formattedDate,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Status Badge Chip
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Valid report · Verified',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Tap for details',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final allReports = _effectiveReports;
    final filtered = _filteredReports;

    // Filter counts
    final count7d = allReports.where((r) => r.isWithinDays(7)).length;
    final count30d = allReports.where((r) => r.isWithinDays(30)).length;
    final countAll = allReports.length;

    final selected = _selectedReport ?? (filtered.isNotEmpty ? filtered.first : null);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title, Live Status, Seeding Action
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Risk Map',
                          style: (textTheme.headlineMedium ?? AppTypography.title).copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Seed Colombo Data Tool
                      if (_isSeeding)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      else
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                          tooltip: 'Map Options',
                          onSelected: (val) {
                            if (val == 'seed') {
                              _seedDemoData();
                            } else if (val == 'recenter') {
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(_colomboCenter, 13.0),
                              );
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'recenter',
                              child: Row(
                                children: [
                                  Icon(Icons.my_location, size: 18, color: AppColors.primary),
                                  SizedBox(width: 10),
                                  Text('Recenter Colombo'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'seed',
                              child: Row(
                                children: [
                                  Icon(Icons.cloud_upload_outlined, size: 18, color: AppColors.primary),
                                  SizedBox(width: 10),
                                  Text('Seed 25 Colombo Reports'),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Status info note
                  InfoNote(
                    text: _liveReports.isNotEmpty
                        ? 'Live Firestore: ${_liveReports.length} verified breeding sites active'
                        : (_hasLoadedFromFirestore
                            ? 'Colombo demo data active · Tap menu (⋮) to seed Firestore'
                            : 'Connecting to CleanSpot live reports...'),
                  ),
                  const SizedBox(height: 12),

                  // Heatmap / Markers Toggle
                  _buildViewModeToggle(),
                  const SizedBox(height: 10),

                  // Time Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTimeFilterChip('Last 7 Days', '7d', count7d),
                        const SizedBox(width: 8),
                        _buildTimeFilterChip('Last 30 Days', '30d', count30d),
                        const SizedBox(width: 8),
                        _buildTimeFilterChip('All Time', 'all', countAll),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // Map Area (expands to take available space)
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _colomboCenter,
                      zoom: 12.8,
                    ),
                    onMapCreated: (ctrl) => _mapController = ctrl,
                    heatmaps: _buildHeatmaps(filtered),
                    circles: _buildDensityCircles(filtered),
                    markers: _buildMarkers(filtered),
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: true,
                    mapToolbarEnabled: false,
                  ),

                  // Floating Legend (top right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: RiskLegend(isHeatmap: _viewMode == 'heatmap'),
                  ),

                  // Recenter FAB (bottom right above detail card)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'recenter_fab',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primaryDark,
                      elevation: 3,
                      onPressed: () {
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(_colomboCenter, 13.0),
                        );
                      },
                      child: const Icon(Icons.my_location, size: 20),
                    ),
                  ),

                  // Heatmap/Density notification badge if active
                  if (_viewMode == 'heatmap')
                    Positioned(
                      left: 14,
                      top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.errorText,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${filtered.length} Heatmap Hotspots',
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Selected Incident Quick Preview Card
            if (selected != null) _buildDetailCard(context, selected),
          ],
        ),
      ),
    );
  }
}
