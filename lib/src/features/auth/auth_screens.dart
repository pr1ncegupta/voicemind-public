import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =====================================================================
//  ONBOARDING  (4 pages)
// =====================================================================
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static final _pages = [
    {"icon": Icons.mic_rounded, "title": "Voice-First Support", "desc": "Tap the mic or type — share how you feel and get instant, evidence-based coping strategies.", "color": const Color(0xFFD97757)},
    {"icon": Icons.wifi_off_rounded, "title": "Works Offline Too", "desc": "No internet? No problem. 20+ coping tools and wellness activities are built-in and always available.", "color": const Color(0xFFA8B5A0)},
    {"icon": Icons.spa_rounded, "title": "Wellness Activities", "desc": "Guided breathing, body scans, journaling prompts, movement exercises — all in your pocket.", "color": const Color(0xFFC9A88B)},
    {"icon": Icons.person_outline_rounded, "title": "Personalized Care", "desc": "Set up your profile so AI learns what works for you and avoids what doesn't.", "color": const Color(0xFFE8A87C)},
  ];

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Column(
          children: [
            Align(alignment: Alignment.topRight, child: Padding(padding: const EdgeInsets.all(16), child: TextButton(
              onPressed: widget.onComplete,
              child: Text("Skip", style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w500))))),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 120, height: 120, decoration: BoxDecoration(color: (p['color'] as Color).withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(p['icon'] as IconData, size: 56, color: p['color'] as Color)),
                      const SizedBox(height: 48),
                      Text(p['title'] as String, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: const Color(0xFF191918))),
                      const SizedBox(height: 16),
                      Text(p['desc'] as String, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF6B6B66), height: 1.5)),
                    ]),
                  );
                },
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pages.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 4), width: _page == i ? 24 : 8, height: 8, decoration: BoxDecoration(color: _page == i ? const Color(0xFFD97757) : const Color(0xFFE5E5E0), borderRadius: BorderRadius.circular(4))))),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_page < _pages.length - 1) {
                      _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    } else {
                      widget.onComplete();
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97757), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: Text(_page < _pages.length - 1 ? "Next" : "Get Started", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
//  MAIN DASHBOARD  (3 Tabs)
// =====================================================================
