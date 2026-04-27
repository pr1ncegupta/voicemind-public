import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'talk_provider.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/tools/tools_screens.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/chat_message.dart';
import '../../data/models/tools_data.dart';
import '../profile/profile_screens.dart';
import '../../common/constants.dart';

class TalkPage extends ConsumerStatefulWidget {
  const TalkPage({super.key});
  @override
  ConsumerState<TalkPage> createState() => _TalkPageState();
}

class _TalkPageState extends ConsumerState<TalkPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late Animation<double> _pulseAnim;
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _quickFilters = [
    {'emoji': '😴', 'label': 'sleepless', 'color': const Color(0xFF8B5CF6)},
    {'emoji': '😟', 'label': 'anxious', 'color': const Color(0xFFF59E0B)},
    {'emoji': '😠', 'label': 'angry', 'color': const Color(0xFFEF4444)},
    {'emoji': '😥', 'label': 'sad', 'color': const Color(0xFF3B82F6)},
    {'emoji': '😓', 'label': 'stressed', 'color': const Color(0xFFD97757)}
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _waveCtrl = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this)..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(talkProvider.notifier);
      notifier.onCrisisAlert = (data) {
        if (mounted) {
          showModalBottomSheet(context: context, isScrollControlled: true, isDismissible: false, enableDrag: false, backgroundColor: Colors.transparent, builder: (ctx) => CrisisAlertSheet(crisisData: data)).whenComplete(() {
            notifier.resetCrisisAlert();
          });
        }
      };
      notifier.onThinkingStart = () => _scrollToBottom();
      notifier.onThinkingStop = () => _scrollToBottom();
      notifier.onListeningStart = () {
        _pulseCtrl.repeat(reverse: true);
        _scrollToBottom();
      };
      notifier.onListeningStop = () {
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      };
      notifier.onSuggestWellnessActivity = (emotion) {
        _suggestWellnessActivity(emotion);
      };
      notifier.onOfflineFallback = () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text("Trouble connecting to server — showing offline response")),
          ]),
          backgroundColor: const Color(0xFF6B6B66),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: "Try again",
            textColor: Colors.white,
            onPressed: () {
              final lastUserMsg = ref.read(talkProvider).messages.lastWhere(
                (m) => m.isUser,
                orElse: () => ChatMessage(text: "", isUser: true),
              );
              if (lastUserMsg.text.isNotEmpty) {
                notifier.processInput(lastUserMsg.text);
              }
            },
          ),
        ));
      };
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _handleTextSubmit(TalkNotifier notifier) {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    FocusScope.of(context).unfocus();
    notifier.processInputWithSuggestions(text);
  }

  void _suggestWellnessActivity(String signal) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      var suggestion = "";
      String? toolTitle;

      if (signal.startsWith("ACTION:")) {
        final parts = signal.split(":");
        final tag = parts.length > 1 ? parts[1] : "";
        final actionText = parts.length > 2 ? parts.sublist(2).join(":") : "";
        switch (tag) {
          case "breathing":
            toolTitle = actionText.toLowerCase().contains("4-7-8") ? "4-7-8 Breath" : "Box Breathing";
            suggestion = "AI suggested breathing. Start $toolTitle now?";
            break;
          case "grounding":
            toolTitle = "5-4-3-2-1 Grounding";
            suggestion = "AI suggested grounding. Start $toolTitle now?";
            break;
          case "somatic":
            toolTitle = "Progressive Muscle Relaxation";
            suggestion = "AI suggested body relaxation. Start $toolTitle now?";
            break;
          default:
            suggestion = "A coping exercise was suggested. Open Coping Toolbox?";
        }
      } else {
        final emotion = signal.replaceFirst("EMOTION:", "");
        switch (emotion) {
          case "anxious": suggestion = "Try Box Breathing to calm your nervous system"; toolTitle = "Box Breathing"; break;
          case "sad": suggestion = "A Gratitude Journal might help shift your mood"; break;
          case "stressed": suggestion = "Progressive Muscle Relaxation can release tension"; toolTitle = "Progressive Muscle Relaxation"; break;
          case "sleepless": suggestion = "4-7-8 Breathing can help you fall asleep"; toolTitle = "4-7-8 Breath"; break;
          case "angry": suggestion = "Try the STOP technique to reset"; break;
          default: return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.lightbulb_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(suggestion, style: GoogleFonts.inter())),
        ]),
        backgroundColor: const Color(0xFFD97757),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: toolTitle != null ? "Start now" : "View",
          textColor: Colors.white,
          onPressed: () {
            if (toolTitle != null) {
              final match = kCopingTools.cast<Map<String, dynamic>?>().firstWhere(
                (e) => e?['title'] == toolTitle,
                orElse: () => null,
              );
              if (match != null) {
                if (match['category'] == 'Breathing' && match['pattern'] != null) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuidedBreathingSession(breathingData: match)));
                } else {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuidedCopingSession(toolData: match)));
                }
                return;
              }
            }
            MainDashboard.switchToTab(0);
          },
        ),
        duration: const Duration(seconds: 4),
      ));
    });
  }

  /// Voice status and short hints for turn-based mode.
  Widget _buildVoiceTransportBanner(TalkState state) {
    if (state.voiceHint.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDBA74).withValues(alpha: 0.7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFEA580C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.voiceHint,
                  style: GoogleFonts.inter(fontSize: 12, height: 1.35, color: const Color(0xFF9A3412)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (state.isListening && state.activeVoiceTransport == VoiceTransport.standardFallback) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Standard mode — device voice for replies (same AI via text)',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFFB45309)),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(talkProvider);
    final notifier = ref.read(talkProvider.notifier);
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        title: Text("VoiceMind", style: GoogleFonts.inter(color: const Color(0xFF191918), fontWeight: FontWeight.w600, fontSize: 17)),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Open profile',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          icon: const Icon(Icons.person_outline_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Open crisis helplines',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelplinesPage())),
            icon: const Icon(Icons.emergency_rounded),
          )
        ],
      ),
      body: Column(
        children: [
          // Quick emotion chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _quickFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final f = _quickFilters[i];
                return GestureDetector(
                  onTap: () => ref.read(talkProvider.notifier).processInputWithSuggestions("I'm feeling ${f['label']}"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withValues(alpha: 0.08))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(f['emoji'] as String, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        f['label'] as String,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF404040)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          _buildVoiceTransportBanner(state),

          // WebSocket Status Indicator
          if (state.wsConnected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Live crisis detection active",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF6B6B66),
                    ),
                  ),
                ],
              ),
            ),

          // Conversation area (history + orb)
          Expanded(
            child: state.messages.isEmpty ? _buildEmptyState(state, notifier) : _buildConversation(state, notifier),
          ),

          // Text input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06)))),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    onSubmitted: (_) => _handleTextSubmit(notifier),
                    textInputAction: TextInputAction.send,
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: "Type how you're feeling...",
                      hintStyle: GoogleFonts.inter(color: const Color(0xFFB0B0B0), fontSize: 14),
                      filled: true, fillColor: const Color(0xFFF5F3F0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: state.isListening ? 'Stop listening' : 'Start listening',
                  child: GestureDetector(
                    onTap: notifier.handleMicPress,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: state.isListening ? const Color(0xFFD97757) : const Color(0xFFF5F3F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: state.isListening
                              ? const Color(0xFFD97757)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        state.isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                        color: state.isListening ? Colors.white : const Color(0xFF6B6B66),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Send message',
                  child: GestureDetector(
                    onTap: () => _handleTextSubmit(notifier),
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFC9A88B), Color(0xFFD97757)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TalkState state, TalkNotifier notifier) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 60),
          AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Text(state.statusText, key: ValueKey(state.statusText), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, color: state.isListening ? const Color(0xFF191918) : const Color(0xFF9CA3AF), fontWeight: FontWeight.w500))),
          const SizedBox(height: 32),
          _buildOrb(state, notifier),
          const SizedBox(height: 16),
          if (!state.isListening && !state.isThinking) Text("Tap to speak, type below, or shake your phone", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFB0B0B0))),
          if (state.isListening && state.liveTranscript.isNotEmpty) _buildLiveTranscript(state),
        ],
      ),
    );
  }

  Widget _buildConversation(TalkState state, TalkNotifier notifier) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: state.messages.length + (state.isThinking ? 1 : 0) + (state.isListening ? 1 : 0),
      itemBuilder: (ctx, i) {
        // Live transcript card while listening
        if (state.isListening && i == state.messages.length + (state.isThinking ? 1 : 0)) {
          return _buildLiveTranscript(state);
        }
        // Thinking indicator
        if (state.isThinking && i == state.messages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withValues(alpha: 0.06))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97757))),
                  const SizedBox(width: 10),
                  Text("Thinking...", style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF))),
                ]),
              ),
            ]),
          );
        }

        final msg = state.messages[i];
        if (msg.isUser) return _buildUserBubble(msg);
        return _buildAiBubble(msg, notifier);
      },
    );
  }

  Widget _buildOrb(TalkState state, TalkNotifier notifier) {
    return Center(
      child: Semantics(
        button: true,
        label: state.isListening ? 'Stop listening' : 'Start listening',
        child: GestureDetector(
          onTap: notifier.handleMicPress,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (ctx, _) {
              final scale = state.isListening ? _pulseAnim.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: Stack(alignment: Alignment.center, children: [
                  if (state.isListening || state.isThinking)
                    AnimatedBuilder(
                      animation: _waveCtrl,
                      builder: (ctx, _) => Container(
                        width: 140 + (state.soundLevel * 30),
                        height: 140 + (state.soundLevel * 30),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFD97757).withValues(alpha: 0.15)),
                      ),
                    ),
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFC9A88B), Color(0xFFD97757)]),
                      boxShadow: [BoxShadow(color: const Color(0xFFD97757).withValues(alpha: state.isListening ? 0.5 : 0.25), blurRadius: state.isListening ? 40 : 25, spreadRadius: state.isListening ? 5 : 0)],
                    ),
                    child: Center(
                      child: state.isListening
                          ? AnimatedBuilder(
                              animation: _waveCtrl,
                              builder: (ctx, _) => Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (j) {
                                  final phase = (j - 2) * 0.2;
                                  final h = 16 + (math.sin((_waveCtrl.value + phase) * math.pi * 2) * 10) + (state.soundLevel * 15);
                                  return Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 4, height: h.clamp(6.0, 40.0), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(2)));
                                }),
                              ),
                            )
                          : Icon(state.isThinking ? Icons.auto_awesome : Icons.mic_none_rounded, size: 40, color: Colors.white),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLiveTranscript(TalkState state) {
    if (state.liveTranscript.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD97757).withValues(alpha: 0.2))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFD97757), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text("Listening", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFFD97757))),
        ]),
        const SizedBox(height: 10),
        Text(state.liveTranscript, textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFF404040), fontSize: 15, height: 1.5)),
      ]),
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 40),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFD97757), borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4))),
            child: Text(msg.text, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, height: 1.4)),
          ),
        ),
      ]),
    );
  }

  Widget _buildAiBubble(ChatMessage msg, TalkNotifier notifier) {
    // Some assistant turns can be plain text without the structured fields.
    // Render those as a simple conversational bubble.
    if ((msg.validation == null || msg.validation!.isEmpty) &&
        (msg.action == null || msg.action!.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 24),
        child: Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Text(
                  msg.text,
                  style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF191918), height: 1.45),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Offline badge
        if (msg.isOffline)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off_rounded, size: 12, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text("Offline response", style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        // Response card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFFEF3EF), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.favorite_rounded, color: Color(0xFFD97757), size: 14)),
              const SizedBox(width: 8),
              Text("We hear you", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD97757))),
            ]),
            const SizedBox(height: 8),
            Text(msg.validation ?? "", style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF191918), fontWeight: FontWeight.w500, height: 1.5)),

            if (msg.insight != null && msg.insight!.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Container(height: 1, color: const Color(0xFFF0F0EB))),
              Row(children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFA8B5A0).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFA8B5A0), size: 14)),
                const SizedBox(width: 8),
                Text("A gentle perspective", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6B8F71))),
              ]),
              const SizedBox(height: 8),
              Text(msg.insight!, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF404040), height: 1.6)),
            ],

            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Container(height: 1, color: const Color(0xFFF0F0EB))),
            Row(children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFC9A88B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.spa_rounded, color: Color(0xFFC9A88B), size: 14)),
              const SizedBox(width: 8),
              Text("Try this now", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9C7A5C))),
            ]),
            const SizedBox(height: 8),
            Text(msg.action ?? "", style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF404040), height: 1.6)),
            ..._buildCopingChips(msg.action ?? ""),
          ]),
        ),
      ]),
    );
  }

  static const _copingKeywords = <String, List<String>>{
    'Box Breathing': ['box breathing', 'breathe in for 4', '4-4-4-4', 'deep breath', 'deep breaths', 'take a breath', 'slow breath', 'breathing exercise', 'breathe slowly', 'breathe deeply'],
    '4-7-8 Breath': ['4-7-8', '478 breath'],
    'Diaphragmatic Breathing': ['diaphragmatic', 'belly breath'],
    '5-4-3-2-1 Grounding': ['5-4-3-2-1', 'grounding', '5 things you can see', 'five things', 'name five', 'ground yourself'],
    'Progressive Muscle Relaxation': ['progressive muscle', 'muscle relaxation', 'tense and release', 'tense your', 'release tension'],
    'Body Scan': ['body scan', 'scan your body'],
    'Thought Record': ['thought record', 'write down the thought', 'challenge the thought', 'write down your thoughts', 'journal'],
    'Positive Reframe': ['reframe', 'shift perspective', 'look at it differently', 'another way to see'],
    'Self-Compassion Break': ['self-compassion', 'kind to yourself', 'be gentle with yourself', 'self-care'],
    'Gratitude List': ['gratitude', 'grateful', 'things you appreciate', 'write three things'],
    'Safe Place Visualization': ['safe place', 'visualization', 'visualize', 'imagine a calm', 'picture yourself'],
    'Butterfly Hug': ['butterfly hug', 'bilateral', 'cross your arms', 'tap your shoulders'],
    'Cold Water Reset': ['cold water', 'splash your face', 'cold water on your face'],
    'Container Exercise': ['container exercise', 'place your worries', 'put your worries in a box'],
  };

  List<Widget> _buildCopingChips(String action) {
    if (action.isEmpty) return [];
    final lower = action.toLowerCase();
    final matched = <Map<String, dynamic>>[];
    for (final entry in _copingKeywords.entries) {
      if (entry.value.any((kw) => lower.contains(kw))) {
        final tool = kCopingTools.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['title'] == entry.key,
          orElse: () => null,
        );
        if (tool != null && matched.length < 3) matched.add(tool);
      }
    }
    if (matched.isEmpty) return [];
    return [
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: matched.map((tool) {
        return GestureDetector(
          onTap: () {
            if (tool['category'] == 'Breathing' && tool['pattern'] != null) {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuidedBreathingSession(breathingData: tool)));
            } else {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuidedCopingSession(toolData: tool)));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3EF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD97757).withValues(alpha: 0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.play_circle_outline_rounded, size: 16, color: Color(0xFFD97757)),
              const SizedBox(width: 6),
              Text("Start ${tool['title']}", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFD97757))),
            ]),
          ),
        );
      }).toList()),
    ];
  }
}

// =====================================================================
//  CRISIS ALERT SHEET
// =====================================================================
class CrisisAlertSheet extends StatelessWidget {
  final Map<String, dynamic> crisisData;
  const CrisisAlertSheet({super.key, required this.crisisData});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Icon(Icons.emergency_rounded, size: 56, color: Color(0xFFC94A4A)),
        const SizedBox(height: 16),
        Text("You're Not Alone", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF191918))),
        const SizedBox(height: 12),
        Text(crisisData['message'] as String? ?? "Your life matters. Please reach out for support.", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF6B6B66), height: 1.5)),
        const SizedBox(height: 24),
        _callBtn(context, kPrimaryHelplineUs.name, kPrimaryHelplineUs.telUri, const Color(0xFFC94A4A)),
        const SizedBox(height: 12),
        _callBtn(context, kPrimaryHelplineIndia.name, kPrimaryHelplineIndia.telUri, const Color(0xFFD97757)),
        const SizedBox(height: 12),
        _textFriendBtn(context),
        const SizedBox(height: 16),
        TextButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const HelplinesPage())); }, child: const Text("View All Helplines")),
        const Spacer(),
        TextButton(onPressed: () => Navigator.pop(context), child: Text("I'm okay, close this", style: GoogleFonts.inter(color: const Color(0xFF9CA3AF)))),
      ]),
    );
  }

  Widget _callBtn(BuildContext ctx, String label, String uri, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async { final u = Uri.parse(uri); if (await canLaunchUrl(u)) await launchUrl(u); },
        icon: const Icon(Icons.phone, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _textFriendBtn(BuildContext ctx) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          // whatsapp://app opens the WhatsApp home screen (no number needed).
          final waUri = Uri.parse('whatsapp://app');
          if (await canLaunchUrl(waUri)) {
            await launchUrl(waUri, mode: LaunchMode.externalApplication);
          } else {
            // WhatsApp not installed — open phone dialer.
            final telUri = Uri.parse('tel:');
            if (await canLaunchUrl(telUri)) await launchUrl(telUri);
          }
        },
        icon: const Icon(Icons.message_rounded, color: Color(0xFF25D366)),
        label: Text("Call or WhatsApp a Friend", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF25D366))),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// =====================================================================
//  COPING TOOLBOX PAGE  (20 tools, categorized, fully offline)
// =====================================================================
