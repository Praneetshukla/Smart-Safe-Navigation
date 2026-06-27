import '../data/safety_features.dart';

class DiscreteState {
  final int crimeLevel;   // 0=low, 1=medium, 2=high
  final int timeOfDay;    // 0=day, 1=night
  final int lightingLevel; // 0=poor, 1=ok, 2=good

  const DiscreteState({
    required this.crimeLevel,
    required this.timeOfDay,
    required this.lightingLevel,
  });

  /// Flatten to a single integer index for Q-table lookup.
  /// Range: 0–17 (18 total states).
  int get index => crimeLevel * 6 + timeOfDay * 3 + lightingLevel;

  /// Total number of possible states.
  static const int totalStates = 18;

  /// Total number of possible actions.
  /// 0 = no modifier, 1 = boost safety weight, 2 = boost speed weight
  static const int totalActions = 3;

  @override
  String toString() =>
      'State(crime=$crimeLevel, time=$timeOfDay, light=$lightingLevel, idx=$index)';

  @override
  bool operator ==(Object other) =>
      other is DiscreteState && other.index == index;

  @override
  int get hashCode => index.hashCode;
}

class FeatureDiscretizer {
  FeatureDiscretizer._();

  /// Convert a continuous feature vector to a discrete state.
  static DiscreteState discretize(SafetyFeatureVector features) {
    return DiscreteState(
      crimeLevel: _discretizeCrime(features.historicalCrimeIndex),
      timeOfDay: _discretizeTime(features.timeOfDayFactor),
      lightingLevel: _discretizeLighting(features.streetLights, features.cctvCount),
    );
  }

  /// Crime index: <0.3 = low, 0.3–0.55 = medium, >0.55 = high
  static int _discretizeCrime(double crimeIndex) {
    if (crimeIndex < 0.3) return 0; // low
    if (crimeIndex < 0.55) return 1; // medium
    return 2; // high
  }

  /// Time factor: <0.5 = day, ≥0.5 = night
  static int _discretizeTime(double timeFactor) {
    return timeFactor < 0.5 ? 0 : 1;
  }

  /// Lighting: based on street lamps + CCTV count combined.
  /// <3 = poor, 3–10 = ok, >10 = good
  static int _discretizeLighting(int streetLights, int cctvCount) {
    final combined = streetLights + cctvCount;
    if (combined < 3) return 0; // poor
    if (combined <= 10) return 1; // ok
    return 2; // good
  }

  /// Human-readable labels for each state dimension.
  static String crimeLevelLabel(int level) {
    const labels = ['Low Crime', 'Moderate Crime', 'High Crime'];
    return labels[level.clamp(0, 2)];
  }

  static String timeOfDayLabel(int level) {
    return level == 0 ? 'Daytime' : 'Nighttime';
  }

  static String lightingLabel(int level) {
    const labels = ['Poor Lighting', 'Moderate Lighting', 'Well Lit'];
    return labels[level.clamp(0, 2)];
  }

  /// Get a human-readable description of a discrete state.
  static String describeState(DiscreteState state) {
    return '${crimeLevelLabel(state.crimeLevel)} · '
        '${timeOfDayLabel(state.timeOfDay)} · '
        '${lightingLabel(state.lightingLevel)}';
  }
}
