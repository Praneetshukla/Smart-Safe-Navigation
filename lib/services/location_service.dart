// lib/services/location_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/safety_features.dart';
import '../data/crime_dataset.dart';

class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  StreamController<LatLng>? _locationController;
  StreamSubscription<Position>? _positionSub;
  LatLng? _lastKnown;

  LatLng? get lastKnown => _lastKnown;

  /// Fetches current GPS coordinates with permission handling.
  Future<LatLng?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _lastKnown = LatLng(pos.latitude, pos.longitude);
      return _lastKnown;
    } catch (e) {
      debugPrint('[LocationService] getCurrentLocation error: $e');
      return null;
    }
  }

  /// Real-time location updates for navigation.
  Stream<Position> trackLocation() {
    // Check if services are enabled (optional but better for debugging)
    Geolocator.isLocationServiceEnabled().then((enabled) {
      if (!enabled) debugPrint('[LocationService] WARNING: GPS services are disabled.');
    });

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2, // Reduced for smoother tracking
      ),
    );
  }

  /// Reverse geocoding: LatLng -> Street Address
  Future<String> getAddressFromLatLng(LatLng loc) async {
    try {
      final placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.name, p.subLocality, p.locality, p.administrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .take(3);
        return parts.join(', ');
      }
    } catch (e) {
      debugPrint('[LocationService] getAddress error: $e');
    }
    return 'Unknown Location';
  }

  /// Forward geocoding: Address -> LatLng
  Future<LatLng?> getLatLngFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address).timeout(const Duration(seconds: 10));
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      debugPrint('[LocationService] getLatLng error: $e');
    }
    return null;
  }

  /// Calculates point-to-point distance in metres for high precision.
  double distanceBetween(LatLng p1, LatLng p2) {
    return Geolocator.distanceBetween(
      p1.latitude,
      p1.longitude,
      p2.latitude,
      p2.longitude,
    );
  }

  /// Fetches comprehensive environment data from Overpass API in a single
  /// batched query: street lamps, shops, CCTV, police, hospitals, bus stops.
  Future<Map<String, int>> fetchEnvironmentData(LatLng loc) async {
    try {
      final query = '''
    [out:json][timeout:15];
    (
      node["highway"="street_lamp"](around:500, ${loc.latitude}, ${loc.longitude});
      node["shop"](around:500, ${loc.latitude}, ${loc.longitude});
      node["man_made"="surveillance"](around:500, ${loc.latitude}, ${loc.longitude});
      node["amenity"="police"](around:2000, ${loc.latitude}, ${loc.longitude});
      node["amenity"="hospital"](around:2000, ${loc.latitude}, ${loc.longitude});
      node["amenity"="clinic"](around:2000, ${loc.latitude}, ${loc.longitude});
      node["highway"="bus_stop"](around:500, ${loc.latitude}, ${loc.longitude});
      node["amenity"="bus_station"](around:500, ${loc.latitude}, ${loc.longitude});
    );
    out;
    ''';

      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return _defaultEnvData();

      final data = json.decode(res.body);
      final elements = data['elements'] as List;

      int lights = 0, shops = 0, cctv = 0;
      int police = 0, hospitals = 0, busStops = 0;

      for (final e in elements) {
        final tags = e['tags'] ?? {};
        if (tags['highway'] == 'street_lamp') lights++;
        if (tags['shop'] != null) shops++;
        if (tags['man_made'] == 'surveillance') cctv++;
        if (tags['amenity'] == 'police') police++;
        if (tags['amenity'] == 'hospital' || tags['amenity'] == 'clinic') hospitals++;
        if (tags['highway'] == 'bus_stop' || tags['amenity'] == 'bus_station') busStops++;
      }

      return {
        'lights': lights,
        'shops': shops,
        'cctv': cctv,
        'police': police,
        'hospitals': hospitals,
        'busStops': busStops,
      };
    } catch (e) {
      debugPrint('[Overpass] error: $e');
      return _defaultEnvData();
    }
  }

  Map<String, int> _defaultEnvData() => {
        'lights': 0, 'shops': 0, 'cctv': 0,
        'police': 0, 'hospitals': 0, 'busStops': 0,
      };

  /// Compute approximate distance to nearest amenity of a given type.
  /// Returns distance in metres, or 5000 if none found.
  Future<double> _distanceToNearestAmenity(
      LatLng loc, String amenityType) async {
    try {
      final query = '''
      [out:json][timeout:10];
      node["amenity"="$amenityType"](around:5000, ${loc.latitude}, ${loc.longitude});
      out 1;
      ''';
      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return 5000.0;

      final data = json.decode(res.body);
      final elements = data['elements'] as List;
      if (elements.isEmpty) return 5000.0;

      final nearest = elements.first;
      final nLat = (nearest['lat'] as num).toDouble();
      final nLon = (nearest['lon'] as num).toDouble();
      return distanceBetween(loc, LatLng(nLat, nLon)); // Already in metres
    } catch (e) {
      return 5000.0;
    }
  }

  /// Build a complete SafetyFeatureVector for a location by combining
  /// all available data sources: Overpass, NCRB, time-of-day, community reports.
  Future<SafetyFeatureVector> fetchSafetyFeatures(
    LatLng loc, {
    double communityReportPenalty = 0.0,
    List<String> hazardWarnings = const [],
  }) async {
    // Fetch environment data and active places in parallel
    final results = await Future.wait([
      fetchEnvironmentData(loc),
      fetchActivePlaces(loc),
    ]);

    final envData = results[0] as Map<String, int>;
    final activePlaces = results[1] as int;

    // Get district name for NCRB lookup via reverse geocoding
    String district = '';
    String state = '';
    try {
      final placemarks = await placemarkFromCoordinates(
          loc.latitude, loc.longitude);
      if (placemarks.isNotEmpty) {
        district = placemarks.first.subAdministrativeArea ?? '';
        state = placemarks.first.administrativeArea ?? '';
      }
    } catch (e) {
      debugPrint('[SafetyFeatures] Geocode error: $e');
    }

    // NCRB crime index lookup
    final crimeIndex = CrimeDataset.getCrimeIndex(district, state: state);

    // Estimate distances to police/hospital based on count.
    // If found in 2km radius → ~1000m avg, else 5000m default.
    final policeDistance = (envData['police'] ?? 0) > 0 ? 800.0 : 5000.0;
    final hospitalDistance = (envData['hospitals'] ?? 0) > 0 ? 1200.0 : 5000.0;

    return SafetyFeatureVector(
      streetLights: envData['lights'] ?? 0,
      shops: envData['shops'] ?? 0,
      cctvCount: envData['cctv'] ?? 0,
      policeStationDistanceM: policeDistance,
      hospitalDistanceM: hospitalDistance,
      busStops: envData['busStops'] ?? 0,
      historicalCrimeIndex: crimeIndex,
      communityReportPenalty: communityReportPenalty,
      timeOfDayFactor: SafetyFeatureVector.computeTimeOfDayFactor(),
      activePlaces: activePlaces,
    );
  }

  Future<int> fetchActivePlaces(LatLng loc) async {
    try {
      final url = Uri.parse(
        'https://api.foursquare.com/v3/places/search'
            '?ll=${loc.latitude},${loc.longitude}&radius=500&limit=20',
      );

      final res = await http.get(url, headers: {
        'Authorization': const String.fromEnvironment('FSQ_API_KEY'),
      });

      if (res.statusCode != 200) return 0;

      final data = json.decode(res.body);
      final places = data['results'] as List;

      return places.length; // simple proxy: more places = safer
    } catch (e) {
      debugPrint('[Foursquare] error: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> searchSuggestions(String query, {LatLng? proximity}) async {
    try {
      String bias = '';
      if (proximity != null) {
        // Create a ~100km viewbox around the proximity point
        final left   = proximity.longitude - 1.0;
        final right  = proximity.longitude + 1.0;
        final top    = proximity.latitude  + 1.0;
        final bottom = proximity.latitude  - 1.0;
        bias = '&viewbox=$left,$top,$right,$bottom&bounded=0';
      } else {
        // Default bias for Chhattisgarh, India (approximate bounding box)
        // viewbox: left,top,right,bottom (lon_min, lat_max, lon_max, lat_min)
        bias = '&viewbox=80.25,24.10,84.40,17.78&bounded=0';
      }

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(query)}'
            '&format=json'
            '&addressdetails=1'
            '&limit=8'
            '&countrycodes=in' // Prioritize/Restrict results to India
            '$bias',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'com.saferoute.app',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[LocationService] searchSuggestions error: $e');
    }
    return [];
  }

  /// Finds the absolute nearest amenity of a specific type (e.g., 'police', 'hospital')
  /// using high-precision Overpass API queries.
  Future<Map<String, dynamic>?> findNearestAmenity(LatLng loc, String type) async {
    try {
      String filter = '';
      if (type == 'bus') {
        filter = '''
        node["highway"="bus_stop"](around:15000, ${loc.latitude}, ${loc.longitude});
        way["highway"="bus_stop"](around:15000, ${loc.latitude}, ${loc.longitude});
        node["amenity"="bus_station"](around:15000, ${loc.latitude}, ${loc.longitude});
        way["amenity"="bus_station"](around:15000, ${loc.latitude}, ${loc.longitude});
        ''';
      } else {
        filter = '''
        node["amenity"="$type"](around:15000, ${loc.latitude}, ${loc.longitude});
        way["amenity"="$type"](around:15000, ${loc.latitude}, ${loc.longitude});
        ''';
      }
      
      final query = '''
      [out:json][timeout:15];
      (
$filter
      );
      out center;
      ''';

      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return null;

      final data = json.decode(res.body);
      final List elements = data['elements'] ?? [];
      if (elements.isEmpty) return null;

      // Sort by absolute distance (double-precision meters)
      elements.sort((a, b) {
        final latA = double.tryParse((a['lat'] ?? a['center']?['lat'] ?? 0).toString()) ?? 0;
        final lonA = double.tryParse((a['lon'] ?? a['center']?['lon'] ?? 0).toString()) ?? 0;
        final latB = double.tryParse((b['lat'] ?? b['center']?['lat'] ?? 0).toString()) ?? 0;
        final lonB = double.tryParse((b['lon'] ?? b['center']?['lon'] ?? 0).toString()) ?? 0;
        
        final distA = distanceBetween(loc, LatLng(latA, lonA));
        final distB = distanceBetween(loc, LatLng(latB, lonB));
        return distA.compareTo(distB);
      });

      final nearest = elements.first;
      final lat = double.tryParse((nearest['lat'] ?? nearest['center']?['lat'] ?? 0).toString()) ?? 0;
      final lon = double.tryParse((nearest['lon'] ?? nearest['center']?['lon'] ?? 0).toString()) ?? 0;
      final tags = nearest['tags'] ?? {};
      final name = tags['name'] ?? 'Nearest ${type.capitalize()}';

      return {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'display_name': '$name, ${tags['addr:street'] ?? 'Nearby'}',
      };
    } catch (e) {
      debugPrint('[Nearest discovery] Error: $e');
      return null;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
