import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../services/safety_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_theme.dart';

class AddReportScreen extends StatefulWidget {
  final LatLng? location;
  const AddReportScreen({super.key, this.location});
  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _descCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _safetySvc = SafetyService();
  final _authSvc = AuthService();
  final _locationSvc = LocationService();
  String _type = 'harassment';
  double _severity = 3;
  bool _submitting = false;
  bool _locLoading = false;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _selectedLocation = widget.location;
      _initLocationString();
    }
  }

  Future<void> _initLocationString() async {
     final addr = await _locationSvc.getAddressFromLatLng(widget.location!);
     if (mounted) _locCtrl.text = addr;
  }

  static const _types = [
    ('harassment', Icons.person_off_rounded, 'Harassment', Color(0xFFFF3B3B)),
    ('theft', Icons.money_off_rounded, 'Theft', Color(0xFFFF6B35)),
    ('accident', Icons.car_crash_rounded, 'Accident', Color(0xFFFFD700)),
    ('lighting', Icons.lightbulb_outlined, 'Poor Lighting', Color(0xFF8B5CF6)),
    ('other', Icons.warning_amber_rounded, 'Other', Color(0xFF64748B)),
  ];

  Future<void> _submit() async {
    setState(() => _submitting = true);
    LatLng? finalLoc = _selectedLocation;

    try {
      if (finalLoc == null && _locCtrl.text.trim().isNotEmpty) {
        // More robust geocoding using Nominatim search suggestions
        final suggestions = await _locationSvc.searchSuggestions(_locCtrl.text.trim());
        if (suggestions.isNotEmpty) {
          final lat = double.tryParse(suggestions.first['lat'] ?? '0') ?? 0;
          final lon = double.tryParse(suggestions.first['lon'] ?? '0') ?? 0;
          if (lat != 0 && lon != 0) {
            finalLoc = LatLng(lat, lon);
          }
        }
        // Fallback to basic geocoding if needed
        if (finalLoc == null) {
          finalLoc = await _locationSvc.getLatLngFromAddress(_locCtrl.text.trim());
        }
      }
      
      // Auto-fetch current location if no explicit location given or geocoding failed
      if (finalLoc == null) {
        finalLoc = await _locationSvc.getCurrentLocation();
      }

      if (finalLoc == null) {
        _snack('Could not determine location. Please ensure GPS is enabled or enter a valid address.', isError: true);
        setState(() => _submitting = false);
        return;
      }

      final user = await _authSvc.getCurrentAppUser().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      final report = SafetyReport(
        id: '',
        userId: user?.uid ?? 'anonymous',
        userName: user?.name ?? 'Anonymous',
        location: finalLoc,
        type: _type,
        description: _descCtrl.text.trim(),
        severity: _severity,
        timestamp: DateTime.now(),
      );
      
      // Submit with a timeout so it doesn't hang if Firestore is unreachable
      await _safetySvc.submitReport(report).timeout(const Duration(seconds: 5));

      if (mounted) {
        Navigator.pop(context);
        _snack('Report submitted. Thank you for keeping the community safe!');
      }
    } catch (e) {
      if (mounted) {
        if (e is TimeoutException || e.toString().contains('Timeout')) {
           _snack('Network timeout. Your report was saved offline and will sync later.');
           Navigator.pop(context);
        } else {
           _snack('Error: $e', isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.danger : AppTheme.safe,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF112240)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50, right: -50,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentOrange.withOpacity(0.05),
                ),
              ),
            ),
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _sectionTitle('What happened?'),
                        const SizedBox(height: 16),
                        _buildTypeGrid(),
                        const SizedBox(height: 32),
                        _sectionTitle('Severity Level'),
                        const SizedBox(height: 12),
                        _buildSeverityPicker(),
                        const SizedBox(height: 32),
                        _sectionTitle('Details (optional)'),
                        const SizedBox(height: 12),
                        _buildDescriptionField(),
                        const SizedBox(height: 32),
                        _sectionTitle('Location'),
                        const SizedBox(height: 12),
                        _buildLocationInput(),
                        const SizedBox(height: 40),
                        _buildSubmitButton(),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      floating: true,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Report Hazard',
          style: GoogleFonts.spaceGrotesk(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
    );
  }

  Widget _buildTypeGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _types.map((t) {
        final (value, icon, label, color) = t;
        final isSelected = _type == value;
        return GestureDetector(
          onTap: () => setState(() => _type = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: AppTheme.glassDecoration(
              opacity: isSelected ? 0.35 : 0.15,
              borderColor: isSelected ? color : AppTheme.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: isSelected ? color : AppTheme.textSecondary, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: GoogleFonts.spaceGrotesk(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeverityPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppTheme.glassDecoration(opacity: 0.15),
      child: Row(
        children: [
          const Icon(Icons.sentiment_very_satisfied_rounded, color: AppTheme.safe, size: 20),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.accentOrange,
                inactiveTrackColor: AppTheme.border.withOpacity(0.5),
                thumbColor: Colors.white,
                overlayColor: AppTheme.accentOrange.withOpacity(0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _severity,
                min: 1, max: 5, divisions: 4,
                onChanged: (v) => setState(() => _severity = v),
              ),
            ),
          ),
          const Icon(Icons.sentiment_very_dissatisfied_rounded, color: AppTheme.danger, size: 20),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descCtrl,
      maxLines: 4,
      style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Add context to help other users...',
        hintStyle: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 14),
        filled: true,
        fillColor: AppTheme.cardBg.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.border.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildLocationInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _locCtrl,
            onChanged: (v) => _selectedLocation = null, // Reset if user types manually
            style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter hazard location...',
              hintStyle: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 14),
              filled: true,
              fillColor: AppTheme.cardBg.withOpacity(0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.border.withOpacity(0.3)),
              ),
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () async {
            setState(() => _locLoading = true);
            final loc = await _locationSvc.getCurrentLocation();
            if (loc != null) {
              _selectedLocation = loc;
              final addr = await _locationSvc.getAddressFromLatLng(loc);
              if (mounted) _locCtrl.text = addr;
            } else {
              if (mounted) _snack('Could not get current location', isError: true);
            }
            if (mounted) setState(() => _locLoading = false);
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
            ),
            child: Center(
              child: _locLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                : const Icon(Icons.my_location_rounded, color: AppTheme.accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentOrange,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppTheme.accentOrange.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _submitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text('Submit Report',
                      style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontSize: 11),
      );
}
