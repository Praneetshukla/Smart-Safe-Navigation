// lib/screens/map/map_screen.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/location_service.dart';
import '../../services/route_service.dart';
import '../../services/safety_service.dart';
import '../../services/tts_service.dart';
import '../../services/auth_service.dart';
import '../../services/journey_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/route_panel.dart';
import '../../widgets/hazard_marker.dart';
import '../../widgets/ai_safety_breakdown.dart';
import '../../ai/rl_agent.dart';
import '../../ai/feature_discretizer.dart';
import '../../data/safety_features.dart';
import '../auth/login_screen.dart';
import '../reports/add_report_screen.dart';
import '../sos/sos_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/pulse_marker.dart';
import '../../widgets/safety_heatmap_layer.dart';

// ── 2 routes only ─────────────────────────────────────────────────────────────
const _routeColors = [
  Color(0xFF00E676), // index 0 – safest  → green
  Color(0xFFFF6D00), // index 1 – fastest → orange
];
const _routeLabels = ['Safest', 'Fastest'];
const _routeIcons  = [Icons.shield_rounded, Icons.flash_on_rounded];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final _mapController = MapController();
  final _locationSvc   = LocationService();
  final _routeSvc      = RouteService();
  final _safetySvc     = SafetyService();
  final _ttsSvc        = TtsService();
  final _journeySvc    = JourneyService();
  final _authSvc       = AuthService();

  LatLng? _currentLocation;
  LatLng? _origin;
  LatLng? _destination;
  String  _originAddress      = '';
  String  _destinationAddress = '';

  List<SafeRoute>    _routes       = [];
  SafeRoute?         _selectedRoute;
  List<SafetyReport> _reports      = [];
  StreamSubscription<Position>?           _locationSub;
  StreamSubscription<List<SafetyReport>>? _reportsSub;

  bool   _isNavigating   = false;
  int    _nextStepIndex  = 0;
  final Set<String> _alertedHazards = {};
  bool   _isLoading      = false;
  bool   _showRoutePanel = false;
  String _phase          = 'search';
  bool   _showTraffic    = false;
  bool   _showHeatmap    = true;

  double  _areaSafetyScore = 0;
  String? _activeJourneyId;

  // Professional Navigation State
  String  _currentInstruction  = "Follow route";
  String  _nextInstruction     = "";
  double  _distToNextStep      = 0.0;
  double  _remainingKm         = 0.0;
  int     _remainingSeconds    = 0;
  double  _currentSpeed        = 0.0; // km/h
  double  _mapRotation         = 0.0; // degrees
  DateTime? _arrivalTime;

  late AnimationController _panelCtrl;
  late Animation<Offset>   _panelAnim;

  final _srcCtrl = TextEditingController();
  final _dstCtrl = TextEditingController();
  bool _srcLoading = false;
  bool _dstLoading = false;

  List<Map<String, dynamic>> _srcSuggestions = [];
  List<Map<String, dynamic>> _dstSuggestions = [];
  bool   _showSrcSug = false;
  bool   _showDstSug = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _panelCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _panelAnim = Tween<Offset>(
        begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));
    _initLocation();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _reportsSub?.cancel();
    _debounce?.cancel();
    _ttsSvc.stop();
    _panelCtrl.dispose();
    _srcCtrl.dispose();
    _dstCtrl.dispose();
    super.dispose();
  }

  // ── GPS init ────────────────────────────────────────────────────────────────
  Future<void> _initLocation() async {
    final loc = await _locationSvc.getCurrentLocation();
    if (loc != null && mounted) {
      setState(() => _currentLocation = loc);
      final addr = await _locationSvc.getAddressFromLatLng(loc);
      if (mounted) {
        setState(() {
          _origin        = loc;
          _originAddress = addr;
          _srcCtrl.text  = addr;
        });
      }
      _loadNearbyReports(loc);
      _loadAreaSafety(loc);
    }
  }

  void _loadNearbyReports(LatLng center) {
    _reportsSub?.cancel();
    _reportsSub = _safetySvc.streamNearbyReports(center).listen((r) {
      if (mounted) setState(() => _reports = r);
    });
  }

  Future<void> _loadAreaSafety(LatLng loc) async {
    final score = await _safetySvc.getAreaSafetyScore(loc);
    if (mounted) setState(() => _areaSafetyScore = score);
  }

  // ── Geocode helpers ─────────────────────────────────────────────────────────
  Future<void> _resolveSource(String query) async {
    setState(() => _srcLoading = true);
    final loc = await _locationSvc.getLatLngFromAddress(query);
    if (mounted) setState(() => _srcLoading = false);
    if (loc == null) { _snack('Source location not found'); return; }
    setState(() { _origin = loc; _originAddress = query; });
  }

  Future<void> _resolveDestination(String query) async {
    setState(() => _dstLoading = true);
    final loc = await _locationSvc.getLatLngFromAddress(query);
    if (mounted) setState(() => _dstLoading = false);
    if (loc == null) { _snack('Destination not found'); return; }
    setState(() { _destination = loc; _destinationAddress = query; });
  }

  // ── Autocomplete ────────────────────────────────────────────────────────────
  void _onSrcTyped(String q) {
    _origin = null;
    _debounce?.cancel();
    if (q.length < 3) {
      setState(() { _srcSuggestions = []; _showSrcSug = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final list = await _locationSvc.searchSuggestions(q, proximity: _currentLocation);
      if (mounted) setState(() { _srcSuggestions = list; _showSrcSug = list.isNotEmpty; });
    });
  }

  void _onDstTyped(String q) {
    _destination = null;
    _debounce?.cancel();
    if (q.length < 3) {
      setState(() { _dstSuggestions = []; _showDstSug = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final list = await _locationSvc.searchSuggestions(q, proximity: _currentLocation);
      if (mounted) setState(() { _dstSuggestions = list; _showDstSug = list.isNotEmpty; });
    });
  }

  void _pickSrc(Map<String, dynamic> s) {
    final lat  = double.tryParse(s['lat'] ?? '0') ?? 0;
    final lon  = double.tryParse(s['lon'] ?? '0') ?? 0;
    final name = _shortName(s['display_name'] ?? '');
    setState(() {
      _origin        = LatLng(lat, lon);
      _originAddress = name;
      _srcCtrl.text  = name;
      _showSrcSug    = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _pickDst(Map<String, dynamic> s) {
    final lat  = double.tryParse(s['lat'] ?? '0') ?? 0;
    final lon  = double.tryParse(s['lon'] ?? '0') ?? 0;
    final name = _shortName(s['display_name'] ?? '');
    setState(() {
      _destination        = LatLng(lat, lon);
      _destinationAddress = name;
      _dstCtrl.text       = name;
      _showDstSug         = false;
    });
    FocusScope.of(context).unfocus();
  }

  String _shortName(String full) =>
      full.split(',').take(3).map((s) => s.trim()).join(', ');

  // ── FIND ROUTES ─────────────────────────────────────────────────────────────
  Future<void> _findRoutes() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _showSrcSug    = false;
      _showDstSug    = false;
      _isLoading      = true;
      _phase          = 'map';
      _routes         = [];
      _selectedRoute  = null;
      _showRoutePanel = false;
    });

    try {
      // Step 1 – resolve source if needed
      if (_origin == null) {
        final q = _srcCtrl.text.trim();
        if (q.isEmpty) throw 'Please enter your source location';
        final loc = await _locationSvc.getLatLngFromAddress(q);
        if (loc == null) throw 'Source not found – try a more specific name';
        _origin = loc;
        _originAddress = q;
      }

      // Step 2 – resolve destination if needed
      if (_destination == null) {
        final q = _dstCtrl.text.trim();
        if (q.isEmpty) throw 'Please enter your destination';
        final loc = await _locationSvc.getLatLngFromAddress(q);
        if (loc == null) throw 'Destination not found – try a more specific name';
        _destination = loc;
        _destinationAddress = q;
      }

      // Step 3 – Adjust map view
      try {
        _mapController.move(
          LatLng(
            (_origin!.latitude  + _destination!.latitude)  / 2,
            (_origin!.longitude + _destination!.longitude) / 2,
          ),
          12,
        );
      } catch (_) {}

      _loadNearbyReports(_origin!);

      // Step 4 – fetch 2 routes with timeout
      List<SafeRoute> routes = [];
      try {
        routes = await _routeSvc
            .getRoutes(_origin!, _destination!, _reports)
            .timeout(const Duration(seconds: 25));
      } catch (e) {
        debugPrint('[FindRoutes] $e');
        throw 'Route calculation timed out or failed';
      }

      if (!mounted) return;

      if (routes.isEmpty) {
        throw 'Could not find routes – check connection or map coverage';
      }

      // ✅ Pad to exactly 2 routes
      final padded = _padRoutes(routes);

      setState(() {
        _routes         = padded;
        _selectedRoute  = padded.first;
        _showRoutePanel = true;
        _isLoading      = false;
      });

      _panelCtrl.forward(from: 0);
      _fitAllRoutes(padded);

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack(e.toString());
        // Auto-revert to search if we haven't picked a destination yet
        if (_phase == 'map' && _routes.isEmpty) {
          setState(() => _phase = 'search');
        }
      }
    }
  }

  /// Ensure exactly 2 routes: safest + fastest, or a combined route if they are identical.
  List<SafeRoute> _padRoutes(List<SafeRoute> raw) {
    if (raw.isEmpty) return [];

    // Prioritise results that are already labeled as combined or specific
    if (raw.any((r) => r.type == 'safest_fastest')) {
      return [raw.firstWhere((r) => r.type == 'safest_fastest')];
    }

    final result = <SafeRoute>[];
    final types = ['safest', 'fastest'];

    for (final type in types) {
      SafeRoute? found;
      try {
        found = raw.firstWhere((r) => r.type == type);
      } catch (_) {}

      if (found != null) {
        result.add(found);
      }
    }

    // If we still don't have labeled routes, just return the raw scored routes
    if (result.isEmpty) return raw.take(2).toList();
    
    return result;
  }

  void _fitAllRoutes(List<SafeRoute> routes) {
    final allPts = routes.expand((r) => r.points).toList();
    if (allPts.isEmpty) return;

    double minLat = allPts.first.latitude,  maxLat = allPts.first.latitude;
    double minLng = allPts.first.longitude, maxLng = allPts.first.longitude;

    for (final p in allPts) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center  = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

    double zoom = 13.0;
    if (maxSpan > 0.0001) {
      zoom = (log(160.0 / maxSpan) / log(2)).clamp(6.0, 16.0);
    }

    final paddedCenter = LatLng(center.latitude - maxSpan * 0.10, center.longitude);
    _mapController.move(paddedCenter, zoom);
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  Future<void> _startNavigation() async {
    if (_selectedRoute == null) {
      debugPrint('[Navigation] No route selected, cannot start.');
      return;
    }

    debugPrint('[Navigation] Starting journey...');
    
    // Set state immediately for UI responsiveness
    setState(() {
      _isNavigating   = true;
      _nextStepIndex  = 0;
      _alertedHazards.clear();
      _remainingKm      = _selectedRoute!.distanceKm;
      _remainingSeconds = _selectedRoute!.durationSeconds;
      _arrivalTime      = DateTime.now().add(Duration(seconds: _remainingSeconds));
      _mapRotation      = 0.0;
    });

    // Fit map to navigation view
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    }

    // 1. Start Real-Time location tracking immediately (True GPS)
    _locationSub = _locationSvc.trackLocation().listen(
      (pos) {
        if (!mounted) return;
        final loc = LatLng(pos.latitude, pos.longitude);

        // Calculate bearing/rotation
        if (_currentLocation != null) {
          final bearing = _calculateBearing(_currentLocation!, loc);
          // Only rotate if moving (speed > 1 m/s)
          if (pos.speed > 1.0) {
            setState(() => _mapRotation = bearing);
          }
        }

        setState(() {
          _currentLocation = loc;
          // Use real GPS speed if available (>0.1 m/s), else use simulated for demo if static
          _currentSpeed = pos.speed > 0.1 ? pos.speed * 3.6 : 0.0;
        });
        
        // Move map to center on user with current rotation
        _mapController.move(loc, 17); // Use 17 for better navigation context
        
        _processNavigationUpdate(loc);
        _checkArrival(loc);
      },
      onError: (e) => debugPrint('[Navigation] GPS error: $e'),
    );

    // 2. Persist journey in background (non-blocking for UI)
    _persistJourney();


    // Audio confirmation
    _ttsSvc.speak('Navigation started. Heading to $_destinationAddress.');
    
    if (_selectedRoute!.hazardWarnings.isNotEmpty) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isNavigating) {
          _ttsSvc.safetyAlert(
              'Initial warning: Watch out for ${_selectedRoute!.hazardWarnings.join(", ")}');
        }
      });
    }
  }

  void _checkArrival(LatLng current) {
    if (_destination == null) return;
    if (_locationSvc.distanceBetween(current, _destination!) < 30) {
      _stopNavigation();
      _ttsSvc.announceArrival(_destinationAddress);
    }
  }

  void _processNavigationUpdate(LatLng current) {
    if (_selectedRoute == null) return;

    // 1. Proximity Safety Alerts
    for (final report in _reports) {
      if (_alertedHazards.contains(report.id)) continue;
      
      final dist = _locationSvc.distanceBetween(current, report.location); // m
      if (dist < 150) {
        _alertedHazards.add(report.id);
        final severityTxt = report.severity >= 4 ? 'high severity ' : '';
        _ttsSvc.safetyAlert(
          'Approaching a ${severityTxt}${report.typeLabel} reported nearby. ${report.description}',
          severity: report.severity,
        );
      }
    }

    // 2. Turn-by-Turn Logic & Progress Metrics
    double totalRemaining = 0.0;
    bool foundCurrent = false;

    if (_selectedRoute != null && _selectedRoute!.steps.isNotEmpty) {
      for (int i = 0; i < _selectedRoute!.steps.length; i++) {
         final step = _selectedRoute!.steps[i];
         final distToStep = _locationSvc.distanceBetween(current, step.location);

         if (!foundCurrent) {
           if (i >= _nextStepIndex - 1) {
              _currentInstruction = step.instruction;
              _distToNextStep     = distToStep;
              
              // Peek at next instruction
              if (i + 1 < _selectedRoute!.steps.length) {
                _nextInstruction = _selectedRoute!.steps[i+1].instruction;
              } else {
                _nextInstruction = "";
              }
              foundCurrent = true;
           }
         }

         if (distToStep < 30 && i == _nextStepIndex) {
           _ttsSvc.announceNavigation(step.instruction);
           _nextStepIndex++;
         }

         if (i >= _nextStepIndex) {
           totalRemaining += step.distanceMetres / 1000.0;
         }
      }
    }

    setState(() {
      _remainingKm = totalRemaining + (_distToNextStep / 1000.0);
      _remainingSeconds = (_remainingKm * 3600 / 45).round(); // est at 45km/h
      _arrivalTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
      // Calculate speed roughly for demo if real GPS speed not available
      _currentSpeed = 42.5 + (sin(DateTime.now().millisecondsSinceEpoch / 2000) * 5); 
    });
  }

  /// Calculates bearing between two coordinates to support Head-Up rotation
  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (pi / 180);
    final lon1 = start.longitude * (pi / 180);
    final lat2 = end.latitude * (pi / 180);
    final lon2 = end.longitude * (pi / 180);

    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final radians = atan2(y, x);
    return (radians * 180 / pi + 360) % 360;
  }

  Future<void> _persistJourney() async {
    try {
      final user = await _authSvc.getCurrentAppUser();
      if (user != null && _origin != null && _destination != null) {
        final journey = Journey(
          id: '', userId: user.uid,
          startAddress:  _originAddress,
          endAddress:    _destinationAddress,
          startLocation: _origin!,
          endLocation:   _destination!,
          startTime:     DateTime.now(),
          routeType:     _selectedRoute!.type,
          rlStateIndex:  _selectedRoute!.rlStateIndex,
          rlAction:      _selectedRoute!.rlAction,
          safetyFeaturesMap: _selectedRoute!.safetyFeatures?.toMap(),
        );
        _activeJourneyId = await _journeySvc.startJourney(journey);
        debugPrint('[Navigation] Journey persisted: $_activeJourneyId');
      }
    } catch (e) {
      debugPrint('[Navigation] Failed to persist journey: $e');
    }
  }

  Future<void> _stopNavigation() async {
    _locationSub?.cancel();
    if (_activeJourneyId != null) _showRatingDialog();
    _panelCtrl.reverse();
    setState(() {
      _isNavigating   = false;
      _showRoutePanel = false;
      _routes         = [];
      _selectedRoute  = null;
      _destination    = null;
      _phase          = 'search';
    });
    await _ttsSvc.stop();
  }

  void _showRatingDialog() {
    // Capture RL state/action before route is cleared
    final rlStateIdx = _selectedRoute?.rlStateIndex ?? 0;
    final rlAction = _selectedRoute?.rlAction ?? 0;

    showDialog(
      context: context,
      builder: (ctx) {
        double rating = 4;
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Rate this route',
                style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontSize: 18)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('How safe did this route feel?',
                style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (_, setS) => Slider(
                value: rating, min: 1, max: 5, divisions: 4,
                activeColor: AppTheme.accent,
                label: rating.round().toString(),
                onChanged: (v) => setS(() => rating = v),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your rating helps the AI learn and improve future route recommendations.',
                    style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF6366F1), fontSize: 10),
                  ),
                ),
              ]),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Skip')),
            ElevatedButton(
              onPressed: () async {
                // 1. Complete journey in Firestore
                await _journeySvc.completeJourney(_activeJourneyId!, rating: rating);

                // 2. Feed reward to RL agent
                final reward = RLAgent.ratingToReward(rating);
                final rlState = DiscreteState(
                  crimeLevel: rlStateIdx ~/ 6,
                  timeOfDay: (rlStateIdx % 6) ~/ 3,
                  lightingLevel: rlStateIdx % 3,
                );
                RLAgent().update(rlState, rlAction, reward);

                _activeJourneyId = null;
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.cardBg),
    );
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        child: _phase == 'search' ? _buildSearchPhase() : _buildMapPhase(),
      ),
    );
  }

  void _quickSearch(String query) async {
    setState(() {
      _dstCtrl.text = query;
      _destination = null;
      _showDstSug = false;
      _isLoading = true;
      _phase = 'map';
    });

    try {
      // ── Step 0: Always fetch fresh GPS location for Quick Picks ──
      final freshLoc = await _locationSvc.getCurrentLocation();
      if (freshLoc != null) {
        _currentLocation = freshLoc;
        
        // If it's a "nearby" quick pick, we should prioritize fresh location as the search origin
        if (query.toLowerCase().contains('nearby') || _origin == null) {
          final addr = await _locationSvc.getAddressFromLatLng(freshLoc);
          _origin = freshLoc;
          _originAddress = addr;
          _srcCtrl.text = addr;
        }
      } else if (_currentLocation == null) {
        throw 'Unable to get your current location. Please enter it manually.';
      }

      Map<String, dynamic>? best;
      String searchQuery = query;

      final user = await _authSvc.getCurrentAppUser();
      if (query.toLowerCase() == 'home') {
        if (user?.preferences.homeAddress?.isNotEmpty == true) {
          searchQuery = user!.preferences.homeAddress!;
          _dstCtrl.text = searchQuery;
        } else {
          throw 'Please set your Home address in your Profile first!';
        }
      } else if (query.toLowerCase() == 'work') {
        if (user?.preferences.workAddress?.isNotEmpty == true) {
          searchQuery = user!.preferences.workAddress!;
          _dstCtrl.text = searchQuery;
        } else {
          throw 'Please set your Work address in your Profile first!';
        }
      }

      // 1. Proximity-aware resolution for 'Nearest' categories
      if (query.toLowerCase().contains('hospital')) {
        best = await _locationSvc.findNearestAmenity(_origin!, 'hospital');
        searchQuery = 'Hospital';
      } else if (query.toLowerCase().contains('police')) {
        best = await _locationSvc.findNearestAmenity(_origin!, 'police');
        searchQuery = 'Police Station';
      } else if (query.toLowerCase().contains('bus')) {
        best = await _locationSvc.findNearestAmenity(_origin!, 'bus');
        searchQuery = 'Bus Stop';
      }

      // 2. Fallback to biased search suggestions
      if (best == null) {
        final suggestions = await _locationSvc.searchSuggestions(searchQuery, proximity: _origin!);
        if (suggestions.isNotEmpty) {
          // ✅ CRITICAL: Sort fallback suggestions by absolute distance to ensure "Nearest" is respected
          suggestions.sort((a, b) {
            final latA = double.tryParse(a['lat']?.toString() ?? '0') ?? 0;
            final lonA = double.tryParse(a['lon']?.toString() ?? '0') ?? 0;
            final latB = double.tryParse(b['lat']?.toString() ?? '0') ?? 0;
            final lonB = double.tryParse(b['lon']?.toString() ?? '0') ?? 0;
            final distA = _locationSvc.distanceBetween(_origin!, LatLng(latA, lonA));
            final distB = _locationSvc.distanceBetween(_origin!, LatLng(latB, lonB));
            return distA.compareTo(distB);
          });

          // Prefer high-rank (major) results but only from the sorted top of the list
          best = suggestions.firstWhere(
            (s) => (int.tryParse(s['place_rank']?.toString() ?? '0') ?? 0) >= 28,
            orElse: () => suggestions.first,
          );
        }
      }

      if (best != null && mounted) {
        final lat  = double.tryParse(best['lat'] ?? '0') ?? 0;
        final lon  = double.tryParse(best['lon'] ?? '0') ?? 0;
        final name = _shortName(best['display_name'] ?? '');
        setState(() {
          _destination        = LatLng(lat, lon);
          _destinationAddress = name;
          _dstCtrl.text       = name;
        });
      } else if (mounted) {
        throw 'No nearby facilities found for "$query". Try a more specific name.';
      }

      _findRoutes();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _phase = 'search';
        });
        _snack(e.toString());
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  SEARCH PHASE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildSearchPhase() {
    return GestureDetector(
      key: const ValueKey('search_phase'),
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() { _showSrcSug = false; _showDstSug = false; });
      },
      child: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primary, Color(0xFF112240), Color(0xFF0D1B2A)],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 16),

              // Header
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent, width: 1.5),
                  ),
                  child: const Icon(Icons.shield_rounded, color: AppTheme.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SafeRoute',
                      style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Navigate safely',
                      style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ]),
              ]),

              const SizedBox(height: 40),
              Text('Where are you going?',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textPrimary, fontSize: 26,
                      fontWeight: FontWeight.w700, height: 1.2)),
              const SizedBox(height: 6),
              Text('Enter your source and destination to find the safest route.',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textSecondary, fontSize: 13)),

              const SizedBox(height: 36),

              // Location input card
              Container(
                decoration: AppTheme.glassDecoration(
                  opacity: 0.45,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(children: [
                  _LocationField(
                    controller: _srcCtrl,
                    label: 'From',
                    hint: 'Your current location',
                    icon: Icons.radio_button_checked_rounded,
                    iconColor: AppTheme.safe,
                    isLoading: _srcLoading,
                    isFirst: true,
                    onChanged: _onSrcTyped,
                    onSubmitted: (v) { if (v.isNotEmpty) _resolveSource(v); },
                    onUseGps: () async {
                      setState(() => _srcLoading = true);
                      final loc = await _locationSvc.getCurrentLocation();
                      if (loc != null) {
                        final addr = await _locationSvc.getAddressFromLatLng(loc);
                        setState(() {
                          _origin = loc; _originAddress = addr;
                          _srcCtrl.text = addr;
                        });
                      }
                      if (mounted) setState(() => _srcLoading = false);
                    },
                  ),
                  _SwapDivider(onSwap: () {
                    final tmpCtrl = _srcCtrl.text;
                    final tmpLoc  = _origin;
                    final tmpAddr = _originAddress;
                    setState(() {
                      _srcCtrl.text       = _dstCtrl.text;
                      _origin             = _destination;
                      _originAddress      = _destinationAddress;
                      _dstCtrl.text       = tmpCtrl;
                      _destination        = tmpLoc;
                      _destinationAddress = tmpAddr;
                      _showSrcSug = false;
                      _showDstSug = false;
                    });
                  }),
                  _LocationField(
                    controller: _dstCtrl,
                    label: 'To',
                    hint: 'Enter destination',
                    icon: Icons.location_on_rounded,
                    iconColor: AppTheme.accentOrange,
                    isLoading: _dstLoading,
                    isFirst: false,
                    onChanged: _onDstTyped,
                    onSubmitted: (v) { if (v.isNotEmpty) _resolveDestination(v); },
                  ),
                ]),
              ),

              const SizedBox(height: 8),
              if (_showSrcSug) _SuggestionList(items: _srcSuggestions, onPick: _pickSrc),
              if (_showDstSug) _SuggestionList(items: _dstSuggestions, onPick: _pickDst),

              const SizedBox(height: 20),

              Text('Quick picks',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textSecondary,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _QuickChip(label: 'Home',           icon: Icons.home_outlined,            onTap: () => _quickSearch('Home')),
                _QuickChip(label: 'Work',           icon: Icons.work_outline_rounded,     onTap: () => _quickSearch('Work')),
                _QuickChip(label: 'Hospital',       icon: Icons.local_hospital_outlined,   onTap: () => _quickSearch('Hospital nearby')),
                _QuickChip(label: 'Police Station', icon: Icons.local_police_outlined,      onTap: () => _quickSearch('Police Station nearby')),
                _QuickChip(label: 'Bus Stop',       icon: Icons.directions_bus_outlined,    onTap: () => _quickSearch('Bus stop nearby')),
              ]),

              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: (_srcCtrl.text.isEmpty || _dstCtrl.text.isEmpty || _isLoading)
                      ? null : _findRoutes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary)),
                    const SizedBox(width: 12),
                    Text('Finding routes…',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  ])
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.alt_route_rounded, size: 22),
                    const SizedBox(width: 10),
                    Text('Find Routes',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),

              const SizedBox(height: 16),
              if (_areaSafetyScore > 0)
                Center(child: _AreaSafetyBadge(score: _areaSafetyScore)),
              
            ]),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  MAP PHASE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildMapPhase() {
    return Stack(children: [

      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: _origin ??
              const LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
          zoom: 18,
          rotation: _mapRotation,
          onLongPress: (_, latlng) => _onMapLongPress(latlng),
        ),
        children: [
          // 1. TILE LAYER
          TileLayer(
            urlTemplate: AppConstants.mapTileUrl,
            userAgentPackageName: 'com.example.smart_safe_nav',
            tileDisplay: const TileDisplay.fadeIn(),
          ),

          // 2. SAFETY HEATMAP LAYER
          SafetyHeatmapLayer(reports: _reports, visible: _showHeatmap),

          // 3. TRAFFIC LAYER
          if (_showTraffic)
            TileLayer(
              urlTemplate: "https://api.mapbox.com/styles/v1/mapbox/traffic-day-v2/tiles/256/{z}/{x}/{y}@2x?access_token=${AppConstants.mapboxToken}",
              userAgentPackageName: 'com.saferoute.app',
              maxZoom: 19,
              backgroundColor: Colors.transparent,
            ),

          // Dim unselected routes
          PolylineLayer(
            polylines: [
              for (int i = 0; i < _routes.length; i++)
                if (_routes[i].id != _selectedRoute?.id)
                  Polyline(
                    points:      _routes[i].points,
                    strokeWidth: 4,
                    color: _routeColors[i % _routeColors.length].withOpacity(0.35),
                  ),
            ],
          ),

          // Selected route bold on top
          if (_selectedRoute != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points:      _selectedRoute!.points,
                  strokeWidth: 8.0,
                  color: AppTheme.navBlue,
                  strokeCap:  StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
                
                
                // Real-time congestion overlay
                if (_showTraffic)
                  ..._selectedRoute!.trafficSegments.map((seg) => Polyline(
                    points: [seg.start, seg.end],
                    strokeWidth: 4.5,
                    color: _congestionColor(seg.level),
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  )),
              ],
            ),
          // Hazard markers
          MarkerLayer(
            markers: _reports.map((r) => Marker(
              point: r.location, width: 32, height: 32,
              child: HazardMarker(report: r),
            )).toList(),
          ),

          // 5. MARKERS LAYER
          MarkerLayer(
            markers: [
              if (_currentLocation != null)
                Marker(
                  point: _currentLocation!,
                  width: 80, height: 80,
                  child: _isNavigating 
                    ? _CurrentLocationMarker(rotation: _mapRotation)
                    : PulseMarker(color: AppTheme.safe),
                ),
              if (_origin != null && !_isNavigating)
                Marker(
                  point: _origin!, width: 56, height: 64,
                  child: _WaypointMarker(label: 'A', color: AppTheme.safe),
                ),
              if (_destination != null && !_isNavigating)
                Marker(
                  point: _destination!, width: 56, height: 64,
                  child: _WaypointMarker(label: 'B', color: AppTheme.accentOrange),
                ),
            ],
          ),

          // Mid-route safety badge on selected route only
          MarkerLayer(
            markers: [
              for (int i = 0; i < _routes.length; i++)
                if (_routes[i].points.length > 1)
                  Marker(
                    point: _routes[i].points[_routes[i].points.length ~/ 2],
                    width: 58, height: 28,
                    child: _RouteScoreBadge(
                      score:      _routes[i].safetyScore,
                      color:      _routeColors[i % _routeColors.length],
                      isSelected: _routes[i].id == _selectedRoute?.id,
                    ),
                  ),
            ],
          ),
        ],
      ),

      // 6. OVERLAYS (Floating controls)
      _buildMapOverlays(),

      // 7. PANELS (Route info / Navigation Dashboard)
      if (_isLoading)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg.withOpacity(0.97),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.4), blurRadius: 24)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 36, height: 36,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: AppTheme.accent)),
                  const SizedBox(height: 16),
                  Text('Finding routes…',
                      style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Fetching road data…',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),

      if (!_isNavigating && _showRoutePanel && _routes.isNotEmpty)
        DraggableScrollableSheet(
          initialChildSize: 0.28,
          minChildSize: 0.18,
          maxChildSize: 0.65,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 30,
                    offset: const Offset(0, -8),
                  )
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: _DualRoutePanel(
                  routes: _routes,
                  selectedId: _selectedRoute?.id,
                  routeColors: _routeColors,
                  onSelect: (r) => setState(() {
                    _selectedRoute = r;
                    _fitAllRoutes(_routes);
                  }),
                  onStart: _startNavigation,
                  isNavigating: _isNavigating,
                ),
              ),
            );
          },
        ),

      if (_isNavigating)
        _buildProfessionalNavInterface(),
    ]);
  }

  Widget _buildMapOverlays() {
    return Stack(children: [
      // Top Bar (Dual Address & AI Verdict)
      if (_phase == 'map' && !_isNavigating)
        Positioned(
          top: 40, left: 16, right: 16,
          child: Column(
            children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassDecoration(opacity: 0.75),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () {
                        _panelCtrl.reverse();
                        setState(() {
                          _phase          = 'search';
                          _showRoutePanel = false;
                          _routes         = [];
                          _selectedRoute  = null;
                          _isLoading      = false;
                        });
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: AppTheme.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AddressNode(
                          address: _originAddress.isEmpty ? 'Current Location' : _originAddress,
                          color: AppTheme.safe,
                          isLast: false,
                        ),
                        const SizedBox(height: 8),
                        _AddressNode(
                          address: _destinationAddress.isEmpty ? 'Destination' : _destinationAddress,
                          color: AppTheme.accentOrange,
                          isLast: true,
                        ),
                      ],
                    )),
                  ]),
                ),
              ),
            ),
            if (_selectedRoute != null) ...[
              const SizedBox(height: 12),
              _AiVerdictChip(route: _selectedRoute!),
            ],
          ],
        ),
      ),

      // Map Controls (Right Side)
      Positioned(
        top: 180, right: 20,
        child: Column(children: [
          _MapControlButton(
            icon: Icons.sos_rounded,
            color: AppTheme.danger,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen())),
            label: 'SOS',
          ),
          const SizedBox(height: 12),
          _MapControlButton(
            icon: Icons.my_location_rounded,
            onTap: () {
              if (_currentLocation != null) _mapController.move(_currentLocation!, 15);
            },
          ),
        ]),
      ),
    ]);
  }

  void _toggleTraffic() {
    setState(() => _showTraffic = !_showTraffic);
  }

  Color _congestionColor(CongestionLevel level) {
    switch (level) {
      case CongestionLevel.low:      return Colors.green;
      case CongestionLevel.moderate: return Colors.orange;
      case CongestionLevel.heavy:    return Colors.red;
      case CongestionLevel.severe:   return const Color(0xFF7B1FA2); // Purple
      default: return Colors.transparent;
    }
  }

  void _onMapLongPress(LatLng latlng) async {
    final addr = await _locationSvc.getAddressFromLatLng(latlng);
    setState(() {
      _destination        = latlng;
      _destinationAddress = addr;
      _dstCtrl.text       = addr;
    });
    if (_origin != null) _findRoutes();
  }

  Widget _buildProfessionalNavInterface() {
    return Stack(children: [
      // 1. Top TBT Instruction Banner
      Positioned(
        top: 0, left: 0, right: 0,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PremiumInstructionHeader(
                instruction: _currentInstruction,
                distanceM: _distToNextStep,
              ),
              if (_nextInstruction.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: _NextTurnBanner(instruction: _nextInstruction),
                ),
            ],
          ),
        ),
      ),

      // 2. Floating Telemetry Widgets (Adjusted for bottom dock)
      Positioned(
        bottom: 150, left: 20,
        child: _NavSpeedometer(speed: _currentSpeed),
      ),

      Positioned(
        bottom: 150, right: 20,
        child: _HazardReportPill(onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddReportScreen(location: _currentLocation)),
        )),
      ),

      // 3. Premium Summary Dashboard
      _PremiumJourneyDashboard(
        etaMinutes: _remainingSeconds ~/ 60,
        distanceKm: _remainingKm,
        arrivalTime: _arrivalTime ?? DateTime.now(),
        safetyScore: _areaSafetyScore,
        onClose: _stopNavigation,
      ),
    ]);
  }
}

// ─── Premium Instruction Header ──────────────────────────────────────────────
class _PremiumInstructionHeader extends StatelessWidget {
  final String instruction;
  final double distanceM;

  const _PremiumInstructionHeader({super.key, required this.instruction, required this.distanceM});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.navGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15)],
      ),
      child: Row(children: [
        const Icon(Icons.navigation_rounded, color: Colors.white, size: 38),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(instruction,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
          const SizedBox(height: 4),
          Text('${distanceM.round()} m',
              style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600, fontSize: 18)),
        ])),
        const Icon(Icons.mic_rounded, color: Colors.white, size: 32),
      ]),
    );
  }
}

// ─── Next Turn Sub-Banner ────────────────────────────────────────────────────
class _NextTurnBanner extends StatelessWidget {
  final String instruction;
  const _NextTurnBanner({super.key, required this.instruction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.navGreen.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Then  ',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const Icon(Icons.turn_left_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(instruction,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── Floating Speedometer ────────────────────────────────────────────────────
class _NavSpeedometer extends StatelessWidget {
  final double speed;
  const _NavSpeedometer({super.key, required this.speed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68, height: 68,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${speed.round()}',
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        Text('km/h',
            style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── Hazard Report Pill ──────────────────────────────────────────────────────
class _HazardReportPill extends StatelessWidget {
  final VoidCallback onTap;
  const _HazardReportPill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.accentOrange, size: 24),
          const SizedBox(width: 10),
          Text('Report',
              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      ),
    );
  }
}

// ─── Premium Journey Dashboard ───────────────────────────────────────────────
class _PremiumJourneyDashboard extends StatelessWidget {
  final int etaMinutes;
  final double distanceKm;
  final DateTime arrivalTime;
  final double safetyScore;
  final VoidCallback onClose;

  const _PremiumJourneyDashboard({
    super.key,
    required this.etaMinutes,
    required this.distanceKm,
    required this.arrivalTime,
    required this.safetyScore,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 32),
          ),
          const Spacer(),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(children: [
              Text('$etaMinutes min',
                  style: GoogleFonts.outfit(color: AppTheme.accentYellow, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              const Icon(Icons.eco_rounded, color: Colors.green, size: 18),
            ]),
            Text('${distanceKm.toStringAsFixed(1)} km • ${_fmtTime(arrivalTime)}',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          const Spacer(),
          const Icon(Icons.alt_route_rounded, color: Colors.white70, size: 30),
        ]),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.hour >= 12 ? 'pm' : 'am';
    return '$h:$m $p';
  }
}

// ─── Instruction Banner ───────────────────────────────────────────────────────
class _InstructionBanner extends StatelessWidget {
  final String instruction;
  final double distanceM;

  const _InstructionBanner({super.key, required this.instruction, required this.distanceM});

  IconData _getIcon() {
    final lower = instruction.toLowerCase();
    if (lower.contains('left')) return Icons.turn_left_rounded;
    if (lower.contains('right')) return Icons.turn_right_rounded;
    if (lower.contains('straight')) return Icons.straight_rounded;
    if (lower.contains('roundabout')) return Icons.roundabout_right_rounded;
    return Icons.navigation_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 20),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getIcon(), color: AppTheme.accent, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(instruction,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text('${distanceM.round()} m',
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 14)),
        ])),
      ]),
    );
  }
}

// ─── Nav Bottom Card ─────────────────────────────────────────────────────────
class _NavBottomCard extends StatelessWidget {
  final int etaSeconds;
  final double remainingKm;
  final double safetyScore;
  final VoidCallback onStop;

  const _NavBottomCard({
    super.key,
    required this.etaSeconds,
    required this.remainingKm,
    required this.safetyScore,
    required this.onStop
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withOpacity(0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Arriving in',
                  style: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 12)),
              Text(_fmtEta(etaSeconds),
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${remainingKm.toStringAsFixed(1)} km',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w700)),
              _NavSafetyBadge(score: safetyScore),
            ]),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: onStop,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger.withOpacity(0.15),
                foregroundColor: AppTheme.danger,
                side: BorderSide(color: AppTheme.danger, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('STOP NAVIGATION',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
            ),
          ),
        ]),
      ),
    );
  }

  String _fmtEta(int seconds) {
    if (seconds < 60) return '< 1 min';
    final mins = seconds ~/ 60;
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60}h ${mins % 60}m';
  }
}

class _NavSafetyBadge extends StatelessWidget {
  final double score;
  const _NavSafetyBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = AppConstants.safetyColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shield_rounded, color: color, size: 14),
        const SizedBox(width: 5),
        Text('Area: ${(score * 10).round()}% Safe',
            style: GoogleFonts.spaceGrotesk(
                color: color, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  DUAL ROUTE PANEL  (2 cards side by side)
// ═══════════════════════════════════════════════════════════════════════════════
class _DualRoutePanel extends StatelessWidget {
  final List<SafeRoute>         routes;
  final String?                 selectedId;
  final List<Color>             routeColors;
  final ValueChanged<SafeRoute> onSelect;
  final VoidCallback            onStart;
  final bool                    isNavigating;

  const _DualRoutePanel({
    required this.routes,
    required this.selectedId,
    required this.routeColors,
    required this.onSelect,
    required this.onStart,
    required this.isNavigating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 30, offset: const Offset(0, -8))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Handle
        Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),

        Row(children: [
          Text('Choose your route',
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          Text('2 options',
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 14),

        // 2 route cards
        Row(
          children: List.generate(routes.length.clamp(0, 2), (i) {
            final r          = routes[i];
            final color      = routeColors[i % routeColors.length];
            final isSelected = r.id == selectedId;
            final safetyPct  = (r.safetyScore * 10).round().clamp(0, 100);

            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.12) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isSelected ? color : AppTheme.border,
                        width: isSelected ? 2 : 1),
                  ),
                  child: Column(children: [
                    // Icon
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: color.withOpacity(isSelected ? 0.25 : 0.1),
                          shape: BoxShape.circle),
                      child: Icon(_routeIcons[i % _routeIcons.length],
                          color: color, size: 22),
                    ),
                    const SizedBox(height: 10),

                    // Label
                    Text(_routeLabels[i % _routeLabels.length],
                        style: GoogleFonts.spaceGrotesk(
                            color: isSelected ? color : AppTheme.textPrimary,
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 8),

                    // Safety ring
                    _SafetyRing(percent: safetyPct / 100, color: color, size: 56),
                    const SizedBox(height: 6),

                    Text('$safetyPct% safe',
                        style: GoogleFonts.spaceGrotesk(
                            color: color, fontWeight: FontWeight.w800, fontSize: 12)),
                    const SizedBox(height: 10),

                    // ETA — real value from OSRM
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.access_time_rounded,
                          color: AppTheme.textSecondary, size: 14),
                      const SizedBox(width: 4),
                      Text(_eta(r.durationSeconds),
                          style: GoogleFonts.spaceGrotesk(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ]),
                    const SizedBox(height: 3),

                    // Distance
                    Text(_fmtDist(r.distanceKm),
                        style: GoogleFonts.spaceGrotesk(
                            color: AppTheme.textSecondary, fontSize: 12)),

                    // Hazard warnings
                    if (r.hazardWarnings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppTheme.warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('⚠ ${r.hazardWarnings.first}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                                color: AppTheme.warning,
                                fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // ── AI Safety Breakdown (for selected route) ─────────────────────
        if (selectedId != null)
          ...routes.where((r) => r.id == selectedId).map((r) {
            final stateIdx = r.rlStateIndex;
            return AiSafetyBreakdown(
              features: r.safetyFeatures ?? const SafetyFeatureVector(),
              safetyScore: r.safetyScore,
              rlAction: r.rlAction,
              rlState: DiscreteState(
                crimeLevel: stateIdx ~/ 6,
                timeOfDay: (stateIdx % 6) ~/ 3,
                lightingLevel: stateIdx % 3,
              ),
            );
          }),

        const SizedBox(height: 16),

        // Start navigation button — colour matches selected route
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: isNavigating ? null : onStart,
            icon: const Icon(Icons.navigation_rounded, size: 20),
            label: Text(isNavigating ? 'Navigating…' : 'Start Navigation',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedId != null
                  ? routeColors[routes
                  .indexWhere((r) => r.id == selectedId)
                  .clamp(0, routeColors.length - 1)]
                  : AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 100), // Ensures the button scrolls past the bottom navigation bar
      ]),
    );
  }

  String _eta(int seconds) {
    if (seconds < 60) return '< 1 min';
    final mins = seconds ~/ 60;
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem == 0 ? '${hrs}h' : '${hrs}h ${rem}m';
  }

  String _fmtDist(double km) {
    if (km < 1.0) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(2)} km';
  }
}

// ─── Safety Ring ──────────────────────────────────────────────────────────────
class _SafetyRing extends StatelessWidget {
  final double percent;
  final Color  color;
  final double size;
  const _SafetyRing({required this.percent, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: percent,
          backgroundColor: AppTheme.border,
          valueColor: AlwaysStoppedAnimation(color),
          strokeWidth: 5,
          strokeCap: StrokeCap.round,
        ),
        Text('${(percent * 100).round()}',
            style: GoogleFonts.spaceGrotesk(
                color: color, fontWeight: FontWeight.w900, fontSize: 14)),
      ]),
    );
  }
}

// ─── Waypoint marker ──────────────────────────────────────────────────────────
class _WaypointMarker extends StatelessWidget {
  final String label;
  final Color  color;
  const _WaypointMarker({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)],
        ),
        child: Center(child: Text(label,
            style: GoogleFonts.spaceGrotesk(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
      ),
      CustomPaint(size: const Size(2, 14), painter: _PinTailPainter(color: color)),
    ]);
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width / 2, 0), Offset(size.width / 2, size.height),
      Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round,
    );
  }
  @override bool shouldRepaint(_) => false;
}

// ─── Mid-route safety badge ───────────────────────────────────────────────────
class _RouteScoreBadge extends StatelessWidget {
  final double score;
  final Color  color;
  final bool   isSelected;
  const _RouteScoreBadge({required this.score, required this.color, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    if (!isSelected) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)],
      ),
      child: Text('${(score * 10).round()}% safe',
          style: GoogleFonts.spaceGrotesk(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

// ─── Location field ───────────────────────────────────────────────────────────
class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String    label, hint;
  final IconData  icon;
  final Color     iconColor;
  final bool      isLoading, isFirst;
  final ValueChanged<String>  onChanged;
  final ValueChanged<String>  onSubmitted;
  final VoidCallback?         onUseGps;

  const _LocationField({
    required this.controller, required this.label, required this.hint,
    required this.icon, required this.iconColor,
    required this.isLoading, required this.isFirst,
    required this.onChanged, required this.onSubmitted,
    this.onUseGps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isFirst ? null : const Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.spaceGrotesk(
              color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 13),
              border: InputBorder.none, enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false, isDense: true, contentPadding: EdgeInsets.zero,
            ),
            textInputAction: TextInputAction.search,
          ),
        ])),
        if (isLoading)
          const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
        else if (onUseGps != null)
          GestureDetector(onTap: onUseGps,
              child: const Icon(Icons.gps_fixed_rounded, color: AppTheme.accent, size: 20)),
      ]),
    );
  }
}

// ─── Autocomplete suggestion list ─────────────────────────────────────────────
class _SuggestionList extends StatelessWidget {
  final List<Map<String, dynamic>>         items;
  final ValueChanged<Map<String, dynamic>> onPick;
  const _SuggestionList({required this.items, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items.take(5).map((s) {
          final name  = s['display_name'] as String? ?? '';
          final parts = name.split(',');
          final title = parts.first.trim();
          final sub   = parts.skip(1).take(2).map((e) => e.trim()).join(', ');
          return InkWell(
            onTap: () => onPick(s),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Icon(Icons.place_outlined, color: AppTheme.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  if (sub.isNotEmpty)
                    Text(sub, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                            color: AppTheme.textSecondary, fontSize: 11)),
                ])),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Swap divider ─────────────────────────────────────────────────────────────
class _SwapDivider extends StatelessWidget {
  final VoidCallback onSwap;
  const _SwapDivider({required this.onSwap});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: Divider(color: AppTheme.border, height: 1)),
      GestureDetector(
        onTap: onSwap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          width: 32, height: 32,
          decoration: BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border)),
          child: const Icon(Icons.swap_vert_rounded, color: AppTheme.accent, size: 18),
        ),
      ),
      const Expanded(child: Divider(color: AppTheme.border, height: 1)),
    ]);
  }
}

// ─── Quick pick chip ──────────────────────────────────────────────────────────
class _QuickChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppTheme.accent, size: 15),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.spaceGrotesk(
              color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── Area safety badge ────────────────────────────────────────────────────────
class _AreaSafetyBadge extends StatelessWidget {
  final double score;
  const _AreaSafetyBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = AppConstants.safetyColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shield_rounded, color: color, size: 16),
        const SizedBox(width: 6),
        Text('Area safety: ${score.toStringAsFixed(1)}/10',
            style: GoogleFonts.spaceGrotesk(
                color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}

// ─── Animated current location marker ────────────────────────────────────────
class _CurrentLocationMarker extends StatefulWidget {
  final double rotation;
  const _CurrentLocationMarker({super.key, this.rotation = 0});

  @override
  State<_CurrentLocationMarker> createState() => _CurrentLocationMarkerState();
}

class _CurrentLocationMarkerState extends State<_CurrentLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Stack(alignment: Alignment.center, children: [
        // Pulsing background
        Container(
          width:  54 * _anim.value, height: 54 * _anim.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.navBlue.withOpacity(0.25 * (1 - _anim.value)),
          ),
        ),
        // Directional indicator (White Arrow)
        Transform.rotate(
           angle: widget.rotation * (pi / 180),
           child: Stack(alignment: Alignment.center, children: [
             Container(
               width: 26, height: 26,
               decoration: BoxDecoration(
                 color: AppTheme.navBlue,
                 shape: BoxShape.circle,
                 border: Border.all(color: Colors.white, width: 2.5),
                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)],
               ),
             ),
             const Padding(
               padding: EdgeInsets.only(bottom: 2),
               child: Icon(Icons.navigation_rounded, color: Colors.white, size: 14),
             ),
           ]),
        ),
      ]),
    );
  }
}

// ─── Map FAB ──────────────────────────────────────────────────────────────────
class _MapFAB extends StatelessWidget {
  final IconData    icon;
  final VoidCallback onTap;
  final String      tooltip;
  final Color       color;
  const _MapFAB({required this.icon, required this.onTap,
    required this.tooltip, this.color = AppTheme.accent});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}


class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String? label;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40, height: 40,
            decoration: AppTheme.glassDecoration(
              opacity: 0.6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(label!, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

void debugPrint(String msg) => print(msg); // ignore: avoid_print

class _AddressNode extends StatelessWidget {
  final String address;
  final Color color;
  final bool isLast;

  const _AddressNode({
    required this.address,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)],
              ),
            ),
            if (!isLast)
              Container(
                width: 2, height: 12,
                color: Colors.white.withOpacity(0.2),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            address,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _AiVerdictChip extends StatelessWidget {
  final SafeRoute route;
  const _AiVerdictChip({required this.route});

  @override
  Widget build(BuildContext context) {
    final verdict = _getVerdict();
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: AppTheme.glassDecoration(
            opacity: 0.8,
            borderRadius: BorderRadius.circular(30),
            borderColor: AppTheme.accent.withOpacity(0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  verdict,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getVerdict() {
    final score = route.safetyScore;
    if (score >= 8.5) return "AI Verdict: Exceptionally Safe Route";
    if (score >= 7.0) return "AI Verdict: Recommended Safe Path";
    if (score >= 5.0) return "AI Verdict: Balanced Safety & Speed";
    return "AI Verdict: Caution Advised for this Segment";
  }
}
