// lib/screens/reports/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/safety_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_theme.dart';
import 'add_report_screen.dart';
import 'package:latlong2/latlong.dart';
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _safetySvc = SafetyService();
  final _locationSvc = LocationService();
  String _filter = 'all';

  static const _reportTypes = [
    'all', 'harassment', 'theft', 'accident', 'lighting', 'other'
  ];

  static const Map<String, Color> _typeColors = {
    'harassment': Color(0xFFFF3B3B),
    'theft': Color(0xFFFF6B35),
    'accident': Color(0xFFFFD700),
    'lighting': Color(0xFF8B5CF6),
    'other': Color(0xFF64748B),
  };

  static const Map<String, IconData> _typeIcons = {
    'harassment': Icons.person_off_rounded,
    'theft': Icons.money_off_rounded,
    'accident': Icons.car_crash_rounded,
    'lighting': Icons.lightbulb_outlined,
    'other': Icons.warning_amber_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with immersion padding
          Padding(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 0),
              child: Row(
                children: [
                  Text('Safety Reports',
                      style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddReportScreen())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Report'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Filter chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _reportTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final type = _reportTypes[i];
                  final isSelected = _filter == type;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accent.withOpacity(0.15)
                            : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accent
                              : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        type == 'all'
                            ? 'All'
                            : type[0].toUpperCase() + type.substring(1),
                        style: GoogleFonts.spaceGrotesk(
                          color: isSelected
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Reports list
            Expanded(
              child: FutureBuilder<LatLng?>(
                future: _locationSvc.getCurrentLocation(),
                builder: (ctx, snap) {
                  final LatLng? loc = snap.data;
                  if (loc == null && snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: AppTheme.accent));
                  }
                  final center = loc ??
                      const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
                  return StreamBuilder<List<SafetyReport>>(
                    stream: _safetySvc.streamNearbyReports(center, radiusKm: 10),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.accent));
                      }
                      var reports = snap.data ?? [];
                      if (_filter != 'all') {
                        reports =
                            reports.where((r) => r.type == _filter).toList();
                      }
                      if (reports.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: AppTheme.safe, size: 56),
                              const SizedBox(height: 12),
                              Text('No reports in this area',
                                  style: GoogleFonts.spaceGrotesk(
                                      color: AppTheme.textSecondary,
                                      fontSize: 15)),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: reports.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _ReportCard(report: reports[i],
                              typeColor: _typeColors[reports[i].type] ??
                                  AppTheme.textSecondary,
                              typeIcon: _typeIcons[reports[i].type] ??
                                  Icons.warning_amber_rounded,
                              onUpvote: () =>
                                  _safetySvc.upvoteReport(reports[i].id),
                            ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
  }

class _ReportCard extends StatelessWidget {
  final SafetyReport report;
  final Color typeColor;
  final IconData typeIcon;
  final VoidCallback onUpvote;

  const _ReportCard({
    required this.report,
    required this.typeColor,
    required this.typeIcon,
    required this.onUpvote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, color: typeColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.typeLabel,
                        style: GoogleFonts.spaceGrotesk(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    Text(
                      DateFormat('MMM d, h:mm a').format(report.timestamp),
                      style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Severity
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Sev ${report.severity.toInt()}',
                    style: GoogleFonts.spaceGrotesk(
                        color: typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (report.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(report.description,
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_outline,
                  color: AppTheme.textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(report.userName,
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const Spacer(),
              if (report.isVerified)
                const Icon(Icons.verified_outlined,
                    color: AppTheme.safe, size: 16),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onUpvote,
                child: Row(
                  children: [
                    const Icon(Icons.thumb_up_outlined,
                        color: AppTheme.textSecondary, size: 16),
                    const SizedBox(width: 4),
                    Text('${report.upvotes}',
                        style: GoogleFonts.spaceGrotesk(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Placeholder for LatLng import

