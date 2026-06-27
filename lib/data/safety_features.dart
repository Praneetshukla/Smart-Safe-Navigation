// lib/data/safety_features.dart
//
// Defines the SafetyFeatureVector — a structured representation of all
// environmental and historical safety signals for a location or route segment.

class SafetyFeatureVector {
  /// Number of street lamps within 500m radius (from Overpass)
  final int streetLights;

  /// Number of shops/commercial places within 500m (from Overpass)
  final int shops;

  /// Number of CCTV/surveillance cameras within 500m (from Overpass)
  final int cctvCount;

  /// Distance to nearest police station in metres (from Overpass)
  final double policeStationDistanceM;

  /// Distance to nearest hospital in metres (from Overpass)
  final double hospitalDistanceM;

  /// Number of bus stops within 500m (from Overpass)
  final int busStops;

  /// Historical crime index for this district (0.0–1.0 from NCRB)
  final double historicalCrimeIndex;

  /// Penalty from community-reported incidents nearby (0.0–10.0)
  final double communityReportPenalty;

  /// Time-of-day factor: 0.0 = safest (midday), 1.0 = riskiest (late night)
  final double timeOfDayFactor;

  /// Number of active/popular places nearby (proxy for foot traffic)
  final int activePlaces;

  const SafetyFeatureVector({
    this.streetLights = 0,
    this.shops = 0,
    this.cctvCount = 0,
    this.policeStationDistanceM = 5000.0,
    this.hospitalDistanceM = 5000.0,
    this.busStops = 0,
    this.historicalCrimeIndex = 0.35,
    this.communityReportPenalty = 0.0,
    this.timeOfDayFactor = 0.3,
    this.activePlaces = 0,
  });

  /// Compute the time-of-day factor from the current hour (0–23).
  /// Safer during day (6–18), riskier at night, worst at 1–4 AM.
  static double computeTimeOfDayFactor([DateTime? dateTime]) {
    final hour = (dateTime ?? DateTime.now()).hour;
    if (hour >= 8 && hour <= 17) return 0.1; // daytime — safest
    if (hour >= 6 && hour < 8) return 0.25; // early morning
    if (hour >= 17 && hour < 20) return 0.3; // evening
    if (hour >= 20 && hour < 23) return 0.6; // night
    if (hour >= 23 || hour < 1) return 0.8; // late night
    return 0.95; // 1–5 AM — riskiest
  }

  /// Create a copy with modified fields.
  SafetyFeatureVector copyWith({
    int? streetLights,
    int? shops,
    int? cctvCount,
    double? policeStationDistanceM,
    double? hospitalDistanceM,
    int? busStops,
    double? historicalCrimeIndex,
    double? communityReportPenalty,
    double? timeOfDayFactor,
    int? activePlaces,
  }) {
    return SafetyFeatureVector(
      streetLights: streetLights ?? this.streetLights,
      shops: shops ?? this.shops,
      cctvCount: cctvCount ?? this.cctvCount,
      policeStationDistanceM:
          policeStationDistanceM ?? this.policeStationDistanceM,
      hospitalDistanceM: hospitalDistanceM ?? this.hospitalDistanceM,
      busStops: busStops ?? this.busStops,
      historicalCrimeIndex: historicalCrimeIndex ?? this.historicalCrimeIndex,
      communityReportPenalty:
          communityReportPenalty ?? this.communityReportPenalty,
      timeOfDayFactor: timeOfDayFactor ?? this.timeOfDayFactor,
      activePlaces: activePlaces ?? this.activePlaces,
    );
  }

  /// Serialise to a Map for Firestore / JSON storage.
  Map<String, dynamic> toMap() => {
        'streetLights': streetLights,
        'shops': shops,
        'cctvCount': cctvCount,
        'policeStationDistanceM': policeStationDistanceM,
        'hospitalDistanceM': hospitalDistanceM,
        'busStops': busStops,
        'historicalCrimeIndex': historicalCrimeIndex,
        'communityReportPenalty': communityReportPenalty,
        'timeOfDayFactor': timeOfDayFactor,
        'activePlaces': activePlaces,
      };

  /// Deserialise from a Map.
  factory SafetyFeatureVector.fromMap(Map<String, dynamic> map) {
    return SafetyFeatureVector(
      streetLights: map['streetLights'] ?? 0,
      shops: map['shops'] ?? 0,
      cctvCount: map['cctvCount'] ?? 0,
      policeStationDistanceM:
          (map['policeStationDistanceM'] as num?)?.toDouble() ?? 5000.0,
      hospitalDistanceM:
          (map['hospitalDistanceM'] as num?)?.toDouble() ?? 5000.0,
      busStops: map['busStops'] ?? 0,
      historicalCrimeIndex:
          (map['historicalCrimeIndex'] as num?)?.toDouble() ?? 0.35,
      communityReportPenalty:
          (map['communityReportPenalty'] as num?)?.toDouble() ?? 0.0,
      timeOfDayFactor:
          (map['timeOfDayFactor'] as num?)?.toDouble() ?? 0.3,
      activePlaces: map['activePlaces'] ?? 0,
    );
  }

  /// Merges multiple vectors by averaging their values.
  static SafetyFeatureVector average(List<SafetyFeatureVector> vectors) {
    if (vectors.isEmpty) return const SafetyFeatureVector();
    if (vectors.length == 1) return vectors.first;

    double lights = 0, shops = 0, cctv = 0, bus = 0, active = 0;
    double police = 0, hospital = 0, crime = 0, penalty = 0, time = 0;

    for (final v in vectors) {
      lights += v.streetLights;
      shops += v.shops;
      cctv += v.cctvCount;
      bus += v.busStops;
      active += v.activePlaces;
      police += v.policeStationDistanceM;
      hospital += v.hospitalDistanceM;
      crime += v.historicalCrimeIndex;
      penalty += v.communityReportPenalty;
      time += v.timeOfDayFactor;
    }

    final n = vectors.length.toDouble();
    return SafetyFeatureVector(
      streetLights: (lights / n).round(),
      shops: (shops / n).round(),
      cctvCount: (cctv / n).round(),
      busStops: (bus / n).round(),
      activePlaces: (active / n).round(),
      policeStationDistanceM: police / n,
      hospitalDistanceM: hospital / n,
      historicalCrimeIndex: crime / n,
      communityReportPenalty: penalty / n,
      timeOfDayFactor: time / n,
    );
  }

  /// Returns a human-readable breakdown of each feature's contribution.
  /// Each entry: (label, rawValue, normalisedContribution -1.0 to +1.0).
  List<FeatureContribution> getContributions() {
    return [
      FeatureContribution(
        label: 'Street Lighting',
        icon: 'lightbulb',
        rawValue: streetLights.toDouble(),
        // More lights → positive contribution
        contribution: (streetLights.clamp(0, 20) / 20.0) * 2.0 - 0.2,
      ),
      FeatureContribution(
        label: 'Shops & Commerce',
        icon: 'store',
        rawValue: shops.toDouble(),
        contribution: (shops.clamp(0, 15) / 15.0) * 1.5 - 0.1,
      ),
      FeatureContribution(
        label: 'CCTV Coverage',
        icon: 'videocam',
        rawValue: cctvCount.toDouble(),
        contribution: (cctvCount.clamp(0, 10) / 10.0) * 1.8,
      ),
      FeatureContribution(
        label: 'Police Proximity',
        icon: 'local_police',
        rawValue: policeStationDistanceM,
        // Closer = better, max bonus at <200m
        contribution:
            ((5000 - policeStationDistanceM.clamp(0, 5000)) / 5000) * 1.5,
      ),
      FeatureContribution(
        label: 'Hospital Access',
        icon: 'local_hospital',
        rawValue: hospitalDistanceM,
        contribution:
            ((5000 - hospitalDistanceM.clamp(0, 5000)) / 5000) * 1.0,
      ),
      FeatureContribution(
        label: 'Public Transit',
        icon: 'directions_bus',
        rawValue: busStops.toDouble(),
        contribution: (busStops.clamp(0, 8) / 8.0) * 1.2,
      ),
      FeatureContribution(
        label: 'Crime History',
        icon: 'warning',
        rawValue: historicalCrimeIndex,
        // Higher crime = negative contribution
        contribution: -(historicalCrimeIndex.clamp(0, 1) * 3.0),
      ),
      FeatureContribution(
        label: 'Recent Reports',
        icon: 'report',
        rawValue: communityReportPenalty,
        contribution: -(communityReportPenalty.clamp(0, 10) / 10.0 * 2.5),
      ),
      FeatureContribution(
        label: 'Time of Day',
        icon: 'schedule',
        rawValue: timeOfDayFactor,
        // Higher factor = riskier time → negative
        contribution: -(timeOfDayFactor.clamp(0, 1) * 2.0),
      ),
      FeatureContribution(
        label: 'Foot Traffic',
        icon: 'groups',
        rawValue: activePlaces.toDouble(),
        contribution: (activePlaces.clamp(0, 10) / 10.0) * 1.5,
      ),
    ];
  }

  @override
  String toString() =>
      'SafetyFeatures(lights=$streetLights, shops=$shops, cctv=$cctvCount, '
      'police=${policeStationDistanceM.toInt()}m, hospital=${hospitalDistanceM.toInt()}m, '
      'bus=$busStops, crime=$historicalCrimeIndex, reports=$communityReportPenalty, '
      'time=$timeOfDayFactor, active=$activePlaces)';
}

/// Represents one feature's contribution to the safety score.
class FeatureContribution {
  final String label;
  final String icon;
  final double rawValue;

  /// Positive = makes route safer, negative = makes route less safe.
  final double contribution;

  const FeatureContribution({
    required this.label,
    required this.icon,
    required this.rawValue,
    required this.contribution,
  });
}
