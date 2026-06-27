// lib/screens/sos/sos_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../services/location_service.dart';
// import '../../services/tts_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  final _locationSvc = LocationService();
  // final _ttsSvc = TtsService();
  LatLng? _location;
  bool _sosActivated = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _emergencyContacts = [
    ('Police', '100', Icons.local_police_outlined),
    ('Ambulance', '108', Icons.emergency_outlined),
    ('Women Helpline', '1091', Icons.woman_outlined),
    ('Child Helpline', '1098', Icons.child_care_outlined),
    ('Fire', '101', Icons.local_fire_department_outlined),
    ('Disaster', '1077', Icons.warning_outlined),
  ];

  final _authSvc = AuthService();
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1));
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadData();
  }

  Future<void> _loadData() async {
    final loc = await _locationSvc.getCurrentLocation();
    final u = await _authSvc.getCurrentAppUser();
    if (mounted) {
      setState(() {
        _location = loc;
        _user = u;
      });
    }
  }

  Future<void> _activateSos() async {
    setState(() => _sosActivated = true);
    _pulseCtrl.repeat(reverse: true);
    // await _ttsSvc.speak(
    //     'SOS activated! Sending alert. You are safe. Help is on the way.');
    // await Future.delayed(const Duration(seconds: 30));
    if (mounted) {
      setState(() => _sosActivated = false);
      _pulseCtrl.stop();
    }
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendMessage(String number) async {
    final locationStr = _location != null 
        ? 'My location: https://www.google.com/maps/search/?api=1&query=${_location!.latitude},${_location!.longitude}' 
        : 'Location unavailable';
    
    final message = 'EMERGENCY! I need help. $locationStr';
    
    // Cross-platform compatible SMS URI
    final Uri uri = Uri(
      scheme: 'sms',
      path: number,
      queryParameters: <String, String>{
        'body': message,
      },
    );
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback for some systems that don't like the structured Uri
      final fallbackUri = Uri.parse('sms:$number?body=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri);
      }
    }
  }

  String get _locationText {
    if (_location == null) return 'Location unavailable';
    return '${_location!.latitude.toStringAsFixed(5)}, '
        '${_location!.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // SOS button
              const SizedBox(height: 16),
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Transform.scale(
                    scale: _sosActivated ? _pulseAnim.value : 1.0,
                    child: child,
                  ),
                  child: GestureDetector(
                    onTap: _sosActivated ? null : _activateSos,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _sosActivated
                            ? AppTheme.danger
                            : AppTheme.danger.withOpacity(0.85),
                        border: Border.all(
                          color: AppTheme.danger.withOpacity(0.4),
                          width: 8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.danger
                                .withOpacity(_sosActivated ? 0.6 : 0.3),
                            blurRadius: _sosActivated ? 40 : 20,
                            spreadRadius: _sosActivated ? 10 : 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sos_rounded,
                              color: Colors.white, size: 52),
                          const SizedBox(height: 4),
                          Text(
                            _sosActivated ? 'ACTIVE' : 'HOLD FOR SOS',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_sosActivated)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                    Border.all(color: AppTheme.danger.withOpacity(0.4)),
                  ),
                  child: Text(
                    _sosActivated 
                        ? '🚨 SOS Alert Activated — Notifying ${_user?.trustedContacts.length ?? 0} Contacts' 
                        : '🚨 SOS Alert Activated — Stay Calm',
                    style: GoogleFonts.spaceGrotesk(
                        color: AppTheme.danger, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 24),
              // Location display
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        color: AppTheme.accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Location',
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppTheme.textSecondary, fontSize: 11)),
                          Text(_locationText,
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppTheme.accent, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Trusted Contacts Section
              if (_user != null && _user!.trustedContacts.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Trusted Contacts Notified',
                      style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: _user!.trustedContacts.map((contact) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin_circle_rounded, color: AppTheme.accent, size: 18),
                          const SizedBox(width: 10),
                          Text(contact, style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.phone_rounded, color: AppTheme.accent, size: 18),
                            onPressed: () => _callNumber(contact),
                          ),
                          IconButton(
                            icon: const Icon(Icons.message_rounded, color: AppTheme.accent, size: 18),
                            onPressed: () => _sendMessage(contact),
                          ),
                          if (_sosActivated)
                            const Icon(Icons.check_circle_rounded, color: AppTheme.safe, size: 16),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Emergency Numbers',
                    style: GoogleFonts.spaceGrotesk(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _emergencyContacts.length,
                itemBuilder: (_, i) {
                  final (name, number, icon) = _emergencyContacts[i];
                  return GestureDetector(
                    onTap: () => _callNumber(number),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Icon(icon,
                              color: AppTheme.accentOrange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: GoogleFonts.spaceGrotesk(
                                        color: AppTheme.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                                Text(number,
                                    style: GoogleFonts.spaceGrotesk(
                                        color: AppTheme.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          const Icon(Icons.phone_rounded,
                              color: AppTheme.textSecondary, size: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Safe places nearby button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _openNearbyHelp(),
                  icon: const Icon(Icons.local_hospital_outlined,
                      color: AppTheme.accent),
                  label: Text('Find Nearby Safe Places',
                      style: GoogleFonts.spaceGrotesk(color: AppTheme.accent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNearbyHelp() async {
    if (_location == null) return;
    // Expanded search to include Police and Hospitals
    final query = 'police+station+OR+hospital+OR+pharmacy';
    final uri = Uri.parse(
        'https://www.google.com/maps/search/$query/'
            '@${_location!.latitude},${_location!.longitude},15z');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
