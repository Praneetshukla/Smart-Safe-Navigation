// lib/widgets/route_panel.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';

class RoutePanel extends StatelessWidget {
  final List<SafeRoute> routes;
  final SafeRoute? selected;
  final ValueChanged<SafeRoute> onSelectRoute;
  final VoidCallback onStartNavigation;
  final VoidCallback onClose;

  const RoutePanel({
    super.key,
    required this.routes,
    required this.selected,
    required this.onSelectRoute,
    required this.onStartNavigation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: AppTheme.glassDecoration(
            opacity: 0.7,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          // Drag handle
          Row(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
              Text('Choose Route',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Route options
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: routes
                  .where((r) => r.type != 'preview')
                  .map((r) => _RouteCard(
                    route: r,
                    isSelected: r.id == selected?.id,
                    onTap: () => onSelectRoute(r),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Safety Analytics Chart
          if (selected != null) ...[
            _SafetyAnalyticsChart(route: selected!),
            const SizedBox(height: 12),
            _AiRouteSummary(route: selected!),
          ],
          const SizedBox(height: 12),
          // Safety warnings
          if (selected?.hazardWarnings.isNotEmpty == true)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hazards: ${selected!.hazardWarnings.join(", ")}',
                      style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          // Start button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: selected != null ? onStartNavigation : null,
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: Text('Start Navigation',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
   ),
  );
 }
}

class _RouteCard extends StatelessWidget {
  final SafeRoute route;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteCard({required this.route, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final safetyColor = AppConstants.safetyColor(route.safetyScore);
    final icons = {
      'safest': Icons.shield_rounded,
      'fastest': Icons.flash_on_rounded,
      'balanced': Icons.balance_rounded,
      'safest_fastest': Icons.auto_awesome,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? LinearGradient(
                  colors: [safetyColor.withOpacity(0.2), safetyColor.withOpacity(0.05)],
                  begin: Alignment.topLeft, 
                  end: Alignment.bottomRight) 
              : null,
          color: isSelected ? null : AppTheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? safetyColor : AppTheme.border.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: safetyColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icons[route.type] ?? Icons.route_rounded,
                    color: safetyColor, size: 20),
                Text(
                  route.safetyScore.toStringAsFixed(1),
                  style: GoogleFonts.spaceGrotesk(
                      color: safetyColor, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            const Spacer(),
            Text(
              AppConstants.routeTypeLabels[route.type] ?? route.type,
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${(route.distanceKm).toStringAsFixed(1)}km · ${(route.durationSeconds ~/ 60)}m',
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textSecondary, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyAnalyticsChart extends StatelessWidget {
  final SafeRoute route;
  const _SafetyAnalyticsChart({required this.route});

  @override
  Widget build(BuildContext context) {
    final contributions = route.safetyFeatures?.getContributions() ?? [];
    if (contributions.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppTheme.textSecondary, size: 12),
              const SizedBox(width: 6),
              Text('Safety Risk Profile', 
                style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: contributions.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.contribution);
                    }).toList(),
                    isCurved: true,
                    color: AppConstants.safetyColor(route.safetyScore),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppConstants.safetyColor(route.safetyScore).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: -3,
                maxY: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Safety Chip ─────────────────────────────────────────────────────────────
// lib/widgets/safety_chip.dart
class SafetyChip extends StatelessWidget {
  final double score;
  const SafetyChip({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = AppConstants.safetyColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            'Area Safety: ${score.toStringAsFixed(1)}/10',
            style: GoogleFonts.spaceGrotesk(
                color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Hazard Marker ────────────────────────────────────────────────────────────
// lib/widgets/hazard_marker.dart
class HazardMarker extends StatelessWidget {
  final SafetyReport report;
  const HazardMarker({super.key, required this.report});

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
    final color = _typeColors[report.type] ?? AppTheme.warning;
    final icon = _typeIcons[report.type] ?? Icons.warning_amber_rounded;
    return GestureDetector(
      onTap: () => _showTooltip(context, color),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)],
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  void _showTooltip(BuildContext context, Color color) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(report.typeLabel,
            style: GoogleFonts.spaceGrotesk(
                color: color, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.description.isNotEmpty)
              Text(report.description,
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('Severity: ${report.severity.toInt()}/5',
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textSecondary, fontSize: 12)),
            Text('Reported by: ${report.userName}',
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

// ─── Search Bar Widget ────────────────────────────────────────────────────────
// lib/widgets/search_bar_widget.dart
class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final bool isNavigating;
  final VoidCallback onStopNavigation;

  const SearchBarWidget({
    super.key,
    required this.onSearch,
    required this.isNavigating,
    required this.onStopNavigation,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (widget.isNavigating) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.navigation_rounded, color: AppTheme.accent, size: 18),
            const SizedBox(width: 10),
            Text('Navigating…',
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const Spacer(),
            GestureDetector(
              onTap: widget.onStopNavigation,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                ),
                child: Text('Stop',
                    style: GoogleFonts.spaceGrotesk(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2), blurRadius: 12)
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded,
              color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Where do you want to go?',
                hintStyle: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textSecondary, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (v) {
                if (v.isNotEmpty) widget.onSearch(v);
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                setState(() {});
              },
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.close_rounded,
                    color: AppTheme.textSecondary, size: 18),
              ),
            ),
          GestureDetector(
            onTap: () {
              if (_ctrl.text.isNotEmpty) widget.onSearch(_ctrl.text);
            },
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: AppTheme.primary, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
class _AiRouteSummary extends StatelessWidget {
  final SafeRoute route;
  const _AiRouteSummary({required this.route});

  @override
  Widget build(BuildContext context) {
    final summary = _generateSummary();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassDecoration(
        opacity: 0.3,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary,
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textPrimary.withOpacity(0.9),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _generateSummary() {
    final contributions = route.safetyFeatures?.getContributions() ?? [];
    if (contributions.isEmpty) return "AI analysis pending for this route.";

    final positive = contributions.where((c) => c.contribution > 0.5).toList();
    final negative = contributions.where((c) => c.contribution < -0.5).toList();

    String txt = "";
    if (positive.isNotEmpty) {
      final best = positive.first;
      if (best.label.toLowerCase().contains("lighting")) {
        txt = "Recommended: Well-lit paths verified by AI analysis.";
      } else if (best.label.toLowerCase().contains("crime")) {
        txt = "Safest option: High historical safety data for this segment.";
      } else {
        txt = "Optimized for safety: ${best.label} is particularly strong here.";
      }
    } else if (negative.isNotEmpty) {
      txt = "Caution advised: Some segments have lower historical safety ratings.";
    } else {
      txt = "Balanced choice: Standard safety conditions along this route.";
    }

    return txt;
  }
}
