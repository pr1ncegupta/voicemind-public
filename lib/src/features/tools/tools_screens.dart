import 'dart:async';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models/tools_data.dart';
import '../../common/constants.dart';

class CopingToolsPage extends StatefulWidget {
  const CopingToolsPage({super.key});
  @override
  State<CopingToolsPage> createState() => _CopingToolsPageState();
}

class _CopingToolsPageState extends State<CopingToolsPage> {
  String _selectedCategory = "All";

  List<String> get _categories {
    final cats = kCopingTools.map((e) => e['category'] as String).toSet().toList();
    return ["All", ...cats];
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == "All") return kCopingTools;
    return kCopingTools.where((e) => e['category'] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(title: Text("Coping Toolbox", style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFF191918)))),
      body: Column(children: [
        // Category filter
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final sel = cat == _selectedCategory;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: sel ? const Color(0xFFD97757) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? const Color(0xFFD97757) : Colors.black.withValues(alpha: 0.08))),
                  child: Center(child: Text(cat, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: sel ? Colors.white : const Color(0xFF6B6B66)))),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 900 ? 4 : width > 600 ? 3 : 2;
              final childAspectRatio = width > 600 ? 1.3 : 1.1;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: childAspectRatio),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final item = _filtered[i];
                  return FadeInUp(
                    delay: Duration(milliseconds: 30 * i),
                    duration: const Duration(milliseconds: 350),
                    child: GestureDetector(
                      onTap: () => _showDetail(item),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withValues(alpha: 0.06)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))]),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 26)),
                          const SizedBox(height: 14),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(item['title'] as String, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF191918), height: 1.2))),
                          const SizedBox(height: 4),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)), child: Text(item['category'] as String, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: item['color'] as Color))),
                        ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    final FlutterTts tts = FlutterTts();
    configureTtsVoice(tts);
    bool isSpeaking = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          tts.setCompletionHandler(() {
            setSheetState(() => isSpeaking = false);
          });

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Drag handle + close button
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const SizedBox(width: 32),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5E0), borderRadius: BorderRadius.circular(2))),
                GestureDetector(
                  onTap: () { tts.stop(); Navigator.of(ctx).pop(); },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B6B66)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['title'] as String, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF191918))),
                  const SizedBox(height: 2),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(item['category'] as String, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: item['color'] as Color))),
                ])),
              ]),
              const SizedBox(height: 12),
              Text(item['desc'] as String, style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF6B6B66), height: 1.5)),
              const SizedBox(height: 20),
              Text("Steps", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF))),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: (item['steps'] as List).length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) => FadeInUp(
                    delay: Duration(milliseconds: 60 * idx),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(margin: const EdgeInsets.only(top: 3), width: 22, height: 22, decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Center(child: Text('${idx + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: item['color'] as Color)))),
                      const SizedBox(width: 12),
                      Expanded(child: Text((item['steps'] as List)[idx] as String, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF404040), height: 1.5))),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if ((item['steps'] as List).isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      tts.stop();
                      Navigator.of(ctx).pop();
                      if (item['category'] == 'Breathing' && item['pattern'] != null) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuidedBreathingSession(breathingData: item)));
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuidedCopingSession(toolData: item)));
                      }
                    },
                    icon: const Icon(Icons.play_circle_rounded, color: Colors.white, size: 20),
                    label: Text("Start Guided Session", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item['color'] as Color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isSpeaking) {
                      tts.stop();
                      setSheetState(() => isSpeaking = false);
                    } else {
                      final steps = (item['steps'] as List).asMap().entries.map((e) => "Step ${e.key + 1}: ${e.value}").join(". ");
                      tts.speak("${item['title']}. ${item['desc']}. $steps");
                      setSheetState(() => isSpeaking = true);
                    }
                  },
                  icon: Icon(isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded, color: Colors.white, size: 18),
                  label: Text(isSpeaking ? "Stop Reading" : "Read Aloud", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSpeaking
                        ? Colors.red.shade400
                        : (item['category'] == 'Breathing' && item['pattern'] != null
                            ? Colors.grey.shade600
                            : item['color'] as Color),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    ).then((_) => tts.stop()); // Stop TTS when sheet dismissed
  }
}

// =====================================================================
//  WELLNESS ACTIVITIES PAGE  (20 activities, categorized, fully offline)
// =====================================================================
class WellnessActivitiesPage extends StatefulWidget {
  const WellnessActivitiesPage({super.key});
  @override
  State<WellnessActivitiesPage> createState() => _WellnessActivitiesPageState();
}

class _WellnessActivitiesPageState extends State<WellnessActivitiesPage> {
  String _selectedCategory = "All";

  List<String> get _categories {
    final cats = kWellnessActivities.map((e) => e['category'] as String).toSet().toList();
    return ["All", ...cats];
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == "All") return kWellnessActivities;
    return kWellnessActivities.where((e) => e['category'] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(title: Text("Wellness", style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFF191918)))),
      body: Column(children: [
        // Category filter
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final sel = cat == _selectedCategory;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: sel ? const Color(0xFFA8B5A0) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? const Color(0xFFA8B5A0) : Colors.black.withValues(alpha: 0.08))),
                  child: Center(child: Text(cat, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: sel ? Colors.white : const Color(0xFF6B6B66)))),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            itemCount: _filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final item = _filtered[i];
              return FadeInUp(
                delay: Duration(milliseconds: 30 * i),
                duration: const Duration(milliseconds: 350),
                child: GestureDetector(
                  onTap: () => _showDetail(item),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withValues(alpha: 0.06)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))]),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF191918))),
                        const SizedBox(height: 2),
                        Text(item['desc'] as String, style: GoogleFonts.inter(color: const Color(0xFF6B6B66), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)), child: Text(item['category'] as String, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: item['color'] as Color))),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 20),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    final FlutterTts tts = FlutterTts();
    configureTtsVoice(tts);
    var isSpeaking = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          tts.setCompletionHandler(() {
            setSheetState(() => isSpeaking = false);
          });
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const SizedBox(width: 32),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5E0), borderRadius: BorderRadius.circular(2))),
                GestureDetector(
                  onTap: () { tts.stop(); Navigator.of(ctx).pop(); },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B6B66)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['title'] as String, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF191918))),
                  const SizedBox(height: 2),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(item['category'] as String, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: item['color'] as Color))),
                ])),
              ]),
              const SizedBox(height: 12),
              Text(item['desc'] as String, style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF6B6B66), height: 1.5)),
              const SizedBox(height: 20),
              Text("How to do it", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF))),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: (item['steps'] as List).length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) => FadeInUp(
                    delay: Duration(milliseconds: 60 * idx),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(margin: const EdgeInsets.only(top: 3), width: 22, height: 22, decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Center(child: Text('${idx + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: item['color'] as Color)))),
                      const SizedBox(width: 12),
                      Expanded(child: Text((item['steps'] as List)[idx] as String, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF404040), height: 1.5))),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isSpeaking) {
                      tts.stop();
                      setSheetState(() => isSpeaking = false);
                    } else {
                      final steps = (item['steps'] as List).asMap().entries.map((e) => "Step ${e.key + 1}: ${e.value}").join(". ");
                      tts.speak("${item['title']}. ${item['desc']}. $steps");
                      setSheetState(() => isSpeaking = true);
                    }
                  },
                  icon: Icon(isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded, color: Colors.white, size: 18),
                  label: Text(isSpeaking ? "Stop Reading" : "Read Aloud", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSpeaking ? Colors.red.shade400 : item['color'] as Color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    ).then((_) => tts.stop());
  }
}

// ---------------------------------------------------------------------
// Guided coping — per-technique pacing, labels, copy, and visuals
// ---------------------------------------------------------------------
enum _GuidedCopingVisualKind { senses, anchor, coldSplash, rooted, somatic, bilateral, cognitive, mindful, compassion, containment }

class _CopingGuidedProfile {
  const _CopingGuidedProfile({
    required this.badge,
    required this.idleHeadline,
    this.idleSubtext,
    required this.stepTags,
    this.stepSeconds,
    this.fallbackSeconds = 35,
    this.defaultRounds = 1,
    this.durationPresets = const [20, 30, 45, 60],
    required this.visualKind,
    required this.centerIcon,
    this.openingVoiceLine,
    this.completionMessage,
    this.completionVoiceLine,
  });

  final String badge;
  final String idleHeadline;
  final String? idleSubtext;
  final List<String> stepTags;
  final List<int>? stepSeconds;
  final int fallbackSeconds;
  final int defaultRounds;
  final List<int> durationPresets;
  final _GuidedCopingVisualKind visualKind;
  final IconData centerIcon;
  final String? openingVoiceLine;
  final String? completionMessage;
  final String? completionVoiceLine;

  static final Map<String, _CopingGuidedProfile> _byTitle = {
    '5-4-3-2-1 Grounding': _CopingGuidedProfile(
      badge: 'Sensory anchoring',
      idleHeadline: 'Map the room with your senses',
      idleSubtext: 'No rush — name what you notice, then move on when you are ready.',
      stepTags: ['Settle', 'See · five', 'Touch · four', 'Hear · three', 'Smell · two', 'Taste · one', 'Land here'],
      stepSeconds: [25, 55, 55, 45, 35, 30, 40],
      fallbackSeconds: 45,
      visualKind: _GuidedCopingVisualKind.senses,
      centerIcon: Icons.visibility_rounded,
      openingVoiceLine: "Let's anchor you in the present, one sense at a time.",
      completionMessage: 'You walked your attention through sight, touch, sound, smell, and taste — that is real grounding.',
      completionVoiceLine: 'Nice work. You are here, in your body, in this moment.',
    ),
    'Grounding Object': _CopingGuidedProfile(
      badge: 'Tactile anchor',
      idleHeadline: 'Let one object hold your attention',
      idleSubtext: 'Treat it like a tiny island of “now.” When thoughts drift, come back to the object.',
      stepTags: ['Choose it', 'Feel the weight', 'Trace texture', 'Warm or cool', 'Details', 'Stay sixty seconds', 'Gentle return'],
      stepSeconds: [25, 30, 35, 25, 35, 65, 35],
      fallbackSeconds: 35,
      visualKind: _GuidedCopingVisualKind.anchor,
      centerIcon: Icons.pan_tool_alt_rounded,
      openingVoiceLine: 'Pick something small and let it anchor your attention.',
      completionMessage: 'You practiced returning attention to something solid. That skill travels with you.',
      completionVoiceLine: 'Well done. You can use this anchor anytime.',
    ),
    'Cold Water Reset': _CopingGuidedProfile(
      badge: 'Dive reflex · reset',
      idleHeadline: 'Use cold to wake the nervous system',
      idleSubtext: 'Short, sharp sensation — then slow breaths as your body settles.',
      stepTags: ['Go to water', 'Run it cold', 'Splash or hold', 'Ice in hand', 'Feel the jolt', 'Slow breaths', 'Notice slowing'],
      stepSeconds: [25, 20, 35, 40, 35, 50, 30],
      fallbackSeconds: 30,
      visualKind: _GuidedCopingVisualKind.coldSplash,
      centerIcon: Icons.water_drop_rounded,
      openingVoiceLine: 'Cold water can snap you back into your body. Move at a pace that feels safe.',
      completionMessage: 'You gave your system a reset cue. Let the calm that follows spread.',
      completionVoiceLine: 'Good. Ride the after-calm with a few slow breaths.',
    ),
    'Feet on the Floor': _CopingGuidedProfile(
      badge: 'Postural grounding',
      idleHeadline: 'Press into support beneath you',
      idleSubtext: 'Pressure and contact remind your brain: you have a floor, you have a now.',
      stepTags: ['Sit with contact', 'Press down', 'Feel the floor', 'Texture', 'Wiggle toes', 'Say the phrase', 'Rest in support'],
      stepSeconds: [25, 30, 35, 30, 30, 35, 40],
      fallbackSeconds: 32,
      visualKind: _GuidedCopingVisualKind.rooted,
      centerIcon: Icons.foundation_rounded,
      openingVoiceLine: 'Feel the ground literally holding you. Nothing fancy — just contact.',
      completionMessage: 'You re-linked attention to support under your feet. Simple, and it works.',
      completionVoiceLine: 'Well done. That downward contact is always available.',
    ),
    'Progressive Muscle Relaxation': _CopingGuidedProfile(
      badge: 'Tense · release · contrast',
      idleHeadline: 'Move tension through the body',
      idleSubtext: 'Tighten on purpose, then melt — the contrast teaches relaxation.',
      stepTags: ['Toes curl', 'Release & notice', 'Calves & thighs', 'Core & arms', 'Face scrunch', 'Whole body', 'Lie still'],
      stepSeconds: [22, 38, 42, 55, 30, 40, 70],
      fallbackSeconds: 40,
      visualKind: _GuidedCopingVisualKind.somatic,
      centerIcon: Icons.fitness_center_rounded,
      openingVoiceLine: 'We will move from toes upward. Tense firmly, then let go completely.',
      completionMessage: 'You cycled tension on purpose and gave your muscles permission to soften.',
      completionVoiceLine: 'Beautiful. Rest in that lighter body for a moment.',
    ),
    'Butterfly Hug': _CopingGuidedProfile(
      badge: 'Bilateral calm',
      idleHeadline: 'Slow taps, steady rhythm',
      idleSubtext: 'Left-right stimulation can soothe a stirred-up nervous system.',
      stepTags: ['Cross arms', 'Hands on shoulders', 'Alternate taps', 'Heartbeat pace', 'Eyes soft', 'Stay with rhythm', 'Let it land'],
      stepSeconds: [25, 25, 40, 45, 30, 75, 35],
      fallbackSeconds: 40,
      visualKind: _GuidedCopingVisualKind.bilateral,
      centerIcon: Icons.back_hand_rounded,
      openingVoiceLine: 'Cross your arms and find a slow, kind tapping rhythm.',
      completionMessage: 'You offered your body bilateral rhythm — a quiet regulation tool.',
      completionVoiceLine: 'Nice work. Stay with the softness for another breath if you like.',
    ),
    'Shoulder Release': _CopingGuidedProfile(
      badge: 'Micro release',
      idleHeadline: 'Unload the shoulders and neck',
      idleSubtext: 'Good for desk tension, stress hunching, or “meeting shoulders.”',
      stepTags: ['Lift high', 'Hold tight', 'Drop', 'Roll back', 'Roll forward', 'Neck sides', 'Breathe it out'],
      stepSeconds: [20, 18, 25, 35, 35, 45, 35],
      fallbackSeconds: 30,
      visualKind: _GuidedCopingVisualKind.somatic,
      centerIcon: Icons.accessibility_new_rounded,
      openingVoiceLine: 'Let your shoulders tell the story of your stress — then let them fall.',
      completionMessage: 'You cleared a pocket of held tension. Small moves, real relief.',
      completionVoiceLine: 'Good. Feel the space you just made.',
    ),
    'Thought Record': _CopingGuidedProfile(
      badge: 'CBT · examine the thought',
      idleHeadline: 'Put the thought on paper, not on repeat',
      idleSubtext: 'Jot in notes if you can; thinking it through counts too.',
      stepTags: ['Write it verbatim', 'Belief percent', 'Emotion percent', 'Evidence for', 'Evidence against', 'Balanced thought', 'Re-rate belief'],
      fallbackSeconds: 55,
      defaultRounds: 1,
      durationPresets: const [45, 60, 75, 90],
      visualKind: _GuidedCopingVisualKind.cognitive,
      centerIcon: Icons.psychology_rounded,
      openingVoiceLine: 'We are not fighting the thought — we are inspecting it like evidence.',
      completionMessage: 'You separated story from facts. That is how belief softens.',
      completionVoiceLine: 'Strong work. Notice if the thought feels a little less absolute.',
    ),
    'Positive Reframe': _CopingGuidedProfile(
      badge: 'Perspective · without toxic positivity',
      idleHeadline: 'Shift toward accuracy, not denial',
      idleSubtext: 'Honor the feeling while widening the lens a little.',
      stepTags: ['Notice the thought', 'Is it one-hundred percent true', 'Friend voice', 'One neutral truth', 'Swap phrase one', 'Swap phrase two', 'Accurate kindness'],
      fallbackSeconds: 50,
      durationPresets: const [40, 50, 60, 75],
      visualKind: _GuidedCopingVisualKind.cognitive,
      centerIcon: Icons.autorenew_rounded,
      openingVoiceLine: 'We are looking for a truer sentence, not a fake happy one.',
      completionMessage: 'You practiced flexible thinking without dismissing what hurts.',
      completionVoiceLine: 'Well done. Carry the kinder, truer line with you.',
    ),
    'Worry Time': _CopingGuidedProfile(
      badge: 'Containment · scheduled',
      idleHeadline: 'Fence worries into a time box',
      idleSubtext: 'Outside the window: defer with kindness. Inside: sort with clarity.',
      stepTags: ['Pick your window', 'Catch intrusions', 'Defer kindly', 'Open the list', 'Control check', 'Solve or release', 'Close the container'],
      fallbackSeconds: 50,
      durationPresets: const [40, 50, 60, 90],
      visualKind: _GuidedCopingVisualKind.cognitive,
      centerIcon: Icons.schedule_rounded,
      openingVoiceLine: 'You are allowed to worry — just not all day. Give it a bounded home.',
      completionMessage: 'You practiced postponing anxiety without shaming yourself for having it.',
      completionVoiceLine: 'Nice. When a worry knocks, you have a door to point it to.',
    ),
    'Body Scan': _CopingGuidedProfile(
      badge: 'Mindful · inward tour',
      idleHeadline: 'Soft attention from head to toe',
      idleSubtext: 'No fixing — noticing. Breathe space into anywhere that grips.',
      stepTags: ['Settle the body', 'Head and face', 'Down through arms', 'Chest and belly', 'Legs and feet', 'Whole body field', 'Rest wide'],
      stepSeconds: [35, 45, 50, 50, 50, 40, 65],
      fallbackSeconds: 45,
      visualKind: _GuidedCopingVisualKind.mindful,
      centerIcon: Icons.self_improvement_rounded,
      openingVoiceLine: 'Glide attention slowly; if you drift, come back without judgment.',
      completionMessage: 'You gave your body a full listen. That alone can loosen grip.',
      completionVoiceLine: 'Beautiful. Linger in stillness for one more breath if you like.',
    ),
    'Safe Place Visualization': _CopingGuidedProfile(
      badge: 'Inner sanctuary',
      idleHeadline: 'Build a place your mind can visit',
      idleSubtext: 'Rich detail makes it feel real — color, air, sound, touch.',
      stepTags: ['Arrive with breath', 'Choose the place', 'Shape the space', 'Sight there', 'Sound and air', 'Smell and touch', 'Stay awhile'],
      stepSeconds: [35, 40, 45, 50, 50, 45, 90],
      fallbackSeconds: 45,
      visualKind: _GuidedCopingVisualKind.mindful,
      centerIcon: Icons.landscape_rounded,
      openingVoiceLine: 'This is your imagination in service of safety. Make it vivid.',
      completionMessage: 'You installed a refuge you can return to with one intentional breath.',
      completionVoiceLine: 'Well done. You can open that door anytime.',
    ),
    'Mindful Observation': _CopingGuidedProfile(
      badge: 'Single-point focus',
      idleHeadline: 'One object, full curiosity',
      idleSubtext: 'Let the future-thoughts wait; the object is enough for now.',
      stepTags: ['Choose the object', 'Beginner eyes', 'Surface and edge', 'Light play', 'Two minutes of looking', 'What shifted', 'Ease out'],
      stepSeconds: [25, 40, 45, 40, 125, 40, 25],
      fallbackSeconds: 45,
      visualKind: _GuidedCopingVisualKind.mindful,
      centerIcon: Icons.remove_red_eye_rounded,
      openingVoiceLine: 'Treat this like seeing for the first time — slow, patient, curious.',
      completionMessage: 'You trained “now” attention on something ordinary. That is mindfulness.',
      completionVoiceLine: 'Nice work. Notice if the mind feels a half-step quieter.',
    ),
    'Self-Compassion Break': _CopingGuidedProfile(
      badge: 'Neff · three moves',
      idleHeadline: 'Kindness when it hurts',
      idleSubtext: 'Acknowledge, common humanity, then a gentle toward-yourself line.',
      stepTags: ['Name the pain', 'Common humanity', 'Hand on heart', 'Kind phrase', 'Ask what you need', 'Permission', 'You belong'],
      stepSeconds: [35, 40, 35, 40, 45, 40, 40],
      fallbackSeconds: 40,
      visualKind: _GuidedCopingVisualKind.compassion,
      centerIcon: Icons.favorite_rounded,
      openingVoiceLine: 'This is not self-indulgence — it is emotional first aid.',
      completionMessage: 'You spoke to yourself the way a good friend would. That matters.',
      completionVoiceLine: 'Beautiful. Let that warmth stay a moment longer.',
    ),
    'Compassionate Letter': _CopingGuidedProfile(
      badge: 'Write as a loving friend',
      idleHeadline: 'Let kindness flow onto the page',
      idleSubtext: 'No grading the prose — only honesty and care.',
      stepTags: ['Picture the friend', 'Their view of you', 'Write in their voice', 'Honor the hurt', 'Name strengths', 'Encouraging close', 'Keep it close'],
      fallbackSeconds: 55,
      durationPresets: const [45, 60, 75, 90],
      visualKind: _GuidedCopingVisualKind.compassion,
      centerIcon: Icons.edit_note_rounded,
      openingVoiceLine: 'Borrow the voice of someone who loves you until yours remembers how.',
      completionMessage: 'You externalized care toward yourself. Reread it on rough days.',
      completionVoiceLine: 'Well done. That letter is evidence you can be on your own side.',
    ),
    'Gratitude List': _CopingGuidedProfile(
      badge: 'Small specifics · big shift',
      idleHeadline: 'Name concrete good things',
      idleSubtext: 'Specific beats vague — one true detail beats ten platitudes.',
      stepTags: ['Choose medium', 'Three specifics', 'Add texture', 'Feel each line', 'One about you', 'Read aloud internally', 'Save for later'],
      stepSeconds: [25, 45, 40, 45, 40, 35, 30],
      fallbackSeconds: 40,
      visualKind: _GuidedCopingVisualKind.compassion,
      centerIcon: Icons.emoji_events_rounded,
      openingVoiceLine: 'Hunt for small, true bright spots — they count more than you think.',
      completionMessage: 'You widened the lens toward what is also true besides the struggle.',
      completionVoiceLine: 'Nice. Keep this list where you can find it.',
    ),
    'Container Exercise': _CopingGuidedProfile(
      badge: 'Containment imagery',
      idleHeadline: 'Put worries somewhere strong',
      idleSubtext: 'You are not erasing them — you are storing them until you are resourced.',
      stepTags: ['Arrive with breath', 'See the container', 'Place each worry', 'Weight lifts', 'Lock it', 'Trust the hold', 'Open only when ready'],
      stepSeconds: [35, 40, 50, 45, 35, 40, 40],
      fallbackSeconds: 40,
      visualKind: _GuidedCopingVisualKind.containment,
      centerIcon: Icons.inventory_2_rounded,
      openingVoiceLine: 'Imagine a container strong enough to hold what feels too heavy to carry loose.',
      completionMessage: 'You visualized boundaries for your worry — a skill therapists teach for a reason.',
      completionVoiceLine: 'Well done. Nothing was erased; it was held safely.',
    ),
  };

  static _CopingGuidedProfile forTool(Map<String, dynamic> tool) {
    final title = tool['title'] as String;
    final base = _byTitle[title] ?? _fallbackForCategory(tool['category'] as String);
    final n = (tool['steps'] as List).length;
    return _CopingGuidedProfile(
      badge: base.badge,
      idleHeadline: base.idleHeadline,
      idleSubtext: base.idleSubtext,
      stepTags: _padList(base.stepTags, n, (i) => 'Step ${i + 1}'),
      stepSeconds: base.stepSeconds == null ? null : _padInts(base.stepSeconds!, n, base.fallbackSeconds),
      fallbackSeconds: base.fallbackSeconds,
      defaultRounds: base.defaultRounds,
      durationPresets: base.durationPresets,
      visualKind: base.visualKind,
      centerIcon: base.centerIcon,
      openingVoiceLine: base.openingVoiceLine,
      completionMessage: base.completionMessage,
      completionVoiceLine: base.completionVoiceLine,
    );
  }

  static List<String> _padList(List<String> items, int n, String Function(int i) filler) {
    if (items.length >= n) return items.sublist(0, n);
    return [...items, ...List.generate(n - items.length, (j) => filler(items.length + j))];
  }

  static List<int> _padInts(List<int> items, int n, int fill) {
    if (items.length >= n) return items.sublist(0, n);
    return [...items, ...List.filled(n - items.length, fill)];
  }

  static _CopingGuidedProfile _fallbackForCategory(String category) {
    switch (category) {
      case 'Grounding':
        return _CopingGuidedProfile(
          badge: 'Grounding',
          idleHeadline: 'Come back to the present',
          idleSubtext: 'Use your body and senses as anchors.',
          stepTags: const ['Step 1', 'Step 2', 'Step 3', 'Step 4', 'Step 5', 'Step 6', 'Step 7'],
          fallbackSeconds: 40,
          visualKind: _GuidedCopingVisualKind.anchor,
          centerIcon: Icons.anchor_rounded,
          completionMessage: 'You practiced grounding — attention on what is real right now.',
        );
      case 'Somatic':
        return _CopingGuidedProfile(
          badge: 'Body-based regulation',
          idleHeadline: 'Work with sensation and release',
          idleSubtext: 'Small physical shifts can reset emotional charge.',
          stepTags: const ['Step 1', 'Step 2', 'Step 3', 'Step 4', 'Step 5', 'Step 6', 'Step 7'],
          fallbackSeconds: 38,
          visualKind: _GuidedCopingVisualKind.somatic,
          centerIcon: Icons.spa_rounded,
          completionMessage: 'You tended to your body as a way to calm the mind.',
        );
      case 'CBT':
        return _CopingGuidedProfile(
          badge: 'Think it through clearly',
          idleHeadline: 'Slow, structured reflection',
          idleSubtext: 'Write if you can; thinking aloud works too.',
          stepTags: const ['Step 1', 'Step 2', 'Step 3', 'Step 4', 'Step 5', 'Step 6', 'Step 7'],
          fallbackSeconds: 50,
          durationPresets: const [40, 50, 60, 90],
          visualKind: _GuidedCopingVisualKind.cognitive,
          centerIcon: Icons.psychology_alt_rounded,
          completionMessage: 'You gave your thoughts structure instead of rumination.',
        );
      case 'Mindfulness':
        return _CopingGuidedProfile(
          badge: 'Present-moment training',
          idleHeadline: 'Widen awareness, gently',
          idleSubtext: 'Return kindly when attention wanders — that is the practice.',
          stepTags: const ['Step 1', 'Step 2', 'Step 3', 'Step 4', 'Step 5', 'Step 6', 'Step 7'],
          fallbackSeconds: 45,
          visualKind: _GuidedCopingVisualKind.mindful,
          centerIcon: Icons.self_improvement_rounded,
          completionMessage: 'You spent intentional time with the present. That counts.',
        );
      case 'Self-Compassion':
        return _CopingGuidedProfile(
          badge: 'Kind inner voice',
          idleHeadline: 'Turn warmth toward yourself',
          idleSubtext: 'You deserve the same care you give others.',
          stepTags: const ['Step 1', 'Step 2', 'Step 3', 'Step 4', 'Step 5', 'Step 6', 'Step 7'],
          fallbackSeconds: 45,
          visualKind: _GuidedCopingVisualKind.compassion,
          centerIcon: Icons.volunteer_activism_rounded,
          completionMessage: 'You practiced self-compassion as a skill, not a mood.',
        );
      default:
        return _CopingGuidedProfile(
          badge: 'Guided practice',
          idleHeadline: 'Move through each step',
          stepTags: const ['Step 1', 'Step 2', 'Step 3', 'Step 4', 'Step 5', 'Step 6', 'Step 7'],
          fallbackSeconds: 35,
          visualKind: _GuidedCopingVisualKind.anchor,
          centerIcon: Icons.self_improvement_rounded,
          completionMessage: 'You completed this guided session.',
        );
    }
  }
}

class GuidedCopingSession extends StatefulWidget {
  final Map<String, dynamic> toolData;
  const GuidedCopingSession({super.key, required this.toolData});

  @override
  State<GuidedCopingSession> createState() => _GuidedCopingSessionState();
}

class _GuidedCopingSessionState extends State<GuidedCopingSession> {
  late FlutterTts _tts;
  Timer? _timer;
  late _CopingGuidedProfile _profile;

  int _currentStepIndex = 0;
  int _secondsPerStep = 30;
  int _secondsRemaining = 0;
  int _totalLoops = 1;
  int _completedLoops = 0;
  bool _isRunning = false;
  bool _voiceGuidance = true;
  bool _showingSettings = false;
  bool _openingSpoken = false;

  List<String> get _steps => (widget.toolData['steps'] as List).cast<String>();
  Color get _color => widget.toolData['color'] as Color;
  bool get _hasProgress => _currentStepIndex > 0 || _completedLoops > 0 || _secondsRemaining > 0;
  bool get _usesCustomStepSeconds => _profile.stepSeconds != null;

  int _secondsForStepIndex(int index) {
    if (_usesCustomStepSeconds && index >= 0 && index < _profile.stepSeconds!.length) {
      return _profile.stepSeconds![index];
    }
    return _secondsPerStep;
  }

  double _sessionProgressFraction() {
    if (_steps.isEmpty) return 0;
    var total = 0;
    for (var l = 0; l < _totalLoops; l++) {
      for (var i = 0; i < _steps.length; i++) {
        total += _secondsForStepIndex(i);
      }
    }
    if (total <= 0) return 0;
    var done = 0;
    for (var l = 0; l < _totalLoops; l++) {
      for (var i = 0; i < _steps.length; i++) {
        final d = _secondsForStepIndex(i);
        if (l < _completedLoops || (l == _completedLoops && i < _currentStepIndex)) {
          done += d;
        } else if (l == _completedLoops && i == _currentStepIndex) {
          if (_isRunning || _secondsRemaining > 0) {
            done += d - _secondsRemaining;
          }
          return (done / total).clamp(0.0, 1.0);
        } else {
          return (done / total).clamp(0.0, 1.0);
        }
      }
    }
    return 1.0;
  }

  @override
  void initState() {
    super.initState();
    _profile = _CopingGuidedProfile.forTool(widget.toolData);
    _secondsPerStep = _profile.fallbackSeconds;
    _totalLoops = _profile.defaultRounds;
    _tts = FlutterTts();
    configureTtsVoice(_tts);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _startSession() {
    if (_steps.isEmpty) return;
    _timer?.cancel();
    _tts.stop();
    setState(() {
      _openingSpoken = false;
      _currentStepIndex = 0;
      _secondsRemaining = _secondsForStepIndex(0);
      _completedLoops = 0;
      _isRunning = true;
    });
    _announceCurrentStep(includeStepText: true);
    _startTicking();
  }

  void _pauseSession() {
    _timer?.cancel();
    _tts.stop();
    setState(() => _isRunning = false);
  }

  void _resumeSession() {
    if (_steps.isEmpty) return;
    setState(() => _isRunning = true);
    _announceCurrentStep();
    _startTicking();
  }

  void _stopSession() {
    _timer?.cancel();
    _tts.stop();
    setState(() {
      _isRunning = false;
      _currentStepIndex = 0;
      _secondsRemaining = 0;
      _completedLoops = 0;
      _openingSpoken = false;
    });
  }

  BorderRadius _centerpieceRadius() {
    switch (_profile.visualKind) {
      case _GuidedCopingVisualKind.cognitive:
        return BorderRadius.circular(22);
      case _GuidedCopingVisualKind.containment:
        return BorderRadius.circular(14);
      case _GuidedCopingVisualKind.coldSplash:
        return const BorderRadius.vertical(top: Radius.circular(52), bottom: Radius.circular(18));
      case _GuidedCopingVisualKind.bilateral:
        return BorderRadius.circular(36);
      case _GuidedCopingVisualKind.somatic:
        return BorderRadius.circular(28);
      case _GuidedCopingVisualKind.mindful:
        return BorderRadius.circular(100);
      case _GuidedCopingVisualKind.compassion:
        return BorderRadius.circular(100);
      case _GuidedCopingVisualKind.senses:
      case _GuidedCopingVisualKind.anchor:
      case _GuidedCopingVisualKind.rooted:
        return BorderRadius.circular(100);
    }
  }

  Widget _buildGuidedCenterpiece() {
    final tag = _steps.isEmpty ? "" : _profile.stepTags[_currentStepIndex];
    final stepDur = _steps.isEmpty ? 0 : _secondsForStepIndex(_currentStepIndex);
    final displaySec = _isRunning ? _secondsRemaining : stepDur;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      tween: Tween<double>(begin: 0.96, end: _isRunning ? 1.02 : 1.0),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: _centerpieceRadius(),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _color.withValues(alpha: 0.14),
              _color.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: _color.withValues(alpha: 0.24), width: 2),
          boxShadow: [
            BoxShadow(color: _color.withValues(alpha: _isRunning ? 0.24 : 0.1), blurRadius: _isRunning ? 30 : 12, spreadRadius: _isRunning ? 1 : 0),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_profile.centerIcon, size: 34, color: _color.withValues(alpha: 0.9)),
            const SizedBox(height: 10),
            Text(
              _isRunning ? "$displaySec" : "${displaySec}s",
              style: GoogleFonts.inter(fontSize: 46, fontWeight: FontWeight.w300, color: _color),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                tag,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _color.withValues(alpha: 0.82), letterSpacing: 0.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
      });
      if (_secondsRemaining <= 0) {
        _advanceToNextStep();
      }
    });
  }

  void _skipToNextStep() {
    if (!_isRunning) return;
    _timer?.cancel();
    _tts.stop();
    _advanceToNextStep();
    if (_isRunning) _startTicking();
  }

  void _advanceToNextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _secondsRemaining = _secondsForStepIndex(_currentStepIndex);
      });
      _announceCurrentStep(includeStepText: true);
      return;
    }

    if (_completedLoops < _totalLoops - 1) {
      setState(() {
        _completedLoops++;
        _currentStepIndex = 0;
        _secondsRemaining = _secondsForStepIndex(0);
      });
      _announceCurrentStep(includeStepText: true, announceLoop: true);
      return;
    }

    _completeSession();
  }

  void _announceCurrentStep({bool includeStepText = false, bool announceLoop = false}) {
    if (!_voiceGuidance) return;
    final stepNumber = _currentStepIndex + 1;
    final tag = _profile.stepTags[_currentStepIndex];
    final loopIntro = announceLoop ? "Starting round ${_completedLoops + 1}. " : "";
    var open = "";
    if (includeStepText && !_openingSpoken && _profile.openingVoiceLine != null) {
      open = "${_profile.openingVoiceLine} ";
      _openingSpoken = true;
    }
    final body = includeStepText
        ? "$tag. ${_steps[_currentStepIndex]}"
        : tag;
    _tts.speak("$open$loopIntro Step $stepNumber. $body");
  }

  void _completeSession() {
    _timer?.cancel();
    _tts.stop();
    setState(() {
      _isRunning = false;
      _currentStepIndex = 0;
      _secondsRemaining = 0;
      _completedLoops = 0;
      _openingSpoken = false;
    });
    if (_voiceGuidance) {
      _tts.speak(_profile.completionVoiceLine ?? "Session complete. Well done.");
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Session Complete! 🎉", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(_profile.completionMessage ?? "You completed a guided ${widget.toolData['title']} session.", style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text("Done", style: GoogleFonts.inter(color: _color, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startSession();
            },
            child: Text("Go Again", style: GoogleFonts.inter(color: _color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _sessionProgressFraction();
    final currentStep = _steps.isEmpty ? "" : _steps[_currentStepIndex];
    final headline = _isRunning ? _profile.stepTags[_currentStepIndex] : _profile.idleHeadline;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F5),
        title: Text(widget.toolData['title'] as String, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => setState(() => _showingSettings = !_showingSettings),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showingSettings) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_usesCustomStepSeconds) ...[
                    Text("Pacing", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      "This technique uses tailored time per step (for example, longer “observe” moments).",
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B6B66), height: 1.45),
                    ),
                  ] else ...[
                    Text("Seconds per step", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _profile.durationPresets.map((seconds) => GestureDetector(
                        onTap: () => setState(() {
                          _secondsPerStep = seconds;
                          if (!_isRunning && _secondsRemaining == 0) {
                            _secondsRemaining = seconds;
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _secondsPerStep == seconds ? _color : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _secondsPerStep == seconds ? _color : Colors.black.withValues(alpha: 0.1)),
                          ),
                          child: Text("$seconds s", style: GoogleFonts.inter(
                            color: _secondsPerStep == seconds ? Colors.white : const Color(0xFF404040),
                            fontWeight: FontWeight.w600,
                          )),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text("Rounds", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 2, 3].map((loops) => GestureDetector(
                      onTap: () => setState(() => _totalLoops = loops),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _totalLoops == loops ? _color : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _totalLoops == loops ? _color : Colors.black.withValues(alpha: 0.1)),
                        ),
                        child: Text("$loops", style: GoogleFonts.inter(
                          color: _totalLoops == loops ? Colors.white : const Color(0xFF404040),
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Voice Guidance", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                      Switch(
                        value: _voiceGuidance,
                        onChanged: (val) => setState(() => _voiceGuidance = val),
                        activeThumbColor: _color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                    child: Text(_profile.badge, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _color.withValues(alpha: 0.95), letterSpacing: 0.3)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    headline,
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: _color, height: 1.25),
                    textAlign: TextAlign.center,
                  ),
                  if (!_isRunning && _profile.idleSubtext != null) ...[
                    const SizedBox(height: 10),
                    Text(_profile.idleSubtext!, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B6B66), height: 1.45), textAlign: TextAlign.center),
                  ],
                  if (_isRunning) ...[
                    const SizedBox(height: 8),
                    Text("Step ${_currentStepIndex + 1} of ${_steps.length}", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF9CA3AF))),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _color.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      currentStep,
                      style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF404040), height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildGuidedCenterpiece(),
                  const SizedBox(height: 18),
                  Text(
                    "Round ${_completedLoops + 1} of $_totalLoops",
                    style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF6B6B66)),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.black.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(_color),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _isRunning
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _skipToNextStep,
                          icon: const Icon(Icons.skip_next_rounded, size: 20),
                          label: Text("Next Step", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pauseSession,
                              icon: const Icon(Icons.pause_rounded),
                              label: Text("Pause", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _color,
                                side: BorderSide(color: _color),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _stopSession,
                              icon: const Icon(Icons.stop_rounded),
                              label: Text("Stop", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                foregroundColor: Colors.red.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _hasProgress ? _resumeSession : _startSession,
                      icon: Icon(_hasProgress ? Icons.play_arrow_rounded : Icons.play_circle_fill_rounded),
                      label: Text(_hasProgress ? "Resume Session" : "Start Session", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//  GUIDED BREATHING SESSION
// =====================================================================
class GuidedBreathingSession extends StatefulWidget {
  final Map<String, dynamic> breathingData;
  const GuidedBreathingSession({super.key, required this.breathingData});
  
  @override
  State<GuidedBreathingSession> createState() => _GuidedBreathingSessionState();
}

class _GuidedBreathingSessionState extends State<GuidedBreathingSession> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late FlutterTts _tts;
  int _currentPhaseIndex = 0;
  int _currentCount = 0;
  int _cyclesCompleted = 0;
  int _totalMinutes = 2;
  Timer? _timer;
  bool _isRunning = false;
  bool _showingSettings = false;
  bool _voiceGuidance = true;

  List<int> get _pattern => (widget.breathingData['pattern'] as List).cast<int>();
  List<String> get _labels => (widget.breathingData['patternLabels'] as List).cast<String>();
  Color get _color => widget.breathingData['color'] as Color;

  int get _totalCycles {
    final totalSeconds = _totalMinutes * 60;
    final cycleSeconds = _pattern.reduce((a, b) => a + b);
    return (totalSeconds / cycleSeconds).floor();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = Tween<double>(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _tts = FlutterTts();
    configureTtsVoice(_tts);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _tts.stop();
    super.dispose();
  }

  void _startSession() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _currentPhaseIndex = 0;
      _currentCount = _pattern[0];
      _cyclesCompleted = 0;
    });
    _startPhase();
  }

  void _pauseSession() {
    setState(() => _isRunning = false);
    _timer?.cancel();
    _controller.stop();
    _tts.stop();
  }

  void _resumeSession() {
    setState(() => _isRunning = true);
    _startPhase();
  }

  void _stopSession() {
    _timer?.cancel();
    _controller.stop();
    _tts.stop();
    setState(() {
      _isRunning = false;
      _currentPhaseIndex = 0;
      _currentCount = 0;
      _cyclesCompleted = 0;
    });
  }

  void _startPhase() {
    _currentCount = _pattern[_currentPhaseIndex];
    final phaseDuration = Duration(seconds: _pattern[_currentPhaseIndex]);

    if (_voiceGuidance) {
      _tts.speak(_labels[_currentPhaseIndex]);
    }

    _controller.duration = phaseDuration;

    final label = _labels[_currentPhaseIndex];
    if (label.contains("In")) {
      _controller.forward(from: 0.0);
    } else if (label.contains("Out")) {
      _controller.reverse(from: 1.0);
    } else {
      final holdSize = _animation.value;
      _controller.stop();
      _controller.duration = const Duration(milliseconds: 1200);
      _animation = Tween<double>(
        begin: holdSize - 0.02,
        end: holdSize + 0.02,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.repeat(reverse: true);
    }

    if (!label.contains("Hold")) {
      _animation = Tween<double>(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      setState(() {
        _currentCount--;
        if (_currentCount <= 0) {
          _currentPhaseIndex++;
          if (_currentPhaseIndex >= _pattern.length) {
            _currentPhaseIndex = 0;
            _cyclesCompleted++;
            if (_cyclesCompleted >= _totalCycles) {
              _completeSession();
              timer.cancel();
              return;
            }
          }
          _currentCount = _pattern[_currentPhaseIndex];
          timer.cancel();
          _startPhase();
        }
      });
    });
  }

  void _completeSession() {
    _timer?.cancel();
    _controller.stop();
    setState(() => _isRunning = false);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Session Complete! 🎉", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text("You've completed $_totalMinutes minutes of ${widget.breathingData['title']}. Well done!", style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text("Done", style: GoogleFonts.inter(color: _color, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _stopSession();
              _startSession();
            },
            child: Text("Go Again", style: GoogleFonts.inter(color: _color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F5),
        title: Text(widget.breathingData['title'] as String, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => setState(() => _showingSettings = !_showingSettings),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showingSettings) ...[
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Session Duration", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [1, 2, 3, 5, 10].map((mins) => GestureDetector(
                      onTap: () => setState(() => _totalMinutes = mins),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _totalMinutes == mins ? _color : Colors.white,
                          border: Border.all(color: _totalMinutes == mins ? _color : Colors.black.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text("$mins min", style: GoogleFonts.inter(
                          color: _totalMinutes == mins ? Colors.white : const Color(0xFF404040),
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Voice Guidance", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                      Switch(
                        value: _voiceGuidance,
                        onChanged: (val) => setState(() => _voiceGuidance = val),
                        activeThumbColor: _color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isRunning ? _labels[_currentPhaseIndex] : "Ready to Begin",
                    style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: _color),
                  ),
                  const SizedBox(height: 40),
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final ringScale = _isRunning ? (0.96 + (_animation.value * 0.08)) : 1.0;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: ringScale,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _color.withValues(alpha: 0.16), width: 2),
                              ),
                            ),
                          ),
                          Container(
                            width: 250 * _animation.value,
                            height: 250 * _animation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _color.withValues(alpha: 0.34),
                                  _color.withValues(alpha: 0.12),
                                  _color.withValues(alpha: 0.05),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _color.withValues(alpha: 0.34),
                                  blurRadius: 32 * _animation.value,
                                  spreadRadius: 6 * _animation.value,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _isRunning ? "$_currentCount" : "•",
                                style: GoogleFonts.inter(
                                  fontSize: 80,
                                  fontWeight: FontWeight.w300,
                                  color: _color,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  if (_isRunning) ...[
                    Text(
                      "Cycle ${_cyclesCompleted + 1} of $_totalCycles",
                      style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF6B6B66)),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _cyclesCompleted / _totalCycles,
                      backgroundColor: Colors.black.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(_color),
                    ),
                  ] else
                    Text(
                      "$_totalMinutes minute session • $_totalCycles cycles",
                      style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF6B6B66)),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (_isRunning)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pauseSession,
                          icon: const Icon(Icons.pause_rounded),
                          label: Text("Pause", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _color,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: _color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _stopSession,
                          icon: const Icon(Icons.stop_rounded),
                          label: Text("Stop", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _cyclesCompleted > 0 ? _resumeSession : _startSession,
                      icon: Icon(_cyclesCompleted > 0 ? Icons.play_arrow_rounded : Icons.self_improvement_rounded),
                      label: Text(_cyclesCompleted > 0 ? "Resume" : "Start Session", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//  PROFILE PAGE
// =====================================================================
