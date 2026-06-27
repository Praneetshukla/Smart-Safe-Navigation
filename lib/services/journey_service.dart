// lib/services/journey_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class JourneyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> startJourney(Journey journey) async {
    final ref =
        await _db.collection('journeys').add(journey.toMap());
    return ref.id;
  }

  Future<void> completeJourney(String journeyId,
      {double? rating}) async {
    await _db.collection('journeys').doc(journeyId).update({
      'isCompleted': true,
      'endTime': Timestamp.now(),
      if (rating != null) 'rating': rating,
    });
  }

  Stream<List<Journey>> streamUserJourneys(String userId) {
    return _db
        .collection('journeys')
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) => Journey.fromFirestore(d)).toList());
  }

  Stream<Map<String, dynamic>> getJourneyStats(String userId) {
    return _db
        .collection('journeys')
        .where('userId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final journeys = snap.docs.map((d) => Journey.fromFirestore(d)).toList();
      if (journeys.isEmpty) {
        return {
          'total': 0,
          'avgRating': 0.0,
          'routeTypes': <String, int>{},
          'thisWeek': 0,
        };
      }

      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final routeTypes = <String, int>{};
      double totalRating = 0;
      int ratingCount = 0;
      int thisWeek = 0;

      for (final j in journeys) {
        routeTypes[j.routeType] = (routeTypes[j.routeType] ?? 0) + 1;
        if (j.rating != null) {
          totalRating += j.rating!;
          ratingCount++;
        }
        if (j.startTime.isAfter(weekAgo)) thisWeek++;
      }

      return {
        'total': journeys.length,
        'avgRating': ratingCount > 0 ? totalRating / ratingCount : 0.0,
        'routeTypes': routeTypes,
        'thisWeek': thisWeek,
      };
    });
  }

  Future<void> deleteJourney(String journeyId) async {
    await _db.collection('journeys').doc(journeyId).delete();
  }

  Future<void> deleteAllJourneys(String userId) async {
    final batch = _db.batch();
    final snap = await _db
        .collection('journeys')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
