// lib/services/route_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../data/safety_features.dart';
import '../ai/safety_scorer.dart';
import '../ai/rl_agent.dart';
import '../ai/feature_discretizer.dart';
import 'location_service.dart';
import '../utils/app_theme.dart';

class MapboxResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationSeconds;
  final int delaySeconds;
  final List<TrafficSegment> segments;
  final List<RouteStep> steps;

  MapboxResult({
    required this.points,
    required this.distanceKm,
    required this.durationSeconds,
    this.delaySeconds = 0,
    this.segments = const [],
    this.steps = const [],
  });
}

class RouteService {
  static const String _mapboxBase =
      'https://api.mapbox.com/directions/v5/mapbox/driving-traffic';

  final RLAgent _rlAgent = RLAgent();

  /// Returns exactly 2 routes: [0] = Safest, [1] = Fastest
  /// Now uses ML-based SafetyScorer + RL agent for personalised scoring.
  Future<List<SafeRoute>> getRoutes(
      LatLng origin,
      LatLng dest,
      List<SafetyReport> reports,
      ) async {
    // Ensure RL agent is loaded
    await _rlAgent.load();

    List<MapboxResult> results = [];
    try {
      results = await _fetchMapboxRoutes(origin, dest)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[RouteService] Mapbox error: $e');
    }

    if (results.isEmpty) {
      final fb = _fallback(origin, dest);
      results = fb.map((f) => MapboxResult(points: f.$1, distanceKm: f.$2, durationSeconds: f.$3)).toList();
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final scoredRoutes = <SafeRoute>[];

    // 1. Score ALL available routes using AI-powered scoring
    for (int i = 0; i < results.length; i++) {
      final res = results[i];
      final r = await _applyAIScore(
        SafeRoute(
          id:              'route_${ts}_$i',
          type:            'alternative', // Initial type
          points:          res.points,
          distanceKm:      res.distanceKm,
          durationSeconds: res.durationSeconds,
          trafficDelaySeconds: res.delaySeconds,
          trafficSegments: res.segments,
          steps:           res.steps,
          safetyScore:     0,
        ),
        reports,
      );
      scoredRoutes.add(r);
    }

    // 2. Data-driven selection
    // Sort by duration for fastest
    final sortedByTime = [...scoredRoutes]..sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
    final rawFastest = sortedByTime.first;

    // Sort by safety score for safest
    final sortedBySafety = [...scoredRoutes]..sort((a, b) => b.safetyScore.compareTo(a.safetyScore));
    final rawSafest = sortedBySafety.first;

    // 3. Handle duplicate routes (if safest is also fastest)
    if (rawFastest.id == rawSafest.id) {
      debugPrint('[RouteService] Safest route is also the fastest.');
      return [rawSafest.copyWith(type: 'safest_fastest')];
    }

    return [
      rawSafest.copyWith(type: 'safest'),
      rawFastest.copyWith(type: 'fastest'),
    ];
  }

  // ── Mapbox fetch ──────────────────────────────────────────────────────────
  Future<List<MapboxResult>> _fetchMapboxRoutes(
      LatLng origin, LatLng dest) async {
    final coords = '${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}';
    final url = Uri.parse(
      '$_mapboxBase/$coords'
      '?access_token=${AppConstants.mapboxToken}'
      '&overview=full&geometries=geojson&alternatives=true&annotations=congestion,duration,distance'
      '&steps=true&banner_instructions=true'
    );

    final res = await http.get(url, headers: {'User-Agent': 'SafeRouteApp/1.0'});

    if (res.statusCode != 200) {
      debugPrint('[Mapbox] HTTP ${res.statusCode}: ${res.body}');
      return [];
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    if (body['code'] != 'Ok') return [];

    final routes = body['routes'] as List<dynamic>;
    final result = <MapboxResult>[];

    for (final r in routes) {
      final points = (r['geometry']['coordinates'] as List<dynamic>)
          .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();
      
      final km = (r['distance'] as num).toDouble() / 1000.0;
      final sec = (r['duration'] as num).toInt();
      final typical = (r['duration_typical'] as num?)?.toInt() ?? sec;
      final delay = max(0, sec - typical);

      // Parse congestion segments
      final segments = <TrafficSegment>[];
      final steps = <RouteStep>[];
      final legs = r['legs'] as List<dynamic>;

      for (final leg in legs) {
        // 1. Parse steps
        final legSteps = leg['steps'] as List<dynamic>?;
        if (legSteps != null) {
          steps.addAll(legSteps.map((s) => RouteStep.fromMap(s)));
        }

        // 2. Parse congestion
        final annotation = leg['annotation'];
        if (annotation != null && annotation['congestion'] != null) {
          final congestion = annotation['congestion'] as List<dynamic>;
          // Mapbox segments are between coordinates
          for (int i = 0; i < congestion.length; i++) {
            if (i + 1 < points.length) {
              segments.add(TrafficSegment(
                start: points[i],
                end: points[i + 1],
                level: _parseCongestion(congestion[i].toString()),
              ));
            }
          }
        }
      }

      result.add(MapboxResult(
        points: points,
        distanceKm: km,
        durationSeconds: sec,
        delaySeconds: delay,
        segments: segments,
        steps: steps,
      ));
    }
    return result;
  }

  CongestionLevel _parseCongestion(String val) {
    switch (val) {
      case 'low': return CongestionLevel.low;
      case 'moderate': return CongestionLevel.moderate;
      case 'heavy': return CongestionLevel.heavy;
      case 'severe': return CongestionLevel.severe;
      default: return CongestionLevel.unknown;
    }
  }


  // ── AI-Powered Safety Scoring ──────────────────────────────────────────────
  Future<SafeRoute> _applyAIScore(
      SafeRoute route,
      List<SafetyReport> reports,
      ) async {

    // 1. Compute community report penalty (entire route scan)
    double communityPenalty = 0.0;
    final warnings = <String>[];

    for (final report in reports) {
      double minDist = double.infinity;

      for (final pt in route.points) {
        final d = _haversine(pt, report.location) * 1000;
        if (d < minDist) minDist = d;
      }

      if (minDist < 500) {
        final proximity = 1.0 - minDist / 500.0;
        communityPenalty += report.severity * proximity;

        if (!warnings.contains(report.typeLabel)) {
          warnings.add(report.typeLabel);
        }
      }
    }

    // 2. Fetch comprehensive safety features with multi-point metrics
    // We sample Start, Midpoint, and Endpoint and average them to create
    // a representative feature vector for the entire path.
    SafetyFeatureVector features;
    try {
      final samplingPoints = [
        route.points.first,
        route.points[(route.points.length / 2).floor()],
        route.points.last,
      ];

      // Fetch in parallel with localized penalties
      final vectorResults = await Future.wait(samplingPoints.map((pt) =>
        LocationService().fetchSafetyFeatures(
          pt,
          communityReportPenalty: communityPenalty / samplingPoints.length,
          hazardWarnings: warnings,
        ).timeout(const Duration(seconds: 8), onTimeout: () => const SafetyFeatureVector())
      ));

      features = SafetyFeatureVector.average(vectorResults).copyWith(
        communityReportPenalty: communityPenalty,
      );
    } catch (e) {
      debugPrint('[RouteService] AI scoring sampling error: $e');
      features = SafetyFeatureVector(
        communityReportPenalty: communityPenalty,
        timeOfDayFactor: SafetyFeatureVector.computeTimeOfDayFactor(),
      );
    }

    // 3. RL Agent: discretize state and select action
    final discreteState = FeatureDiscretizer.discretize(features);
    final rlAction = _rlAgent.selectAction(discreteState);
    final rlModifier = RLAgent.actionToWeightModifier(rlAction);

    // 4. Compute AI safety score using SafetyScorer (unbiased)
    final routeMultiplier = SafetyScorer.routeTypeMultiplier(route.type);
    final aiScore = SafetyScorer.computeScore(
      features,
      routeTypeMultiplier: routeMultiplier,
      rlWeightModifier: rlModifier,
    );

    // 5. Compute AI confidence
    final aiConfidence = SafetyScorer.computeConfidence(features);

    debugPrint('[AI Score] ${route.id}: ${aiScore.toStringAsFixed(1)} '
        '(confidence: ${(aiConfidence * 100).round()}%, '
        'RL: ${RLAgent.actionLabel(rlAction)}, '
        'state: $discreteState)');

    // 6. Return enriched SafeRoute with AI data
    return SafeRoute(
      id: route.id,
      type: route.type,
      points: route.points,
      distanceKm: route.distanceKm,
      durationSeconds: route.durationSeconds,
      safetyScore: aiScore,
      hazardWarnings: warnings,
      safetyFeatures: features,
      steps: route.steps,
      aiConfidence: aiConfidence,
      rlStateIndex: discreteState.index,
      rlAction: rlAction,
    );
  }

  // ── Offline fallback ───────────────────────────────────────────────────────
  List<(List<LatLng>, double, int)> _fallback(LatLng a, LatLng b) {
    debugPrint('[RouteService] Generating neutral fallback candidates');
    final dist = _haversine(a, b);
    
    // Create two neutral path candidates with varying curvatures.
    // They will be scored neutrally by the AI engine.
    return [
      (_curvedLine(a, b, bias: 0.0),    dist * 1.1, (dist * 1.1 * 95).round()), 
      (_curvedLine(a, b, bias: 0.0004), dist * 1.2, (dist * 1.2 * 105).round()),
    ];
  }

  // ── Geometry helpers ───────────────────────────────────────────────────────
  double _haversine(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _rad(b.latitude  - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final sinLat = sin(dLat / 2);
    final sinLon = sin(dLon / 2);
    final x = sinLat * sinLat +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * sinLon * sinLon;
    return R * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  double _rad(double d) => d * pi / 180.0;

  List<LatLng> _curvedLine(LatLng a, LatLng b,
      {double bias = 0.0, int steps = 30}) {
    return List.generate(steps + 1, (i) {
      final t = i / steps;
      return LatLng(
        a.latitude  + (b.latitude  - a.latitude)  * t + bias * sin(t * pi),
        a.longitude + (b.longitude - a.longitude) * t,
      );
    });
  }

}
