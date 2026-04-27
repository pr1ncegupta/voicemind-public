import 'dart:math' as math;
import '../common/constants.dart';

// =====================================================================
//  OFFLINE RESPONSE ENGINE
//  Keyword-matched coping when backend is unreachable.
// =====================================================================
class OfflineEngine {
  static final _rng = math.Random();

  // Each entry: keywords → {validation, insight, action}
  static const List<Map<String, dynamic>> _bank = [
    {
      "keywords": ["anxious", "anxiety", "nervous", "worried", "panic", "fear", "scared", "frightened", "tense", "uneasy"],
      "responses": [
        {"validation": "It's okay to feel anxious — your body is trying to protect you.", "insight": "Anxiety often lives in the future. Grounding brings you back to now.", "action": "Try the 5-4-3-2-1 technique: name 5 things you see, 4 you can touch, 3 you hear, 2 you smell, 1 you taste."},
        {"validation": "Anxiety can feel overwhelming, but it always passes.", "insight": "Your nervous system is in fight-or-flight mode. Slow breathing resets it.", "action": "Try Box Breathing: breathe in 4 counts, hold 4, out 4, hold 4. Repeat 4 cycles."},
        {"validation": "You're not weak for feeling anxious — it takes courage to acknowledge it.", "insight": "Naming the emotion reduces its power. You just did that.", "action": "Place both feet flat on the floor. Press down. Feel the ground holding you. You are safe right now."},
      ]
    },
    {
      "keywords": ["sad", "unhappy", "down", "depressed", "hopeless", "empty", "miserable", "heartbroken", "grief", "loss", "crying", "cry", "tears"],
      "responses": [
        {"validation": "Sadness is a natural response — it means something matters to you.", "insight": "Allowing yourself to feel sad is healthier than pushing it away.", "action": "Place a hand on your heart. Say: 'This is hard, and I'm allowed to feel this way.' Take 5 slow breaths."},
        {"validation": "It's okay to not be okay right now.", "insight": "Sadness often carries a message about what we need — rest, connection, or kindness.", "action": "Do one small act of self-care: drink warm water, wrap yourself in a blanket, or step outside for fresh air."},
        {"validation": "Your pain is real and your feelings are valid.", "insight": "Even in darkness, you reached out — that's strength.", "action": "Write down one thing you're grateful for, no matter how small. Gratitude and sadness can coexist."},
      ]
    },
    {
      "keywords": ["stressed", "stress", "pressure", "overwhelmed", "overloaded", "burnout", "burned out", "exhausted", "too much"],
      "responses": [
        {"validation": "Stress means you care — but you don't have to carry it all at once.", "insight": "The brain can only handle one task at a time. Narrowing focus helps.", "action": "Ask yourself: 'What is the ONE smallest thing I can do right now?' Do just that one thing."},
        {"validation": "Feeling overwhelmed doesn't mean you're failing — it means you're human.", "insight": "Physical tension mirrors mental stress. Releasing one eases the other.", "action": "Progressive Muscle Relaxation: tense your shoulders to your ears for 5 seconds, then drop them completely. Repeat 3 times."},
        {"validation": "It's okay to pause. Rest is productive too.", "insight": "Your body is sending signals that it needs a break.", "action": "Do a 3-minute brain dump: write everything on your mind without editing. Close it when done. The thoughts are captured and out of your head."},
      ]
    },
    {
      "keywords": ["sleep", "insomnia", "awake", "can't sleep", "restless", "tired", "fatigue", "sleepless", "nighttime", "bed"],
      "responses": [
        {"validation": "Sleep struggles are frustrating — you're not alone in this.", "insight": "Fighting sleeplessness creates more stress. Gentle acceptance helps more.", "action": "Try 4-7-8 breathing: inhale for 4 counts, hold for 7, exhale for 8. Repeat 4 cycles. Don't force sleep — just breathe."},
        {"validation": "Your mind is busy, and that's okay. Let's help it wind down.", "insight": "Racing thoughts at night often mean unprocessed emotions from the day.", "action": "Body Scan: starting from your forehead, slowly relax each muscle group down to your toes. Breathe into any tight spots."},
        {"validation": "Not sleeping well doesn't make tomorrow hopeless — your body is resilient.", "insight": "Blue light and screens stimulate your brain. A gentle wind-down routine helps.", "action": "Try the Thought Parking technique: imagine each worry as a car. Park each one in a mental parking lot. Tell them: 'I'll deal with you tomorrow.'"},
      ]
    },
    {
      "keywords": ["angry", "anger", "frustrated", "furious", "irritated", "annoyed", "rage", "mad", "upset"],
      "responses": [
        {"validation": "Anger is a valid emotion — it often signals a boundary has been crossed.", "insight": "Anger isn't the problem; how we express it matters.", "action": "Try the STOP technique: Stop what you're doing. Take 3 deep breaths. Observe what you're feeling. Proceed with intention."},
        {"validation": "It makes sense that you feel angry given what you're dealing with.", "insight": "Anger often masks hurt, fear, or frustration underneath.", "action": "Squeeze your fists tightly for 5 seconds, then release completely. Feel the tension leave. Repeat until the intensity drops."},
      ]
    },
    {
      "keywords": ["lonely", "alone", "isolated", "no friends", "nobody", "disconnected"],
      "responses": [
        {"validation": "Loneliness is painful — wanting connection is deeply human.", "insight": "Feeling lonely doesn't mean you're unlovable. It means you have a need for connection.", "action": "Send one message to someone — a simple 'thinking of you' or 'how are you?' Connection starts with one small step."},
        {"validation": "You're reaching out right now, and that matters. You're not as alone as it feels.", "insight": "Our brains exaggerate isolation when we're low. Reality is usually warmer.", "action": "List 3 people who have shown you kindness — even small gestures count. You are remembered."},
      ]
    },
    {
      "keywords": ["worthless", "useless", "failure", "not good enough", "hate myself", "self-esteem", "ugly", "stupid", "loser"],
      "responses": [
        {"validation": "Those thoughts feel real, but they are thoughts, not facts.", "insight": "We are our own harshest critics. Would you say this to a friend? Probably not.", "action": "CBT Reframe: Write the negative thought. Then ask: 'What evidence do I have against this?' Write a balanced alternative."},
        {"validation": "You are more than your worst thoughts about yourself.", "insight": "Low self-worth often comes from old stories we internalized. They can be rewritten.", "action": "Say out loud: 'I am doing my best, and that is enough.' Repeat it 3 times. Let the words land."},
      ]
    },
    {
      "keywords": ["help", "need help", "support", "talk", "listen", "someone", "vent"],
      "responses": [
        {"validation": "Reaching out for help is one of the bravest things you can do.", "insight": "You don't have to have it all figured out. Asking for help is a sign of strength.", "action": "Take 3 deep breaths right now. Then share what's on your mind — I'm here to listen."},
      ]
    },
    {
      "keywords": ["relationship", "breakup", "partner", "boyfriend", "girlfriend", "spouse", "husband", "wife", "dating", "love"],
      "responses": [
        {"validation": "Relationship pain cuts deep — your feelings are completely valid.", "insight": "Heartbreak activates the same brain regions as physical pain. What you feel is real.", "action": "Write an unsent letter expressing everything you feel. Don't send it — just let the emotions flow onto paper."},
      ]
    },
    {
      "keywords": ["work", "job", "boss", "career", "office", "colleague", "coworker", "meeting", "deadline"],
      "responses": [
        {"validation": "Work stress is real and your feelings about it matter.", "insight": "Burnout happens when demands exceed resources. It's not a personal failing.", "action": "Set one boundary today: leave on time, take a full lunch break, or say 'I'll get back to you on that' instead of an immediate yes."},
      ]
    },
  ];

  /// Given a user transcript, find the best matching category and return a
  /// random response from it.  Falls back to a generic response.
  static Map<String, String> respond(String transcript) {
    final lower = transcript.toLowerCase();
    int bestScore = 0;
    List<Map<String, String>>? bestResponses;
    String detectedEmotion = "general";

    for (final entry in _bank) {
      final keywords = entry['keywords'] as List;
      int score = 0;
      for (final kw in keywords) {
        if (lower.contains(kw as String)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestResponses = (entry['responses'] as List).cast<Map<String, String>>();
        detectedEmotion = (keywords.first as String);
      }
    }

    if (bestResponses != null && bestScore > 0) {
      final chosen = bestResponses[_rng.nextInt(bestResponses.length)];
      return {
        ...chosen,
        "emotion": detectedEmotion,
      };
    }

    // Generic fallback
    return {
      "validation": "I hear you, and your feelings are valid.",
      "insight": "Sometimes just pausing to notice how we feel is the first step toward healing.",
      "action": "Try 3 deep breaths right now: breathe in for 4, hold for 4, exhale for 6. Let your shoulders drop.",
      "emotion": "general",
    };
  }

  /// Detect primary emotion keyword from transcript for the emotion indicator.
  static String detectEmotion(String transcript) {
    final lower = transcript.toLowerCase();
    final emotionMap = {
      "anxious": ["anxious", "anxiety", "nervous", "panic", "worried", "fear"],
      "sad": ["sad", "depressed", "unhappy", "hopeless", "crying", "grief"],
      "stressed": ["stressed", "overwhelmed", "pressure", "burnout", "exhausted"],
      "angry": ["angry", "furious", "frustrated", "annoyed", "rage", "mad"],
      "lonely": ["lonely", "alone", "isolated", "disconnected"],
      "sleepless": ["sleep", "insomnia", "tired", "awake", "restless"],
      "low self-worth": ["worthless", "useless", "failure", "hate myself", "not good enough"],
    };

    for (final entry in emotionMap.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) return entry.key;
      }
    }
    return "reflective";
  }
}

// Global test-accessible wrappers
String detectEmotionGlobal(String text) => OfflineEngine.detectEmotion(text);

double calculateSusScoreGlobal(List<int> responses) {
  if (responses.length != 10) {
    throw ArgumentError('SUS requires exactly 10 responses, got ${responses.length}');
  }
  double total = 0;
  for (int i = 0; i < 10; i++) {
    total += (i.isEven) ? (responses[i] - 1) : (5 - responses[i]);
  }
  return total * 2.5;
}

bool checkCrisisGlobal(String text) {
  final lower = text.toLowerCase();
  return kCrisisKeywords.any((keyword) => lower.contains(keyword));
}
