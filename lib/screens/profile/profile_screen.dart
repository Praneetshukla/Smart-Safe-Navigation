// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authSvc = AuthService();
  AppUser? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await _authSvc.getCurrentAppUser();
    if (mounted) setState(() { _user = u; _loading = false; });
  }

  Future<void> _updatePreferences(UserPreferences prefs) async {
    if (_user == null) return;
    await _authSvc.updatePreferences(_user!.uid, prefs);
    setState(() => _user = AppUser(
      uid: _user!.uid,
      name: _user!.name,
      email: _user!.email,
      photoUrl: _user!.photoUrl,
      trustedContacts: _user!.trustedContacts,
      preferences: prefs,
    ));
  }

  void _showEditNameDialog() {
    final ctrl = TextEditingController(text: _user!.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Edit Name', style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await _authSvc.updateProfile(_user!.uid, name: ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                _loadUser();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeContact(String contact) async {
    final newContacts = List<String>.from(_user!.trustedContacts)..remove(contact);
    await _authSvc.updateContacts(_user!.uid, newContacts);
    _loadUser();
  }

  void _showAddContactDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Add Trusted Contact', style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: 'Enter 10-digit number',
            prefixText: '+91 ',
            prefixStyle: TextStyle(color: AppTheme.accent),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final input = ctrl.text.trim();
              if (input.isEmpty) return;

              // Validation: Must be exactly 10 digits
              final isDigitsOnly = RegExp(r'^[0-9]+$').hasMatch(input);
              if (!isDigitsOnly || input.length != 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
                );
                return;
              }

              final formattedNumber = '+91 $input';
              final newContacts = List<String>.from(_user!.trustedContacts)..add(formattedNumber);
              await _authSvc.updateContacts(_user!.uid, newContacts);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadUser();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: AppTheme.primary,
        child: const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (_user == null) {
      return Container(
        color: AppTheme.primary,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline,
                  color: AppTheme.textSecondary, size: 64),
              const SizedBox(height: 16),
              Text('Not signed in',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textSecondary, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppTheme.primary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 100),
          children: [
            Row(
              children: [
                Text('Profile', style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
                  onPressed: () async {
                    await _authSvc.signOut();
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen()));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Profile header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.accent, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            _user!.name.isNotEmpty
                                ? _user!.name[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.spaceGrotesk(
                                color: AppTheme.accent,
                                fontSize: 28,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_user!.name,
                          style: GoogleFonts.spaceGrotesk(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppTheme.textSecondary, size: 16),
                        onPressed: () => _showEditNameDialog(),
                      ),
                    ],
                  ),
                  Text(_user!.email,
                      style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Saved Locations'),
            const SizedBox(height: 12),
            _AddressField(
              label: 'Home Address',
              hint: 'Enter home location',
              icon: Icons.home_rounded,
              initialValue: _user!.preferences.homeAddress,
              onSaved: (v) => _updatePreferences(
                  _user!.preferences.copyWith(homeAddress: v)),
            ),
            const SizedBox(height: 10),
            _AddressField(
              label: 'Work Address',
              hint: 'Enter work location',
              icon: Icons.work_rounded,
              initialValue: _user!.preferences.workAddress,
              onSaved: (v) => _updatePreferences(
                  _user!.preferences.copyWith(workAddress: v)),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Navigation Preferences'),
            const SizedBox(height: 12),
            _PreferenceToggle(
              title: 'Avoid Dark Alleys',
              subtitle: 'Route around poorly lit areas',
              icon: Icons.nightlight_outlined,
              value: _user!.preferences.avoidDarkAlleys,
              onChanged: (v) => _updatePreferences(
                  _user!.preferences.copyWith(avoidDarkAlleys: v)),
            ),
            const SizedBox(height: 10),
            _PreferenceToggle(
              title: 'Prefer Well-Lit Routes',
              subtitle: 'Prioritize streets with good lighting',
              icon: Icons.wb_sunny_outlined,
              value: _user!.preferences.preferLitRoutes,
              onChanged: (v) => _updatePreferences(
                  _user!.preferences.copyWith(preferLitRoutes: v)),
            ),
            const SizedBox(height: 10),
            _PreferenceToggle(
              title: 'Share Location',
              subtitle: 'Share journey with trusted contacts',
              icon: Icons.share_location_outlined,
              value: _user!.preferences.shareLocationWithContacts,
              onChanged: (v) => _updatePreferences(
                  _user!.preferences.copyWith(shareLocationWithContacts: v)),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Default Route Type'),
            const SizedBox(height: 12),
            Row(
              children: ['safest', 'fastest'].map((type) {
                final isSelected =
                    _user!.preferences.defaultRouteType == type;
                final colors = {
                  'safest': AppTheme.safe,
                  'fastest': AppTheme.accentOrange,
                };
                final color = colors[type]!;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _updatePreferences(
                          _user!.preferences.copyWith(defaultRouteType: type)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.15)
                              : AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isSelected ? color : AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              type == 'safest'
                                  ? Icons.shield_outlined
                                  : Icons.flash_on_outlined,
                              color: isSelected ? color : AppTheme.textSecondary,
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              type[0].toUpperCase() + type.substring(1),
                              style: GoogleFonts.spaceGrotesk(
                                color: isSelected
                                    ? color
                                    : AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Trusted Contacts'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  ...(_user!.trustedContacts.map((contact) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.person_pin_circle_outlined, color: AppTheme.accent, size: 20),
                        const SizedBox(width: 12),
                        Text(contact, style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontSize: 13)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.danger, size: 18),
                          onPressed: () => _removeContact(contact),
                        ),
                      ],
                    ),
                  ))),
                  TextButton.icon(
                    onPressed: _showAddContactDialog,
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.accent, size: 20),
                    label: Text('Add Contact', style: GoogleFonts.spaceGrotesk(color: AppTheme.accent)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16),
      );
}

class _PreferenceToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceToggle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.spaceGrotesk(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(subtitle,
                    style: GoogleFonts.spaceGrotesk(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }
}

class _AddressField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String? initialValue;
  final ValueChanged<String> onSaved;

  const _AddressField({required this.label, required this.hint, required this.icon, this.initialValue, required this.onSaved});

  @override
  State<_AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<_AddressField> {
  late TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue ?? '');
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        if (_ctrl.text != (widget.initialValue ?? '')) {
          widget.onSaved(_ctrl.text);
        }
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary, fontSize: 13),
          hintText: widget.hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 13),
          prefixIcon: Icon(widget.icon, color: AppTheme.accent, size: 20),
          border: InputBorder.none,
        ),
        onSubmitted: (v) {
          if (v != (widget.initialValue ?? '')) {
            widget.onSaved(v);
          }
        },
      ),
    );
  }
}
