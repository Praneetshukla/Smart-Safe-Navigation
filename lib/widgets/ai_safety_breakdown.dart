// lib/widgets/ai_safety_breakdown.dart
//
// Animated widget showing per-feature safety contributions and AI confidence.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/safety_features.dart';
import '../ai/rl_agent.dart';
import '../ai/feature_discretizer.dart';
import '../ai/safety_scorer.dart';
import '../utils/app_theme.dart';

class AiSafetyBreakdown extends StatefulWidget {
  final SafetyFeatureVector features;
  final double safetyScore;
  final int rlAction;
  final DiscreteState? rlState;

  const AiSafetyBreakdown({
    super.key,
    required this.features,
    required this.safetyScore,
    this.rlAction = 0,
    this.rlState,
  });

  @override
  State<AiSafetyBreakdown> createState() => _AiSafetyBreakdownState();
}

class _AiSafetyBreakdownState extends State<AiSafetyBreakdown>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contributions = widget.features.getContributions();
    final confidence = SafetyScorer.computeConfidence(widget.features);
    final rlAgent = RLAgent();
    final rlConfidence =
        widget.rlState != null ? rlAgent.getConfidence(widget.rlState!) : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: AppTheme.glassDecoration(
            opacity: 0.5,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
          // ── Header ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.psychology_rounded,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Safety Analysis',
                            style: GoogleFonts.spaceGrotesk(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        Text(
                          _getActionSummary(),
                          style: GoogleFonts.spaceGrotesk(
                              color: AppTheme.textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  // Confidence badge
                  _ConfidenceBadge(confidence: confidence),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded,
                        color: AppTheme.textSecondary, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable content ──────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Column(
              children: [
                const Divider(color: AppTheme.border, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Column(
                    children: [
                      // Feature bars
                      ...contributions.map((c) => _FeatureBar(contribution: c)),

                      const SizedBox(height: 10),
                      const Divider(color: AppTheme.border, height: 1),
                      const SizedBox(height: 10),

                      // RL status
                      _RLStatusRow(
                        rlAction: widget.rlAction,
                        rlState: widget.rlState,
                        rlConfidence: rlConfidence,
                        episodes: rlAgent.totalEpisodes,
                      ),

                      const SizedBox(height: 8),

                      // Data sources info
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppTheme.textSecondary, size: 12),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Data: NCRB Crime Stats · OSM Infrastructure · '
                              'Community Reports · Live Environment',
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppTheme.textSecondary, fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
   ),
  );
}

  String _getActionSummary() {
    final action = RLAgent.actionLabel(widget.rlAction);
    if (widget.rlState != null) {
      return '$action · ${FeatureDiscretizer.describeState(widget.rlState!)}';
    }
    return action;
  }
}

// ─── Feature Bar ─────────────────────────────────────────────────────────────
class _FeatureBar extends StatelessWidget {
  final FeatureContribution contribution;

  const _FeatureBar({required this.contribution});

  @override
  Widget build(BuildContext context) {
    final isPositive = contribution.contribution >= 0;
    final color = isPositive ? AppTheme.safe : AppTheme.danger;
    final barWidth = contribution.contribution.abs().clamp(0.0, 2.0) / 2.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              contribution.label,
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textSecondary, fontSize: 10),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final half = maxW / 2;
                return Stack(
                  children: [
                    // Center line
                    Positioned(
                      left: half - 0.5,
                      top: 0,
                      bottom: 0,
                      child: Container(
                          width: 1, color: AppTheme.border.withOpacity(0.5)),
                    ),
                    // Background
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Bar
                    Positioned(
                      left: isPositive ? half : half - (half * barWidth),
                      top: 2,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        width: half * barWidth,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${isPositive ? "+" : ""}${contribution.contribution.toStringAsFixed(1)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceGrotesk(
                  color: color, fontWeight: FontWeight.w700, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Confidence Badge ────────────────────────────────────────────────────────
class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    final color = confidence >= 0.7
        ? AppTheme.safe
        : confidence >= 0.4
            ? AppTheme.warning
            : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$pct%',
        style: GoogleFonts.spaceGrotesk(
            color: color, fontWeight: FontWeight.w700, fontSize: 10),
      ),
    );
  }
}

// ─── RL Status Row ───────────────────────────────────────────────────────────
class _RLStatusRow extends StatelessWidget {
  final int rlAction;
  final DiscreteState? rlState;
  final double rlConfidence;
  final int episodes;

  const _RLStatusRow({
    required this.rlAction,
    required this.rlState,
    required this.rlConfidence,
    required this.episodes,
  });

  @override
  Widget build(BuildContext context) {
    final isLearning = episodes < 10;
    final statusColor = isLearning
        ? const Color(0xFF6366F1)
        : AppTheme.safe;

    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            isLearning ? Icons.model_training : Icons.auto_awesome,
            color: statusColor,
            size: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLearning
                    ? 'AI Learning ($episodes/10 journeys)'
                    : 'AI Personalised (${episodes} journeys)',
                style: GoogleFonts.spaceGrotesk(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10),
              ),
              Text(
                isLearning
                    ? 'Rate your journeys to help the AI learn your preferences'
                    : 'Route scoring is personalised based on your feedback',
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textSecondary, fontSize: 9),
              ),
            ],
          ),
        ),
        if (!isLearning)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppTheme.safe, size: 10),
                const SizedBox(width: 3),
                Text('Active',
                    style: GoogleFonts.spaceGrotesk(
                        color: AppTheme.safe,
                        fontWeight: FontWeight.w700,
                        fontSize: 9)),
              ],
            ),
          ),
      ],
    );
  }
}
