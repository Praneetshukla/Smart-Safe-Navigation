// lib/services/safety_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

class SafetyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<SafetyReport>> streamNearbyReports(LatLng center,
      {double radiusKm = 5}) {
    // Firestore geo queries: approximate bounding box
    final latDelta = radiusKm / 110.574;
    final lngDelta = radiusKm / (111.320 * _cos(center.latitude));

    return _db
        .collection('safety_reports')
        .where('location',
            isGreaterThanOrEqualTo:
                GeoPoint(center.latitude - latDelta, center.longitude - lngDelta))
        .where('location',
            isLessThanOrEqualTo:
                GeoPoint(center.latitude + latDelta, center.longitude + lngDelta))
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SafetyReport.fromFirestore(d)).toList());
  }

  Future<void> submitReport(SafetyReport report) async {
    await _db.collection('safety_reports').add(report.toMap());
  }

  Future<void> upvoteReport(String reportId) async {
    await _db
        .collection('safety_reports')
        .doc(reportId)
        .update({'upvotes': FieldValue.increment(1)});
  }

  Future<double> getAreaSafetyScore(LatLng center,
      {double radiusKm = 1}) async {
    final reports = await streamNearbyReports(center, radiusKm: radiusKm)
        .first;
    if (reports.isEmpty) return 0;
    double totalPenalty = 0;
    for (final r in reports) {
      final ageHours =
          DateTime.now().difference(r.timestamp).inHours;
      final ageFactor = (1 - ageHours / (24 * 30)).clamp(0.1, 1.0);
      totalPenalty += r.severity * ageFactor;
    }
    return (10 - totalPenalty / reports.length).clamp(1, 10);
  }

  double _cos(double degrees) {
    return _cos_rad(degrees * 3.14159265358979 / 180);
  }

  double _cos_rad(double rad) {
    // Taylor approximation
    double x = rad % (2 * 3.14159265358979);
    return 1 -
        (x * x) / 2 +
        (x * x * x * x) / 24 -
        (x * x * x * x * x * x) / 720;
  }
}
