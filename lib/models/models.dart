// lib/models/models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../data/safety_features.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final List<String> trustedContacts;
  final UserPreferences preferences;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.trustedContacts = const [],
    required this.preferences,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      trustedContacts: List<String>.from(map['trustedContacts'] ?? []),
      preferences: UserPreferences.fromMap(map['preferences'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'trustedContacts': trustedContacts,
        'preferences': preferences.toMap(),
      };
}

class UserPreferences {
  final bool avoidDarkAlleys;
  final bool preferLitRoutes;
  final bool shareLocationWithContacts;
  final String defaultRouteType;
  final String? homeAddress;
  final String? workAddress;

  UserPreferences({
    this.avoidDarkAlleys = true,
    this.preferLitRoutes = true,
    this.shareLocationWithContacts = false,
    this.defaultRouteType = 'safest',
    this.homeAddress,
    this.workAddress,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) => UserPreferences(
        avoidDarkAlleys: map['avoidDarkAlleys'] ?? true,
        preferLitRoutes: map['preferLitRoutes'] ?? true,
        shareLocationWithContacts: map['shareLocationWithContacts'] ?? false,
        defaultRouteType: map['defaultRouteType'] ?? 'safest',
        homeAddress: map['homeAddress'],
        workAddress: map['workAddress'],
      );

  Map<String, dynamic> toMap() => {
        'avoidDarkAlleys': avoidDarkAlleys,
        'preferLitRoutes': preferLitRoutes,
        'shareLocationWithContacts': shareLocationWithContacts,
        'defaultRouteType': defaultRouteType,
        if (homeAddress != null) 'homeAddress': homeAddress,
        if (workAddress != null) 'workAddress': workAddress,
      };

  UserPreferences copyWith({
    bool? avoidDarkAlleys,
    bool? preferLitRoutes,
    bool? shareLocationWithContacts,
    String? defaultRouteType,
    String? homeAddress,
    String? workAddress,
  }) =>
      UserPreferences(
        avoidDarkAlleys: avoidDarkAlleys ?? this.avoidDarkAlleys,
        preferLitRoutes: preferLitRoutes ?? this.preferLitRoutes,
        shareLocationWithContacts:
            shareLocationWithContacts ?? this.shareLocationWithContacts,
        defaultRouteType: defaultRouteType ?? this.defaultRouteType,
        homeAddress: homeAddress ?? this.homeAddress,
        workAddress: workAddress ?? this.workAddress,
      );
}

// ─── Safety Report Model ──────────────────────────────────────────────────────
class SafetyReport {
  final String id;
  final String userId;
  final String userName;
  final LatLng location;
  final String type; // 'harassment','theft','accident','lighting','other'
  final String description;
  final double severity; // 1–5
  final DateTime timestamp;
  final int upvotes;
  final bool isVerified;

  SafetyReport({
    required this.id,
    required this.userId,
    required this.userName,
    required this.location,
    required this.type,
    required this.description,
    required this.severity,
    required this.timestamp,
    this.upvotes = 0,
    this.isVerified = false,
  });

  factory SafetyReport.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final GeoPoint gp = d['location'];
    return SafetyReport(
      id: doc.id,
      userId: d['userId'],
      userName: d['userName'] ?? 'Anonymous',
      location: LatLng(gp.latitude, gp.longitude),
      type: d['type'] ?? 'other',
      description: d['description'] ?? '',
      severity: (d['severity'] as num).toDouble(),
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      upvotes: d['upvotes'] ?? 0,
      isVerified: d['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'location': GeoPoint(location.latitude, location.longitude),
        'type': type,
        'description': description,
        'severity': severity,
        'timestamp': Timestamp.fromDate(timestamp),
        'upvotes': upvotes,
        'isVerified': isVerified,
      };

  static const Map<String, IconData> typeIcons = {};

  String get typeLabel {
    const labels = {
      'harassment': 'Harassment',
      'theft': 'Theft',
      'accident': 'Accident',
      'lighting': 'Poor Lighting',
      'other': 'Other',
    };
    return labels[type] ?? type;
  }
}

// ─── Traffic Models ──────────────────────────────────────────────────────────
enum CongestionLevel { unknown, low, moderate, heavy, severe }

class TrafficSegment {
  final LatLng start;
  final LatLng end;
  final CongestionLevel level;

  TrafficSegment({
    required this.start,
    required this.end,
    required this.level,
  });
}

// ─── Navigation Models ───────────────────────────────────────────────────────
class RouteStep {
  final String instruction;
  final double distanceMetres;
  final int durationSeconds;
  final LatLng location;

  RouteStep({
    required this.instruction,
    required this.distanceMetres,
    required this.durationSeconds,
    required this.location,
  });

  factory RouteStep.fromMap(Map<String, dynamic> map) {
    final man = map['maneuver'];
    final loc = man['location'] as List;
    return RouteStep(
      instruction: man['instruction'] ?? '',
      distanceMetres: (map['distance'] as num).toDouble(),
      durationSeconds: (map['duration'] as num).toInt(),
      location: LatLng(loc[1].toDouble(), loc[0].toDouble()),
    );
  }
}

// ─── Route Model ─────────────────────────────────────────────────────────────
class SafeRoute {
  final String id;
  final String type; // safest / fastest / balanced
  final List<LatLng> points;
  final double distanceKm;
  final int durationSeconds;
  final int trafficDelaySeconds;
  final List<TrafficSegment> trafficSegments;
  final List<RouteStep> steps;
  final double safetyScore; // 0–10
  final List<String> hazardWarnings;

  // ── AI / RL fields ──────────────────────────────────────────────────────
  /// Full safety feature vector used to compute the score.
  final SafetyFeatureVector? safetyFeatures;

  /// AI confidence level (0.0–1.0) for this score.
  final double aiConfidence;

  /// The RL state index when this route was scored.
  final int rlStateIndex;

  /// The RL action taken (0=neutral, 1=safety boost, 2=speed boost).
  final int rlAction;

  SafeRoute({
    required this.id,
    required this.type,
    required this.points,
    required this.distanceKm,
    required this.durationSeconds,
    this.trafficDelaySeconds = 0,
    this.trafficSegments = const [],
    this.steps = const [],
    required this.safetyScore,
    this.hazardWarnings = const [],
    this.safetyFeatures,
    this.aiConfidence = 0.0,
    this.rlStateIndex = 0,
    this.rlAction = 0,
  });

  SafeRoute copyWith({
    String? id,
    String? type,
    List<LatLng>? points,
    double? distanceKm,
    int? durationSeconds,
    int? trafficDelaySeconds,
    List<TrafficSegment>? trafficSegments,
    List<RouteStep>? steps,
    double? safetyScore,
    List<String>? hazardWarnings,
    SafetyFeatureVector? safetyFeatures,
    double? aiConfidence,
    int? rlStateIndex,
    int? rlAction,
  }) {
    return SafeRoute(
      id: id ?? this.id,
      type: type ?? this.type,
      points: points ?? this.points,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      trafficDelaySeconds: trafficDelaySeconds ?? this.trafficDelaySeconds,
      trafficSegments: trafficSegments ?? this.trafficSegments,
      steps: steps ?? this.steps,
      safetyScore: safetyScore ?? this.safetyScore,
      hazardWarnings: hazardWarnings ?? this.hazardWarnings,
      safetyFeatures: safetyFeatures ?? this.safetyFeatures,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      rlStateIndex: rlStateIndex ?? this.rlStateIndex,
      rlAction: rlAction ?? this.rlAction,
    );
  }
}

// ─── Place Model ─────────────────────────────────────────────────────────────
class SafePlace {
  final String id;
  final String name;
  final String category; // 'police','hospital','pharmacy','atm','petrol'
  final LatLng location;
  final String? phone;
  final bool isOpen24h;

  SafePlace({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    this.phone,
    this.isOpen24h = false,
  });
}

// ─── Journey Model ───────────────────────────────────────────────────────────
class Journey {
  final String id;
  final String userId;
  final String startAddress;
  final String endAddress;
  final LatLng startLocation;
  final LatLng endLocation;
  final DateTime startTime;
  final DateTime? endTime;
  final String routeType;
  final double? rating;
  final bool isCompleted;
  final List<LatLng> trackedPath;

  // ── RL training data ────────────────────────────────────────────────────
  /// The RL state index when this journey started.
  final int rlStateIndex;

  /// The RL action taken for this journey.
  final int rlAction;

  /// Safety features snapshot at journey start.
  final Map<String, dynamic>? safetyFeaturesMap;

  Journey({
    required this.id,
    required this.userId,
    required this.startAddress,
    required this.endAddress,
    required this.startLocation,
    required this.endLocation,
    required this.startTime,
    this.endTime,
    required this.routeType,
    this.rating,
    this.isCompleted = false,
    this.trackedPath = const [],
    this.rlStateIndex = 0,
    this.rlAction = 0,
    this.safetyFeaturesMap,
  });

  factory Journey.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final GeoPoint sl = d['startLocation'];
    final GeoPoint el = d['endLocation'];
    return Journey(
      id: doc.id,
      userId: d['userId'],
      startAddress: d['startAddress'] ?? '',
      endAddress: d['endAddress'] ?? '',
      startLocation: LatLng(sl.latitude, sl.longitude),
      endLocation: LatLng(el.latitude, el.longitude),
      startTime: (d['startTime'] as Timestamp).toDate(),
      endTime: d['endTime'] != null
          ? (d['endTime'] as Timestamp).toDate()
          : null,
      routeType: d['routeType'] ?? 'safest',
      rating: d['rating']?.toDouble(),
      isCompleted: d['isCompleted'] ?? false,
      trackedPath: [],
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'startAddress': startAddress,
        'endAddress': endAddress,
        'startLocation': GeoPoint(startLocation.latitude, startLocation.longitude),
        'endLocation': GeoPoint(endLocation.latitude, endLocation.longitude),
        'startTime': Timestamp.fromDate(startTime),
        'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
        'routeType': routeType,
        'rating': rating,
        'isCompleted': isCompleted,
        'rlStateIndex': rlStateIndex,
        'rlAction': rlAction,
        if (safetyFeaturesMap != null) 'safetyFeatures': safetyFeaturesMap,
      };
}

