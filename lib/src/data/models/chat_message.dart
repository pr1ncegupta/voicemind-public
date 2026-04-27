// =====================================================================
//  CONVERSATION HISTORY MODEL
// =====================================================================
class ChatMessage {
  final String text;
  final bool isUser;
  final String? emotion;
  final String? validation;
  final String? insight;
  final String? action;
  final bool isOffline;
  final DateTime timestamp;
  final Map<String, dynamic>? emotionAnalysis;
  final List<String>? emotionTrajectory;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.emotion,
    this.validation,
    this.insight,
    this.action,
    this.isOffline = false,
    this.emotionAnalysis,
    this.emotionTrajectory,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get acousticScore => (emotionAnalysis?['acoustic_score'] as num?)?.toDouble() ?? 0.0;
  double get textScore => (emotionAnalysis?['text_score'] as num?)?.toDouble() ?? 0.0;
  double get confidence => (emotionAnalysis?['confidence'] as num?)?.toDouble() ?? 0.0;
  String get detectedEmotion => emotionAnalysis?['detected_emotion'] as String? ?? emotion ?? '';
  bool get hasAnalysis => emotionAnalysis != null && emotionAnalysis!.isNotEmpty;
}
