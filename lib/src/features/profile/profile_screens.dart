import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth_service.dart';

import '../../data/models/user_profile.dart';
import '../../common/constants.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _p = UserProfile();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _auth = AuthService();
  bool _authLoading = false;

  static const _ageOptions = ['18-24', '25-34', '35-44', '45-54', '55+'];
  static const _concernOptions = ['Anxiety', 'Depression', 'Stress', 'Sleep Issues', 'Loneliness', 'Relationships', 'Self-esteem', 'Work/School Pressure', 'Grief', 'Anger', 'ADHD', 'PTSD'];

  static const _workedOptions = ['Deep Breathing', 'Exercise', 'Meditation', 'Journaling', 'Talking to Friends', 'Music', 'Nature Walks', 'Creative Activities', 'Cold Showers', 'Yoga'];
  static const _failedOptions = ['Ignoring Feelings', 'Social Media Scrolling', 'Overthinking', 'Isolation', 'Alcohol/Substances', 'Suppressing Emotions', 'Comparing to Others', 'Overworking'];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _p.name;
    _notesCtrl.text = _p.additionalNotes;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  void _save() async {
    _p.name = _nameCtrl.text;
    _p.additionalNotes = _notesCtrl.text;
    await _p.saveAndSync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✓ Profile saved & synced!"), backgroundColor: Color(0xFF3D8C40)));
      Navigator.pop(context);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _authLoading = true);
    final user = await _auth.signInWithGoogle();
    if (user != null) {
      // Pull saved preferences from the cloud
      await _p.loadFromCloudAndMerge();
      _nameCtrl.text = _p.name;
      _notesCtrl.text = _p.additionalNotes;
    }
    if (mounted) setState(() => _authLoading = false);
  }

  Future<void> _handleSignOut() async {
    setState(() => _authLoading = true);
    await _auth.signOut();
    if (mounted) setState(() => _authLoading = false);
  }

  Widget _accountSection() {
    final user = _auth.currentUser;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withValues(alpha: 0.06)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Account", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF191918))),
        const SizedBox(height: 4),
        Text("Sign in to save your preferences & sync across devices", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF))),
        const SizedBox(height: 16),
        if (user != null) ...[
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              backgroundColor: const Color(0xFFD97757),
              child: user.photoURL == null ? Text(user.displayName?.substring(0, 1).toUpperCase() ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.displayName ?? 'Signed in', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF191918))),
              Text(user.email ?? '', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B6B66))),
            ])),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: _authLoading ? null : _handleSignOut,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE5E5E0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
            child: _authLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97757)))
                : Text("Sign Out", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B6B66), fontWeight: FontWeight.w500)),
          )),
        ] else ...[
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _authLoading ? null : _handleGoogleSignIn,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF191918), elevation: 0, side: const BorderSide(color: Color(0xFFE5E5E0), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _authLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97757)))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.network('https://www.google.com/favicon.ico', width: 18, height: 18, errorBuilder: (_, e, s) => const Icon(Icons.login, size: 18)),
                    const SizedBox(width: 10),
                    Text("Sign in with Google", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                  ]),
          )),
        ],
      ]),
    );
  }

  Widget _section(String title, String sub, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withValues(alpha: 0.06)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF191918))),
        const SizedBox(height: 4),
        Text(sub, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF))),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Widget _chips({required List<String> options, required List<String> selected, required ValueChanged<List<String>> onChanged, Color? color}) {
    return Wrap(spacing: 8, runSpacing: 8, children: options.map((o) {
      final sel = selected.contains(o);
      return GestureDetector(
        onTap: () { setState(() { sel ? selected.remove(o) : selected.add(o); onChanged(selected); }); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: sel ? (color ?? const Color(0xFFD97757)) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? (color ?? const Color(0xFFD97757)) : Colors.black.withValues(alpha: 0.08))),
          child: Text(o, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: sel ? Colors.white : const Color(0xFF525252))),
        ),
      );
    }).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text("My Profile", style: GoogleFonts.inter(color: const Color(0xFF191918), fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [Padding(padding: const EdgeInsets.only(right: 8), child: TextButton(onPressed: _save, child: Text("Save", style: GoogleFonts.inter(color: const Color(0xFFD97757), fontWeight: FontWeight.w600))))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _accountSection(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFEF3EF), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFD97757), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text("This helps the AI personalize coping strategies. Everything stays on your device.", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFB85C3D)))),
            ]),
          ),
          const SizedBox(height: 20),
          _section("Your Name", "How should we address you?", TextField(controller: _nameCtrl, style: GoogleFonts.inter(fontSize: 15), decoration: InputDecoration(hintText: "e.g., Alex", hintStyle: GoogleFonts.inter(color: const Color(0xFFB0B0B0)), filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD97757))), prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF9CA3AF), size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
          _section("Age Group", "Helps tailor age-appropriate advice", _chips(options: _ageOptions, selected: _p.ageGroup.isEmpty ? [] : [_p.ageGroup], onChanged: (v) => _p.ageGroup = v.isNotEmpty ? v.last : "", color: const Color(0xFFC9A88B))),
          _section(
            "Voice Companion",
            "Voice is fixed for consistency and empathy",
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3EF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFFD97757), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Using Sulafat (empathetic default) at a natural speaking pace.",
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B6B66), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          _section("Main Concerns", "Select all that apply", _chips(options: _concernOptions, selected: _p.concerns, onChanged: (v) => _p.concerns = v, color: const Color(0xFFD97757))),
          _section("What Helps You? ✓", "Strategies that work for you", _chips(options: _workedOptions, selected: _p.copingStrategiesWorked, onChanged: (v) => _p.copingStrategiesWorked = v, color: const Color(0xFF3D8C40))),
          _section("What Doesn't Help? ✗", "We'll avoid suggesting these", _chips(options: _failedOptions, selected: _p.copingStrategiesFailed, onChanged: (v) => _p.copingStrategiesFailed = v, color: const Color(0xFFC94A4A))),
          _section("Additional Notes", "Anything else the AI should know?", TextField(controller: _notesCtrl, maxLines: 4, decoration: InputDecoration(hintText: "e.g., 'I respond well to nature exercises' or 'I have ADHD'", hintStyle: GoogleFonts.inter(color: const Color(0xFFB0B0B0), fontSize: 13), filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97757), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text("Save My Profile", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}

// =====================================================================
//  HELPLINES PAGE
// =====================================================================
class HelplinesPage extends StatelessWidget {
  const HelplinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text("Crisis Helplines", style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFF191918))),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: const Color(0xFFFEF3EF), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [const Icon(Icons.favorite_rounded, color: Color(0xFFD97757), size: 20), const SizedBox(width: 12), Expanded(child: Text("These helplines are free, confidential, and available 24/7. You are not alone.", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFB85C3D), height: 1.4)))]),
        ),
        Text("India", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF))),
        const SizedBox(height: 12),
        ...kIndiaHelplines.map((entry) => _hl(entry.name, entry.number, entry.telUri)),
        const SizedBox(height: 20),
        Text("International", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF))),
        const SizedBox(height: 12),
        ...kInternationalHelplines.map((entry) => _hl(entry.name, entry.number, entry.telUri)),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _hl(String name, String number, String uri) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF3D8C40).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.phone_rounded, color: Color(0xFF3D8C40), size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF191918))),
          const SizedBox(height: 2),
          Text(number, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B6B66))),
        ])),
        GestureDetector(
          onTap: () async { final u = Uri.parse(uri); if (await canLaunchUrl(u)) await launchUrl(u); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF3D8C40), borderRadius: BorderRadius.circular(8)), child: Text("Call", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
        ),
      ]),
    );
  }
}
