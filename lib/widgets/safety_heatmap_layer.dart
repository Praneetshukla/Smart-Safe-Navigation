import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

class SafetyHeatmapLayer extends StatelessWidget {
  final List<SafetyReport> reports;
  final bool visible;

  const SafetyHeatmapLayer({
    super.key,
    required this.reports,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || reports.isEmpty) return const SizedBox.shrink();

    return CircleLayer(
      circles: reports.map((r) {
        final color = r.severity >= 4.0 
            ? AppTheme.danger 
            : AppTheme.accentOrange;
            
        return CircleMarker(
          point: r.location,
          radius: 120.0, // Large radius for heatmap feel
          useRadiusInMeter: true,
          color: color.withOpacity(0.15),
          borderColor: color.withOpacity(0.3),
          borderStrokeWidth: 1.5,
        );
      }).toList(),
    );
  }
}
