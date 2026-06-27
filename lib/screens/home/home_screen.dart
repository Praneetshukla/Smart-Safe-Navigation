// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../utils/app_theme.dart';
import '../map/map_screen.dart';
import '../reports/reports_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../sos/sos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MapScreen(),
    ReportsScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primary,
      child: Stack(
        children: [
          // Main Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            child: Container(
              key: ValueKey(_currentIndex),
              child: _screens[_currentIndex],
            ),
          ),

          // Static SOS Button (top-right) - hidden on map screen
          if (_currentIndex != 0)
            Positioned(
              top: 180,
              right: 20,
              child: _SOSButton(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SosScreen()),
                ),
              ),
            ),

          // Bottom Nav Bar — pinned to very bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomGlassBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomGlassBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomGlassBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.5), width: 1.5)),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.only(bottom: bottomPadding),
          color: AppTheme.cardBg.withValues(alpha: 0.75),
          child: SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map_rounded, label: 'Map', index: 0, current: currentIndex, onTap: () => onTap(0)),
                _NavItem(icon: Icons.warning_amber_outlined, activeIcon: Icons.warning_amber_rounded, label: 'Reports', index: 1, current: currentIndex, onTap: () => onTap(1)),
                _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history_rounded, label: 'History', index: 2, current: currentIndex, onTap: () => onTap(2)),
                _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', index: 3, current: currentIndex, onTap: () => onTap(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isActive ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppTheme.accent : AppTheme.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: isActive ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SOSButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SOSButton({required this.onTap});

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
            child: const Icon(Icons.sos_rounded, color: AppTheme.danger, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text('SOS', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
