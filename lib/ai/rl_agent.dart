import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'feature_discretizer.dart';
import '../data/safety_features.dart';

class RLAgent {
  // ── Hyperparameters ──────────────────────────────────────────────────────
  static const double _learningRate = 0.1;        // α
  static const double _discountFactor = 0.9;      // γ
  static const double _initialEpsilon = 0.3;      // initial exploration rate
  static const double _minEpsilon = 0.05;          // minimum exploration
  static const double _epsilonDecay = 0.995;       // decay per episode

  static const String _prefsKeyQTable = 'rl_q_table';
  static const String _prefsKeyEpsilon = 'rl_epsilon';
  static const String _prefsKeyEpisodes = 'rl_episodes';
  static const String _prefsKeyVisitCounts = 'rl_visit_counts';

  // ── State ────────────────────────────────────────────────────────────────
  late List<List<double>> _qTable; // [states][actions]
  late List<List<int>> _visitCounts; // track how often each (s,a) is visited
  double _epsilon = _initialEpsilon;
  int _totalEpisodes = 0;
  final Random _rng = Random();
  bool _isLoaded = false;

  // Singleton
  static final RLAgent _instance = RLAgent._();
  factory RLAgent() => _instance;
  RLAgent._() {
    _initQTable();
  }

  void _initQTable() {
    _qTable = List.generate(
      DiscreteState.totalStates,
      (_) => List.filled(DiscreteState.totalActions, 0.0),
    );
    _visitCounts = List.generate(
      DiscreteState.totalStates,
      (_) => List.filled(DiscreteState.totalActions, 0),
    );
  }

  /// Load Q-table from SharedPreferences. Call once at app startup.
  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      final qJson = prefs.getString(_prefsKeyQTable);
      if (qJson != null) {
        final decoded = json.decode(qJson) as List<dynamic>;
        for (int s = 0; s < DiscreteState.totalStates && s < decoded.length; s++) {
          final actions = decoded[s] as List<dynamic>;
          for (int a = 0; a < DiscreteState.totalActions && a < actions.length; a++) {
            _qTable[s][a] = (actions[a] as num).toDouble();
          }
        }
      }

      final vcJson = prefs.getString(_prefsKeyVisitCounts);
      if (vcJson != null) {
        final decoded = json.decode(vcJson) as List<dynamic>;
        for (int s = 0; s < DiscreteState.totalStates && s < decoded.length; s++) {
          final actions = decoded[s] as List<dynamic>;
          for (int a = 0; a < DiscreteState.totalActions && a < actions.length; a++) {
            _visitCounts[s][a] = (actions[a] as num).toInt();
          }
        }
      }

      _epsilon = prefs.getDouble(_prefsKeyEpsilon) ?? _initialEpsilon;
      _totalEpisodes = prefs.getInt(_prefsKeyEpisodes) ?? 0;
      _isLoaded = true;

      debugPrint('[RLAgent] Loaded. Episodes: $_totalEpisodes, ε: ${_epsilon.toStringAsFixed(3)}');
    } catch (e) {
      debugPrint('[RLAgent] Load error: $e');
      _initQTable();
      _isLoaded = true;
    }
  }

  /// Save Q-table to SharedPreferences.
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyQTable, json.encode(_qTable));
      await prefs.setString(_prefsKeyVisitCounts, json.encode(_visitCounts));
      await prefs.setDouble(_prefsKeyEpsilon, _epsilon);
      await prefs.setInt(_prefsKeyEpisodes, _totalEpisodes);
    } catch (e) {
      debugPrint('[RLAgent] Save error: $e');
    }
  }

  /// Select an action using ε-greedy policy.
  ///
  /// Actions:
  ///   0 = neutral (no weight modification)
  ///   1 = boost safety weights (+0.15 modifier)
  ///   2 = boost speed weights (-0.10 modifier)
  ///
  /// Returns the action index.
  int selectAction(DiscreteState state) {
    if (_rng.nextDouble() < _epsilon) {
      // Explore: random action
      return _rng.nextInt(DiscreteState.totalActions);
    }
    // Exploit: pick action with highest Q-value
    return _bestAction(state.index);
  }

  /// Get the weight modifier for a given action.
  static double actionToWeightModifier(int action) {
    switch (action) {
      case 0: return 0.0;    // neutral
      case 1: return 0.15;   // boost safety
      case 2: return -0.10;  // boost speed (reduce safety emphasis)
      default: return 0.0;
    }
  }

  /// Human-readable action label.
  static String actionLabel(int action) {
    switch (action) {
      case 0: return 'Balanced';
      case 1: return 'Safety Boosted';
      case 2: return 'Speed Boosted';
      default: return 'Unknown';
    }
  }

  /// Update Q-table after receiving a reward (user rating).
  ///
  /// [state] — the state when the route was chosen.
  /// [action] — the action that was taken.
  /// [reward] — the user's rating normalised to [-1.0, +1.0].
  /// [nextState] — the state at journey end (can be same or different).
  void update(DiscreteState state, int action, double reward,
      [DiscreteState? nextState]) {
    final s = state.index;
    final a = action;
    final ns = nextState?.index ?? s;

    // Q-learning update rule:
    // Q(s,a) ← Q(s,a) + α [r + γ max_a' Q(s',a') - Q(s,a)]
    final maxNextQ = _qTable[ns].reduce(max);
    final currentQ = _qTable[s][a];
    _qTable[s][a] = currentQ +
        _learningRate * (reward + _discountFactor * maxNextQ - currentQ);

    _visitCounts[s][a]++;
    _totalEpisodes++;

    // Decay exploration rate
    _epsilon = (_epsilon * _epsilonDecay).clamp(_minEpsilon, 1.0);

    debugPrint('[RLAgent] Updated Q($s,$a): '
        '${currentQ.toStringAsFixed(3)} → ${_qTable[s][a].toStringAsFixed(3)} '
        '(reward=$reward, ε=${_epsilon.toStringAsFixed(3)}, episode=$_totalEpisodes)');

    // Auto-save after each update
    save();
  }

  /// Convert a user rating (1–5 stars) to a reward signal (-1.0 to +1.0).
  static double ratingToReward(double rating) {
    // 1 star → -1.0, 3 stars → 0.0, 5 stars → +1.0
    return (rating - 3.0) / 2.0;
  }

  /// Get the confidence level for the current state (based on visit count).
  /// Returns 0.0–1.0 where higher = more confident.
  double getConfidence(DiscreteState state) {
    final totalVisits =
        _visitCounts[state.index].fold<int>(0, (a, b) => a + b);
    // Confidence grows logarithmically: ~0.5 at 5 visits, ~0.8 at 20, ~0.95 at 50
    if (totalVisits == 0) return 0.0;
    return (log(totalVisits + 1) / log(51)).clamp(0.0, 1.0);
  }

  /// Get the total number of RL episodes (training steps).
  int get totalEpisodes => _totalEpisodes;

  /// Get current exploration rate.
  double get epsilon => _epsilon;

  /// Whether the agent has enough data to be meaningful.
  bool get isWarmedUp => _totalEpisodes >= 10;

  /// Reset the agent (for debugging / testing).
  Future<void> reset() async {
    _initQTable();
    _epsilon = _initialEpsilon;
    _totalEpisodes = 0;
    await save();
    debugPrint('[RLAgent] Reset complete');
  }

  // ── Internal helpers ───────────────────────────────────────────────────────
  int _bestAction(int stateIndex) {
    final qValues = _qTable[stateIndex];
    int best = 0;
    for (int i = 1; i < qValues.length; i++) {
      if (qValues[i] > qValues[best]) best = i;
    }
    return best;
  }

  /// Export Q-table summary for debugging.
  Map<String, dynamic> debugSummary() {
    return {
      'episodes': _totalEpisodes,
      'epsilon': _epsilon,
      'qTable': _qTable,
      'visitCounts': _visitCounts,
    };
  }
}
