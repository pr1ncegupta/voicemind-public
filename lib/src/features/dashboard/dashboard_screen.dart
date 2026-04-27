import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth_service.dart';

import '../../features/talk/talk_page.dart';
import '../tools/tools_screens.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override
  State<MainDashboard> createState() => _MainDashboardState();

  static void switchToTab(int index) {
    _MainDashboardState.globalKey.currentState?.switchToTab(index);
  }
}

class _MainDashboardState extends State<MainDashboard> {
  static final GlobalKey<_MainDashboardState> globalKey = GlobalKey<_MainDashboardState>();
  int _idx = 1;
  final _pages = const [CopingToolsPage(), TalkPage(), WellnessActivitiesPage()];

  void switchToTab(int index) {
    setState(() => _idx = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _MainDashboardState.globalKey,
      body: _pages[_idx],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06)))),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _nav(0, Icons.self_improvement_rounded, "Coping"),
              _nav(1, Icons.mic_rounded, "Talk"),
              _nav(2, Icons.spa_rounded, "Wellness"),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _nav(int i, IconData icon, String label) {
    final sel = _idx == i;
    return GestureDetector(
      onTap: () {
        setState(() => _idx = i);
        AuthService().logAnalyticsEvent('tab_switch', {'tab': ['coping', 'talk', 'wellness'][i]});
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: sel ? const Color(0xFFD97757).withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24, color: sel ? const Color(0xFFD97757) : const Color(0xFF9CA3AF)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: sel ? const Color(0xFFD97757) : const Color(0xFF9CA3AF))),
        ]),
      ),
    );
  }
}

// =====================================================================
//  TALK PAGE  (Voice + Text + History + Offline AI + Emotion Indicator)
// =====================================================================
