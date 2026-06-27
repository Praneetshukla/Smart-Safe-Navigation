import '../data/safety_features.dart';

class SafetyScorer {
  SafetyScorer._();

  static const Map<String, double> defaultWeights = {
    'streetLights': 0.12,           // more lights → safer
    'shops': 0.08,                  // more shops → safer
    'cctvCount': 0.15,              // CCTV → significantly safer
    'policeStationProximity': 0.12, // closer police → safer
    'hospitalProximity': 0.08,      // closer hospital → safer
    'busStops': 0.06,               // more transit → safer
    'historicalCrimeIndex': -0.25,  // higher crime → less safe
    'communityReports': -0.18,      // more reports → less safe
    'timeOfDay': -0.15,             // night time → less safe
    'activePlaces': 0.10,           // more foot traffic → safer
  };

  static const double _baseScore = 6.0;

  /// Compute a safety score from 0.0 to 10.0 using weighted features.
  ///
  /// [features] — the environmental data for this route/location.
  /// [routeTypeMultiplier] — allows differentiation (safest=1.2, fastest=0.85).
  /// [rlWeightModifier] — adjustment from RL agent (-0.3 to +0.3).
  static double computeScore(
    SafetyFeatureVector features, {
    double routeTypeMultiplier = 1.0,
    double rlWeightModifier = 0.0,
  }) {
    double score = _baseScore;

    // ── Street Lights ──────────────────────────────────────────────────────
    // Normalise: 0 lights → 0.0, 20+ lights → 1.0
    final lightNorm = (features.streetLights.clamp(0, 20) / 20.0);
    score += lightNorm * _weight('streetLights', rlWeightModifier) * 10;

    // ── Shops ──────────────────────────────────────────────────────────────
    final shopNorm = (features.shops.clamp(0, 15) / 15.0);
    score += shopNorm * _weight('shops', rlWeightModifier) * 10;

    // ── CCTV ───────────────────────────────────────────────────────────────
    final cctvNorm = (features.cctvCount.clamp(0, 10) / 10.0);
    score += cctvNorm * _weight('cctvCount', rlWeightModifier) * 10;

    // ── Police Station Proximity ───────────────────────────────────────────
    // Closer is better: 0m → 1.0, 5000m+ → 0.0
    final policeNorm =
        (5000 - features.policeStationDistanceM.clamp(0, 5000)) / 5000;
    score += policeNorm * _weight('policeStationProximity', rlWeightModifier) * 10;

    // ── Hospital Proximity ─────────────────────────────────────────────────
    final hospitalNorm =
        (5000 - features.hospitalDistanceM.clamp(0, 5000)) / 5000;
    score += hospitalNorm * _weight('hospitalProximity', rlWeightModifier) * 10;

    // ── Bus Stops ──────────────────────────────────────────────────────────
    final busNorm = (features.busStops.clamp(0, 8) / 8.0);
    score += busNorm * _weight('busStops', rlWeightModifier) * 10;

    // ── Historical Crime ───────────────────────────────────────────────────
    // Higher crime index → negative contribution
    final crimeNorm = features.historicalCrimeIndex.clamp(0.0, 1.0);
    score += crimeNorm * _weight('historicalCrimeIndex', rlWeightModifier) * 10;

    // ── Community Reports ──────────────────────────────────────────────────
    final reportNorm = (features.communityReportPenalty.clamp(0, 10) / 10.0);
    score += reportNorm * _weight('communityReports', rlWeightModifier) * 10;

    // ── Time of Day ────────────────────────────────────────────────────────
    final timeNorm = features.timeOfDayFactor.clamp(0.0, 1.0);
    score += timeNorm * _weight('timeOfDay', rlWeightModifier) * 10;

    // ── Active Places ──────────────────────────────────────────────────────
    final activeNorm = (features.activePlaces.clamp(0, 10) / 10.0);
    score += activeNorm * _weight('activePlaces', rlWeightModifier) * 10;

    // ── Route type multiplier ──────────────────────────────────────────────
    // Safest routes get a small bonus, fastest get a small penalty.
    score *= routeTypeMultiplier;

    return score.clamp(1.0, 10.0);
  }

  /// Get the effective weight for a feature, adjusted by RL modifier.
  static double _weight(String feature, double rlModifier) {
    final base = defaultWeights[feature] ?? 0.0;
    // RL modifier shifts all positive weights up/down slightly.
    // This personalises the scoring based on user preferences.
    if (base > 0) {
      return (base + rlModifier * 0.1).clamp(0.01, 0.5);
    } else {
      return (base - rlModifier * 0.05).clamp(-0.5, -0.01);
    }
  }

  /// Compute the route-type multiplier.
  static double routeTypeMultiplier(String routeType) {
    // Bias removed to support truly data-driven route selection.
    // We now allow the raw environmental and community data to determine
    // which route is safer.
    return 1.0;
  }

  /// Returns the AI confidence level (0.0–1.0) based on available data.
  /// More data sources contributing = higher confidence.
  static double computeConfidence(SafetyFeatureVector features) {
    double confidence = 0.0;
    int factors = 0;

    if (features.streetLights > 0) { confidence += 0.15; factors++; }
    if (features.shops > 0) { confidence += 0.10; factors++; }
    if (features.cctvCount > 0) { confidence += 0.15; factors++; }
    if (features.policeStationDistanceM < 4500) { confidence += 0.12; factors++; }
    if (features.hospitalDistanceM < 4500) { confidence += 0.08; factors++; }
    if (features.busStops > 0) { confidence += 0.08; factors++; }
    if (features.historicalCrimeIndex != 0.35) { confidence += 0.15; factors++; }
    if (features.communityReportPenalty > 0) { confidence += 0.10; factors++; }
    if (features.activePlaces > 0) { confidence += 0.10; factors++; }

    // Always have time-of-day
    confidence += 0.05;

    // Bonus for having many data sources
    if (factors >= 6) confidence += 0.10;

    return confidence.clamp(0.0, 1.0);
  }
}
