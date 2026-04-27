import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../auth_service.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/user_profile.dart';
import '../../services/offline_engine.dart';
import '../../common/constants.dart';

enum VoiceTransport { idle, standardFallback }

class TalkState {
  final bool isListening;
  final bool isThinking;
  final String statusText;
  final String liveTranscript;
  final String detectedEmotion;
  final List<ChatMessage> messages;
  final double soundLevel;
  final bool wsConnected;
  final VoiceTransport activeVoiceTransport;
  final String voiceHint;

  const TalkState({
    this.isListening = false,
    this.isThinking = false,
    this.statusText = "Tap to share how you feel",
    this.liveTranscript = "",
    this.detectedEmotion = "",
    this.messages = const [],
    this.soundLevel = 0.0,
    this.wsConnected = false,
    this.activeVoiceTransport = VoiceTransport.idle,
    this.voiceHint = "",
  });

  TalkState copyWith({
    bool? isListening,
    bool? isThinking,
    String? statusText,
    String? liveTranscript,
    String? detectedEmotion,
    List<ChatMessage>? messages,
    double? soundLevel,
    bool? wsConnected,
    VoiceTransport? activeVoiceTransport,
    String? voiceHint,
  }) {
    return TalkState(
      isListening: isListening ?? this.isListening,
      isThinking: isThinking ?? this.isThinking,
      statusText: statusText ?? this.statusText,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      detectedEmotion: detectedEmotion ?? this.detectedEmotion,
      messages: messages ?? this.messages,
      soundLevel: soundLevel ?? this.soundLevel,
      wsConnected: wsConnected ?? this.wsConnected,
      activeVoiceTransport: activeVoiceTransport ?? this.activeVoiceTransport,
      voiceHint: voiceHint ?? this.voiceHint,
    );
  }
}

final talkProvider = NotifierProvider<TalkNotifier, TalkState>(TalkNotifier.new);

class TalkNotifier extends Notifier<TalkState> {
  stt.SpeechToText? _speech;
  FlutterTts? _tts;
  WebSocketChannel? _wsChannel;
  DateTime _sessionStart = DateTime.now();
  String _sessionId = "session_local";
  DateTime? _lastCopingPromptAt;
  String _lastCopingPromptTag = "";

  Function(Map<String, dynamic>)? onCrisisAlert;
  bool _crisisAlertActive = false;
  Function()? onThinkingStart;
  Function()? onThinkingStop;
  Function()? onListeningStart;
  Function()? onListeningStop;
  Function(String)? onSuggestWellnessActivity;
  Function()? onOfflineFallback;

  @override
  TalkState build() {
    ref.onDispose(dispose);
    Future.microtask(() async {
      _speech = stt.SpeechToText();
      _tts = FlutterTts();
      await _initTts();
      _connectWebSocket();
      _sessionStart = DateTime.now();
      _sessionId = "session_${_sessionStart.millisecondsSinceEpoch}";
      AuthService().logAnalyticsEvent('session_started', {'session_start': _sessionStart.toIso8601String()});
    });
    return const TalkState();
  }

  void dispose() {
    final duration = DateTime.now().difference(_sessionStart).inSeconds;
    AuthService().logAnalyticsEvent('session_ended', {
      'duration_seconds': duration,
      'message_count': state.messages.length,
      'session_start': _sessionStart.toIso8601String(),
    });
    _wsChannel?.sink.close();
    _tts?.stop();
  }

  Future<void> _initTts() async {
    if (_tts != null) await configureTtsVoice(_tts!);
  }

  void _connectWebSocket() {
    try {
      final wsUrl = kBackendUrl.replaceFirst('http', 'ws');
      _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/transcribe'));
      _wsChannel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['is_crisis'] == true) _handleCrisisDetection(data);
        },
        onDone: () => state = state.copyWith(wsConnected: false),
        onError: (_) => state = state.copyWith(wsConnected: false),
      );
      state = state.copyWith(wsConnected: true);
    } catch (_) {
      state = state.copyWith(wsConnected: false);
    }
  }

  bool _detectCrisisLocally(String text) {
    final lower = text.toLowerCase();
    return kCrisisKeywords.any((keyword) => lower.contains(keyword));
  }

  void _handleCrisisDetection(Map<String, dynamic> data) {
    if (_crisisAlertActive) return;
    _crisisAlertActive = true;
    onCrisisAlert?.call(data);
  }

  void resetCrisisAlert() {
    _crisisAlertActive = false;
  }

  void _sendToWebSocket(String transcript) {
    if (state.wsConnected && _wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({'transcript': transcript}));
    }
    if (_detectCrisisLocally(transcript)) {
      _handleCrisisDetection({
        'is_crisis': true,
        'message': 'I\'m really concerned about what you\'re sharing. Your life matters.',
        'helplines': {
          'India': {kPrimaryHelplineIndia.name: kPrimaryHelplineIndia.number},
          'US': {kPrimaryHelplineUs.name: kPrimaryHelplineUs.number}
        }
      });
    }
  }

  Future<void> handleMicPress() async {
    AuthService().logAnalyticsEvent('mic_press', {'is_listening': state.isListening});
    if (state.isListening) {
      _speech?.stop();
      onListeningStop?.call();
      state = state.copyWith(
        isListening: false,
        soundLevel: 0.0,
        activeVoiceTransport: VoiceTransport.idle,
      );
      return;
    }
    await _startSpeechToTextMode();
  }

  Future<void> _startSpeechToTextMode() async {
    if (_speech == null) {
      state = state.copyWith(statusText: "Mic not available — use text input below");
      return;
    }
    AuthService().logAnalyticsEvent('voice_transport', {'mode': 'turn_based_stt_tts'});

    final avail = await _speech!.initialize(onError: (val) {
      onListeningStop?.call();
      state = state.copyWith(
        isListening: false,
        soundLevel: 0.0,
        activeVoiceTransport: VoiceTransport.idle,
        statusText: val.errorMsg == "error_speech_timeout" || val.errorMsg == "error_no_match"
            ? "No speech detected. Try again."
            : "Tap to share how you feel",
      );
    });

    if (!avail) {
      state = state.copyWith(statusText: "Mic not available — use text input below");
      return;
    }

    onListeningStart?.call();
    state = state.copyWith(
      isListening: true,
      statusText: 'Listening — speak, pause, then I respond',
      liveTranscript: "",
      soundLevel: 0.0,
      activeVoiceTransport: VoiceTransport.standardFallback,
      voiceHint: 'Voice-first turn mode active.',
    );

    _speech!.listen(
      onResult: (val) {
        state = state.copyWith(liveTranscript: val.recognizedWords);
        if (val.recognizedWords.isNotEmpty) {
          _sendToWebSocket(val.recognizedWords);
        }
        if (val.finalResult && val.recognizedWords.isNotEmpty) {
          onListeningStop?.call();
          state = state.copyWith(
            isListening: false,
            soundLevel: 0.0,
            activeVoiceTransport: VoiceTransport.idle,
            voiceHint: '',
          );
          processInputWithSuggestions(val.recognizedWords);
        }
      },
      onSoundLevelChange: (level) => state = state.copyWith(soundLevel: ((level + 2) / 12).clamp(0.0, 1.0)),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: "en_US",
    );
  }

  Future<void> processInputWithSuggestions(String input) async {
    if (_detectCrisisLocally(input)) {
      _handleCrisisDetection({'is_crisis': true, 'message': 'I\'m really concerned about what you\'re sharing.'});
      return;
    }
    await processInput(input);
  }

  List<Map<String, String>> _conversationHistoryForBackend({required String currentInput}) {
    final history = <Map<String, String>>[];
    for (final msg in state.messages.take(10)) {
      if (msg.isUser) {
        history.add({'role': 'user', 'content': msg.text});
      } else {
        final parts = <String>[];
        if ((msg.validation ?? '').trim().isNotEmpty) parts.add(msg.validation!.trim());
        if ((msg.insight ?? '').trim().isNotEmpty) parts.add(msg.insight!.trim());
        if ((msg.action ?? '').trim().isNotEmpty) parts.add(msg.action!.trim());
        final assistantText = parts.isNotEmpty ? parts.join(' ') : msg.text;
        history.add({'role': 'assistant', 'content': assistantText});
      }
    }
    final shouldAppendCurrent = history.isEmpty ||
        history.last['role'] != 'user' ||
        (history.last['content'] ?? '').trim() != currentInput.trim();
    if (shouldAppendCurrent) {
      history.add({'role': 'user', 'content': currentInput});
    }
    return history;
  }

  bool _shouldOfferCopingPrompt({
    required String userInput,
    required String suggestionTag,
    required String action,
  }) {
    final input = userInput.toLowerCase();
    final actionLower = action.toLowerCase();

    // Guardrails: avoid prompting for casual social turns.
    final isCasual = input.contains('thank you') ||
        input.contains('thanks') ||
        input.contains('hello') ||
        input.contains('hi') ||
        input.contains('good morning') ||
        input.contains('good evening');
    if (isCasual) return false;

    // Situational triggers: user asks for help, reports distress, or says prior step failed.
    final needsHelp = input.contains('help') ||
        input.contains('what can i do') ||
        input.contains("what to do") ||
        input.contains("what else") ||
        input.contains("did not work") ||
        input.contains("didn't work") ||
        input.contains("not working") ||
        input.contains("still feel") ||
        input.contains("not feeling") ||
        input.contains("don't feel") ||
        input.contains("feel bad") ||
        input.contains("feel terrible") ||
        input.contains("feeling bad") ||
        input.contains("feeling terrible") ||
        input.contains('anxious') ||
        input.contains('stressed') ||
        input.contains('overwhelmed') ||
        input.contains('panic') ||
        input.contains('sad') ||
        input.contains('angry') ||
        input.contains('can\'t sleep') ||
        input.contains('sleepless');

    // Action must be clearly actionable and coping-oriented.
    final actionable = actionLower.contains('try ') ||
        actionLower.contains('practice') ||
        actionLower.contains('do this') ||
        actionLower.contains('take ');
    if (!(needsHelp && actionable)) return false;

    // Cooldown + dedupe: keep prompts situational, not repetitive.
    final now = DateTime.now();
    if (_lastCopingPromptAt != null &&
        now.difference(_lastCopingPromptAt!).inSeconds < 75 &&
        _lastCopingPromptTag == suggestionTag) {
      return false;
    }

    _lastCopingPromptAt = now;
    _lastCopingPromptTag = suggestionTag;
    return true;
  }

  void _maybeSuggestCopingFromAction({
    required String userInput,
    required String action,
    required String fallbackEmotion,
  }) {
    final text = action.toLowerCase();
    if (text.contains('breath') || text.contains('box breathing') || text.contains('4-7-8')) {
      const tag = "ACTION:breathing";
      if (_shouldOfferCopingPrompt(userInput: userInput, suggestionTag: tag, action: action)) {
        onSuggestWellnessActivity?.call("$tag:$action");
      }
      return;
    }
    if (text.contains('ground') || text.contains('5-4-3-2-1')) {
      const tag = "ACTION:grounding";
      if (_shouldOfferCopingPrompt(userInput: userInput, suggestionTag: tag, action: action)) {
        onSuggestWellnessActivity?.call("$tag:$action");
      }
      return;
    }
    if (text.contains('muscle') || text.contains('relax')) {
      const tag = "ACTION:somatic";
      if (_shouldOfferCopingPrompt(userInput: userInput, suggestionTag: tag, action: action)) {
        onSuggestWellnessActivity?.call("$tag:$action");
      }
      return;
    }
    if (fallbackEmotion.isNotEmpty &&
        _shouldOfferCopingPrompt(
          userInput: userInput,
          suggestionTag: "EMOTION:$fallbackEmotion",
          action: action,
        )) {
      onSuggestWellnessActivity?.call("EMOTION:$fallbackEmotion");
    }
  }

  Future<void> processInput(String input) async {
    if (_detectCrisisLocally(input)) {
      _handleCrisisDetection({'is_crisis': true, 'message': 'I\'m really concerned about what you\'re sharing.'});
      return;
    }

    final emotion = OfflineEngine.detectEmotion(input);
    onThinkingStart?.call();
    state = state.copyWith(
      isThinking: true,
      statusText: "Thinking...",
      detectedEmotion: emotion,
      messages: [...state.messages, ChatMessage(text: input, isUser: true, emotion: emotion)],
    );

    try {
      final url = Uri.parse('$kBackendUrl/chat');
      final profile = UserProfile();
      final token = await AuthService().getIdToken();
      final headers = {'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.post(url, headers: headers, body: jsonEncode({
        'transcript': input,
        'session_id': _sessionId,
        'conversation_history': _conversationHistoryForBackend(currentInput: input),
        'profile': profile.isProfileComplete
            ? {
                'name': profile.name,
                'age_group': profile.ageGroup,
                'concerns': profile.concerns,
                'coping_strategies_worked': profile.copingStrategiesWorked,
                'coping_strategies_failed': profile.copingStrategiesFailed,
                'additional_notes': profile.additionalNotes
              }
            : null,
      })).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) throw Exception("Server error");

      final data = jsonDecode(response.body);
      if (data['is_crisis'] == true) {
        onThinkingStop?.call();
        state = state.copyWith(isThinking: false, statusText: "Tap to share how you feel");
        _handleCrisisDetection(data);
        return;
      }

      final emotionAnalysis = data['emotion_analysis'] as Map<String, dynamic>?;
      final emotionTrend = data['emotion_trend'] as Map<String, dynamic>?;
      final trajectory = (emotionTrend?['trajectory'] as List<dynamic>?)?.cast<String>();
      _addAiMessage(
        data['validation'] ?? "I hear you.",
        data['insight'] ?? "",
        data['action'] ?? "Take 3 deep breaths.",
        emotion,
        false,
        emotionAnalysis: emotionAnalysis,
        emotionTrajectory: trajectory,
      );
      _maybeSuggestCopingFromAction(
        userInput: input,
        action: (data['action'] as String?) ?? "",
        fallbackEmotion: emotion,
      );
    } catch (_) {
      onOfflineFallback?.call();
      final offline = OfflineEngine.respond(input);
      _addAiMessage(
        offline['validation']!,
        offline['insight']!,
        offline['action']!,
        offline['emotion'] ?? emotion,
        true,
      );
      _maybeSuggestCopingFromAction(
        userInput: input,
        action: offline['action'] ?? "",
        fallbackEmotion: offline['emotion'] ?? emotion,
      );
    }
  }

  void _addAiMessage(
    String validation,
    String insight,
    String action,
    String emotion,
    bool isOffline, {
    Map<String, dynamic>? emotionAnalysis,
    List<String>? emotionTrajectory,
  }) {
    onThinkingStop?.call();
    state = state.copyWith(
      isThinking: false,
      statusText: "Here's something that might help",
      messages: [
        ...state.messages,
        ChatMessage(
          text: validation,
          isUser: false,
          emotion: emotion,
          validation: validation,
          insight: insight,
          action: action,
          isOffline: isOffline,
          emotionAnalysis: emotionAnalysis,
          emotionTrajectory: emotionTrajectory,
        ),
      ],
    );
    _tts?.speak("$validation $insight $action");
  }

  Future<void> sendFeedback(ChatMessage msg, String feedback) async {
    final profile = UserProfile();
    final token = await AuthService().getIdToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    try {
      await http.post(Uri.parse('$kBackendUrl/feedback'), headers: headers, body: jsonEncode({
        'transcript': '',
        'advice_given': msg.validation,
        'strategy_given': msg.action,
        'feedback': feedback,
        'profile': profile.isProfileComplete
            ? {
                'name': profile.name,
                'age_group': profile.ageGroup,
                'concerns': profile.concerns,
                'coping_strategies_worked': profile.copingStrategiesWorked,
                'coping_strategies_failed': profile.copingStrategiesFailed,
                'additional_notes': profile.additionalNotes
              }
            : null,
      }));
    } catch (_) {}
    if (feedback == "Worked" && msg.action != null) await profile.addWorkedStrategy(msg.action!);
    if (feedback == "Failed" && msg.action != null) await profile.addFailedStrategy(msg.action!);
  }
}
