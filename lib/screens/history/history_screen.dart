// lib/screens/history/history_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../models/models.dart';
import '../../services/journey_service.dart';
import '../../services/auth_service.dart';
import '../../services/pdf_export_service.dart';
import '../../utils/app_theme.dart';
import '../auth/login_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _journeySvc = JourneyService();
  final _authSvc = AuthService();
  final _pdfSvc = PdfExportService();
  String _filter = 'all'; // all, completed, rated

  void _confirmDeleteAll(String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Clear All History', style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary)),
        content: Text('This will permanently delete all your journey records. This action cannot be undone.',
            style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              await _journeySvc.deleteAllJourneys(uid);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOne(Journey j) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Delete Journey', style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary)),
        content: Text('Delete the journey from ${j.startAddress} to ${j.endAddress}?',
            style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              await _journeySvc.deleteJourney(j.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showJourneyDetail(Journey j) {
    final routeColors = {'safest': AppTheme.safe, 'fastest': AppTheme.accentOrange, 'balanced': AppTheme.accent};
    final color = routeColors[j.routeType] ?? AppTheme.accent;
    final duration = j.endTime != null ? j.endTime!.difference(j.startTime) : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(AppConstants.routeTypeLabels[j.routeType] ?? j.routeType,
                style: GoogleFonts.spaceGrotesk(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(DateFormat('MMM d, yyyy').format(j.startTime), style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 20),
          _detailRow(Icons.radio_button_checked_rounded, AppTheme.safe, 'From', j.startAddress),
          const SizedBox(height: 12),
          _detailRow(Icons.location_on_rounded, AppTheme.accentOrange, 'To', j.endAddress),
          const SizedBox(height: 16),
          Row(children: [
            _infoChip(Icons.access_time_rounded, 'Started', DateFormat('h:mm a').format(j.startTime)),
            const SizedBox(width: 12),
            if (duration != null) _infoChip(Icons.timer_outlined, 'Duration', '${duration.inMinutes} min'),
            const SizedBox(width: 12),
            _infoChip(Icons.check_circle_outline, 'Status', j.isCompleted ? 'Completed' : 'In Progress'),
          ]),
          if (j.rating != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              Text('Your Rating: ', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 13)),
              RatingBarIndicator(rating: j.rating!, itemBuilder: (_, __) => const Icon(Icons.star, color: AppTheme.accentYellow), itemCount: 5, itemSize: 18),
              const SizedBox(width: 8),
              Text(j.rating!.toStringAsFixed(1), style: GoogleFonts.spaceGrotesk(color: AppTheme.accentYellow, fontWeight: FontWeight.w700)),
            ]),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () { Navigator.pop(ctx); _confirmDeleteOne(j); },
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
              label: Text('Delete Journey', style: GoogleFonts.spaceGrotesk(color: AppTheme.danger)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  Widget _detailRow(IconData icon, Color color, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 11)),
        Text(value, style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ])),
    ]);
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          Icon(icon, color: AppTheme.accent, size: 16),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(label, style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 9)),
        ]),
      ),
    );
  }

  List<Journey> _applyFilter(List<Journey> journeys) {
    switch (_filter) {
      case 'completed': return journeys.where((j) => j.isCompleted).toList();
      case 'rated': return journeys.where((j) => j.rating != null).toList();
      default: return journeys;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary,
      child: FutureBuilder(
          future: _authSvc.getCurrentAppUser(),
          builder: (ctx, userSnap) {
            final user = userSnap.data;
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
            }
            if (user == null) {
              return Center(child: Text('Sign in to view history', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)));
            }
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: AppTheme.primary,
                  floating: true, pinned: true, elevation: 0,
                  title: Text('Activity History', style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                  actions: [
                    StreamBuilder<List<Journey>>(
                      stream: _journeySvc.streamUserJourneys(user.uid),
                      builder: (_, jSnap) {
                        final journeys = jSnap.data ?? [];
                        return Row(mainAxisSize: MainAxisSize.min, children: [
                          StreamBuilder<Map<String, dynamic>>(
                            stream: _journeySvc.getJourneyStats(user.uid),
                            builder: (_, statsSnap) => IconButton(
                              onPressed: journeys.isEmpty ? null : () => _pdfSvc.exportJourneyReport(journeys: journeys, stats: statsSnap.data ?? {}, context: context),
                              icon: Icon(Icons.picture_as_pdf_outlined, color: journeys.isEmpty ? AppTheme.textSecondary : AppTheme.accentOrange),
                              tooltip: 'Export PDF',
                            ),
                          ),
                          IconButton(
                            onPressed: journeys.isEmpty ? null : () => _confirmDeleteAll(user.uid),
                            icon: Icon(Icons.delete_sweep_outlined, color: journeys.isEmpty ? AppTheme.textSecondary : AppTheme.danger, size: 22),
                            tooltip: 'Clear History',
                          ),
                        ]);
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                // Stats Section
                SliverToBoxAdapter(
                  child: StreamBuilder<Map<String, dynamic>>(
                    stream: _journeySvc.getJourneyStats(user.uid),
                    builder: (_, snap) {
                      if (!snap.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppTheme.accent)));
                      return _StatsSection(stats: snap.data!);
                    },
                  ),
                ),
                // Filter Chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Row(children: [
                      Text('Journeys', style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                      const Spacer(),
                      _FilterChip(label: 'All', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                      const SizedBox(width: 6),
                      _FilterChip(label: 'Completed', selected: _filter == 'completed', onTap: () => setState(() => _filter = 'completed')),
                      const SizedBox(width: 6),
                      _FilterChip(label: 'Rated', selected: _filter == 'rated', onTap: () => setState(() => _filter = 'rated')),
                    ]),
                  ),
                ),
                // Journey List
                StreamBuilder<List<Journey>>(
                  stream: _journeySvc.streamUserJourneys(user.uid),
                  builder: (ctx, snap) {
                    final allJourneys = snap.data ?? [];
                    final journeys = _applyFilter(allJourneys);
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.accent))));
                    }
                    if (journeys.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(child: Column(children: [
                            const Icon(Icons.route_outlined, color: AppTheme.textSecondary, size: 56),
                            const SizedBox(height: 12),
                            Text(allJourneys.isEmpty ? 'No journeys yet' : 'No matching journeys',
                                style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(allJourneys.isEmpty ? 'Start navigating to see your history' : 'Try a different filter',
                                style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 13)),
                          ])),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _JourneyCard(
                            journey: journeys[i],
                            onTap: () => _showJourneyDetail(journeys[i]),
                            onDismissed: () => _confirmDeleteOne(journeys[i]),
                          ),
                        ),
                        childCount: journeys.length,
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      );
    }
  }

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withOpacity(0.15) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
        ),
        child: Text(label, style: GoogleFonts.spaceGrotesk(color: selected ? AppTheme.accent : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final routeTypes = stats['routeTypes'] as Map<String, int>? ?? {};
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(child: _StatCard(label: 'Total', value: stats['total'].toString(), icon: Icons.route_rounded, color: AppTheme.accent)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'This Week', value: (stats['thisWeek'] ?? 0).toString(), icon: Icons.today_rounded, color: AppTheme.accentYellow)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'Avg Rating', value: (stats['avgRating'] as double?)?.toStringAsFixed(1) ?? '—', icon: Icons.star_rounded, color: AppTheme.accentOrange)),
        ]),
        if (routeTypes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Route Preferences', style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                child: PieChart(PieChartData(
                  sections: routeTypes.entries.map((e) {
                    final colors = {'safest': AppTheme.safe, 'fastest': AppTheme.accentOrange, 'balanced': AppTheme.accent};
                    return PieChartSectionData(value: e.value.toDouble(), color: colors[e.key] ?? AppTheme.textSecondary, title: e.key, titleStyle: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white), radius: 50);
                  }).toList(),
                  sectionsSpace: 2, centerSpaceRadius: 30,
                )),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 10)),
      ]),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final Journey journey;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  const _JourneyCard({required this.journey, required this.onTap, required this.onDismissed});

  @override
  Widget build(BuildContext context) {
    final routeColors = {'safest': AppTheme.safe, 'fastest': AppTheme.accentOrange, 'balanced': AppTheme.accent};
    final color = routeColors[journey.routeType] ?? AppTheme.accent;
    final duration = journey.endTime != null ? journey.endTime!.difference(journey.startTime) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(AppConstants.routeTypeLabels[journey.routeType] ?? journey.routeType, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            if (!journey.isCompleted) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Text('In Progress', style: GoogleFonts.spaceGrotesk(color: AppTheme.warning, fontSize: 9, fontWeight: FontWeight.w600)),
              ),
            ],
            const Spacer(),
            Text(DateFormat('MMM d, h:mm a').format(journey.startTime), style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          Row(children: [const Icon(Icons.radio_button_checked_rounded, color: AppTheme.safe, size: 14), const SizedBox(width: 8), Expanded(child: Text(journey.startAddress, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 12)))]),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.location_on_rounded, color: AppTheme.accentOrange, size: 14), const SizedBox(width: 8), Expanded(child: Text(journey.endAddress, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 12)))]),
          const SizedBox(height: 10),
          Row(children: [
            if (duration != null) ...[
              const Icon(Icons.timer_outlined, color: AppTheme.textSecondary, size: 13),
              const SizedBox(width: 4),
              Text('${duration.inMinutes} min', style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 11)),
              const SizedBox(width: 16),
            ],
            if (journey.rating != null) ...[
              RatingBarIndicator(rating: journey.rating!, itemBuilder: (_, __) => const Icon(Icons.star, color: AppTheme.accentYellow), itemCount: 5, itemSize: 14),
              const SizedBox(width: 6),
              Text(journey.rating!.toStringAsFixed(1), style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 11)),
            ],
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 18),
          ]),
        ]),
      ),
    );
  }
}
