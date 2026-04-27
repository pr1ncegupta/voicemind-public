// =============================================================================
//  VoiceMind — COMPREHENSIVE UNIT TESTS
//  Run: flutter test test/engines_test.dart -v
//
//  Tests the core logic engines WITHOUT a device:
//   - OfflineEngine (response generation + emotion detection)
//   - Crisis detection (checkCrisisGlobal)
//   - SUS score calculation
//   - Data integrity (kCopingTools, kWellnessActivities)
//   - UserProfile singleton behavior
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:voicemind_flutter/src/data/models/tools_data.dart';
import 'package:voicemind_flutter/src/data/models/chat_message.dart';
import 'package:voicemind_flutter/src/services/offline_engine.dart';


void main() {
  // ===========================================================================
  // 1. OFFLINE ENGINE — Response Generation
  // ===========================================================================
  group('OfflineEngine.respond()', () {
    test('Anxious input → returns valid 3-key response', () {
      final r = OfflineEngine.respond('I feel so anxious and nervous');
      expect(r, containsPair('validation', isNotEmpty));
      expect(r, containsPair('insight', isNotEmpty));
      expect(r, containsPair('action', isNotEmpty));
      expect(r['emotion'], equals('anxious'));
    });

    test('Sad input → returns valid 3-key response', () {
      final r = OfflineEngine.respond('I am very sad and depressed today');
      expect(r.containsKey('validation'), isTrue);
      expect(r.containsKey('insight'), isTrue);
      expect(r.containsKey('action'), isTrue);
    });

    test('Stressed input → returns valid 3-key response', () {
      final r = OfflineEngine.respond('I feel overwhelmed and stressed');
      expect(r.containsKey('validation'), isTrue);
      expect(r['validation'], isNotEmpty);
    });

    test('Sleep input → returns valid response', () {
      final r = OfflineEngine.respond('I cannot sleep at night, insomnia is terrible');
      expect(r.containsKey('validation'), isTrue);
      expect(r.containsKey('action'), isTrue);
    });

    test('Angry input → returns valid response', () {
      final r = OfflineEngine.respond('I am so angry and frustrated');
      expect(r.containsKey('validation'), isTrue);
      expect(r.containsKey('action'), isTrue);
    });

    test('Lonely input → returns valid response', () {
      final r = OfflineEngine.respond('I feel so lonely and isolated, nobody talks to me');
      expect(r.containsKey('validation'), isTrue);
    });

    test('Low self-worth input → returns valid response', () {
      final r = OfflineEngine.respond('I feel worthless and like a failure');
      expect(r.containsKey('validation'), isTrue);
    });

    test('Help seeking input → returns valid response', () {
      final r = OfflineEngine.respond('I need help, I want to talk to someone');
      expect(r.containsKey('validation'), isTrue);
    });

    test('Relationship input → returns valid response', () {
      final r = OfflineEngine.respond('My partner broke up with me, I am heartbroken');
      expect(r.containsKey('validation'), isTrue);
    });

    test('Work stress input → returns valid response', () {
      final r = OfflineEngine.respond('My job is killing me, boss is terrible');
      expect(r.containsKey('validation'), isTrue);
    });

    test('Generic fallback for unrecognized input', () {
      final r = OfflineEngine.respond('hello world random text');
      expect(r.containsKey('validation'), isTrue);
      expect(r.containsKey('insight'), isTrue);
      expect(r.containsKey('action'), isTrue);
      expect(r['emotion'], equals('general'));
    });

    test('Empty string returns generic fallback', () {
      final r = OfflineEngine.respond('');
      expect(r.containsKey('validation'), isTrue);
      expect(r['emotion'], equals('general'));
    });

    test('Multiple keyword matches → picks best category', () {
      final r = OfflineEngine.respond('I am anxious nervous scared worried about everything');
      // Multiple anxiety keywords → should strongly match anxiety
      expect(r.containsKey('validation'), isTrue);
    });

    test('Response values are non-empty strings', () {
      final r = OfflineEngine.respond('I feel really stressed today');
      expect(r['validation'], isA<String>());
      expect(r['insight'], isA<String>());
      expect(r['action'], isA<String>());
      expect(r['validation']!.length, greaterThan(10));
      expect(r['insight']!.length, greaterThan(10));
      expect(r['action']!.length, greaterThan(10));
    });
  });

  // ===========================================================================
  // 2. OFFLINE ENGINE — Emotion Detection
  // ===========================================================================
  group('OfflineEngine.detectEmotion()', () {
    test('Detects anxious', () {
      expect(OfflineEngine.detectEmotion('I am so anxious'), 'anxious');
      expect(OfflineEngine.detectEmotion('My anxiety is killing me'), 'anxious');
      expect(OfflineEngine.detectEmotion('I feel panicked'), 'anxious');
    });

    test('Detects sad', () {
      expect(OfflineEngine.detectEmotion('I feel so sad today'), 'sad');
      expect(OfflineEngine.detectEmotion('I am depressed and hopeless'), 'sad');
      expect(OfflineEngine.detectEmotion('I keep crying'), 'sad');
    });

    test('Detects stressed', () {
      expect(OfflineEngine.detectEmotion('I am so stressed'), 'stressed');
      expect(OfflineEngine.detectEmotion('I feel overwhelmed'), 'stressed');
      expect(OfflineEngine.detectEmotion('Burnout is real'), 'stressed');
    });

    test('Detects angry', () {
      expect(OfflineEngine.detectEmotion('I am so angry'), 'angry');
      expect(OfflineEngine.detectEmotion('I am furious and frustrated'), 'angry');
      expect(OfflineEngine.detectEmotion('This makes me so mad'), 'angry');
    });

    test('Detects lonely', () {
      expect(OfflineEngine.detectEmotion('I feel so lonely'), 'lonely');
      expect(OfflineEngine.detectEmotion('I am alone and isolated'), 'lonely');
    });

    test('Detects sleepless', () {
      expect(OfflineEngine.detectEmotion('I cannot sleep'), 'sleepless');
      expect(OfflineEngine.detectEmotion('Insomnia is terrible'), 'sleepless');
      expect(OfflineEngine.detectEmotion('I am so tired and restless'), 'sleepless');
    });

    test('Detects low self-worth', () {
      expect(OfflineEngine.detectEmotion('I feel worthless'), 'low self-worth');
      expect(OfflineEngine.detectEmotion('I hate myself'), 'low self-worth');
      expect(OfflineEngine.detectEmotion('I am such a failure'), 'low self-worth');
    });

    test('Fallback to reflective for neutral text', () {
      expect(OfflineEngine.detectEmotion('The sky is blue today'), 'reflective');
      expect(OfflineEngine.detectEmotion('Hello there'), 'reflective');
      expect(OfflineEngine.detectEmotion('Just having a normal day'), 'reflective');
    });

    test('Case insensitive detection', () {
      expect(OfflineEngine.detectEmotion('I AM SO ANXIOUS'), 'anxious');
      expect(OfflineEngine.detectEmotion('I Feel Really SAD'), 'sad');
    });
  });

  // ===========================================================================
  // 3. CRISIS DETECTION — checkCrisisGlobal
  // ===========================================================================
  group('checkCrisisGlobal()', () {
    test('Detects "kill myself"', () {
      expect(checkCrisisGlobal('I want to kill myself'), true);
    });

    test('Detects "end my life"', () {
      expect(checkCrisisGlobal('I want to end my life'), true);
    });

    test('Detects "commit suicide"', () {
      expect(checkCrisisGlobal('I want to commit suicide'), true);
    });

    test('Detects "overdose"', () {
      expect(checkCrisisGlobal('I am going to overdose on my pills'), true);
    });

    test('Detects "hang myself"', () {
      expect(checkCrisisGlobal('I want to hang myself'), true);
    });

    test('Detects "jump off"', () {
      expect(checkCrisisGlobal('I want to jump off a building'), true);
    });

    test('Detects "want to die"', () {
      expect(checkCrisisGlobal('I want to die'), true);
    });

    test('Detects "no reason to live"', () {
      expect(checkCrisisGlobal('I have no reason to live'), true);
    });

    test('Detects "hurt myself"', () {
      expect(checkCrisisGlobal('I want to hurt myself'), true);
    });

    test('Detects "cut myself"', () {
      expect(checkCrisisGlobal('I want to cut myself'), true);
    });

    test('Detects "self harm"', () {
      expect(checkCrisisGlobal('I engage in self harm'), true);
    });

    test('Detects "better off dead"', () {
      expect(checkCrisisGlobal('Everyone is better off dead without me'), true);
    });

    test('Detects "wish i was dead"', () {
      expect(checkCrisisGlobal('I wish I was dead'), true);
    });

    test('Detects "nothing to live for"', () {
      expect(checkCrisisGlobal('There is nothing to live for'), true);
    });

    test('Detects "don\'t want to be alive"', () {
      expect(checkCrisisGlobal("I don't want to be alive anymore"), true);
    });

    test('Case insensitive', () {
      expect(checkCrisisGlobal('I WANT TO KILL MYSELF'), true);
      expect(checkCrisisGlobal('I Want To End My Life'), true);
    });

    // ── SAFE PHRASES (must NOT trigger crisis) ──
    test('Safe: "I need help with my exam"', () {
      expect(checkCrisisGlobal('I need help with my exam'), false);
    });

    test('Safe: "I am really sad"', () {
      expect(checkCrisisGlobal('I am really sad today'), false);
    });

    test('Safe: "tough day at work"', () {
      expect(checkCrisisGlobal('I had a tough day at work'), false);
    });

    test('Safe: "stressed about deadline"', () {
      expect(checkCrisisGlobal('I am stressed about my deadline'), false);
    });

    test('Safe: "killing it at the presentation"', () {
      // Note: 'killing' alone is not a crisis keyword — only 'kill myself' / 'kill me' are
      expect(checkCrisisGlobal('I was killing it at the presentation'), false);
    });

    test('Safe: "I feel lonely"', () {
      expect(checkCrisisGlobal('I feel lonely sometimes'), false);
    });

    test('Safe: empty string', () {
      expect(checkCrisisGlobal(''), false);
    });
  });

  // ===========================================================================
  // 4. SUS SCORE CALCULATION
  // ===========================================================================
  group('calculateSusScoreGlobal()', () {
    test('Perfect score = 100.0', () {
      final score = calculateSusScoreGlobal([5, 1, 5, 1, 5, 1, 5, 1, 5, 1]);
      expect(score, equals(100.0));
    });

    test('Worst score = 0.0', () {
      final score = calculateSusScoreGlobal([1, 5, 1, 5, 1, 5, 1, 5, 1, 5]);
      expect(score, equals(0.0));
    });

    test('Neutral score = 50.0', () {
      final score = calculateSusScoreGlobal([3, 3, 3, 3, 3, 3, 3, 3, 3, 3]);
      expect(score, equals(50.0));
    });

    test('Realistic good score > 70', () {
      final score = calculateSusScoreGlobal([4, 2, 4, 2, 5, 1, 4, 2, 4, 1]);
      expect(score, greaterThan(70.0));
    });

    test('Realistic poor score < 30', () {
      final score = calculateSusScoreGlobal([2, 4, 2, 4, 2, 4, 2, 4, 2, 4]);
      expect(score, lessThan(30.0));
    });

    test('Score is always between 0 and 100', () {
      for (int a = 1; a <= 5; a++) {
        final scores = List.filled(10, a);
        final result = calculateSusScoreGlobal(scores);
        expect(result, greaterThanOrEqualTo(0.0));
        expect(result, lessThanOrEqualTo(100.0));
      }
    });

    test('Wrong count throws ArgumentError', () {
      expect(() => calculateSusScoreGlobal([5, 1, 5]), throwsA(isA<ArgumentError>()));
      expect(() => calculateSusScoreGlobal([]), throwsA(isA<ArgumentError>()));
      expect(() => calculateSusScoreGlobal(List.filled(11, 3)), throwsA(isA<ArgumentError>()));
    });
  });

  // ===========================================================================
  // 5. DATA INTEGRITY — Coping Tools
  // ===========================================================================
  group('kCopingTools data integrity', () {
    test('Has exactly 20 tools', () {
      expect(kCopingTools.length, equals(20));
    });

    test('Every tool has required fields', () {
      for (final tool in kCopingTools) {
        expect(tool, contains('title'));
        expect(tool, contains('category'));
        expect(tool, contains('desc'));
        expect(tool, contains('steps'));
        expect(tool, contains('icon'));
        expect(tool, contains('color'));
      }
    });

    test('Every tool has at least 5 steps', () {
      for (final tool in kCopingTools) {
        final steps = tool['steps'] as List;
        expect(steps.length, greaterThanOrEqualTo(5),
            reason: '${tool['title']} has only ${steps.length} steps');
      }
    });

    test('All categories are valid', () {
      final validCategories = {'Breathing', 'Grounding', 'Somatic', 'CBT', 'Mindfulness', 'Self-Compassion'};
      for (final tool in kCopingTools) {
        expect(validCategories, contains(tool['category']),
            reason: '${tool['title']} has invalid category: ${tool['category']}');
      }
    });

    test('Breathing tools have patterns', () {
      final breathing = kCopingTools.where((t) => t['category'] == 'Breathing');
      expect(breathing.length, equals(3));
      for (final tool in breathing) {
        expect(tool, contains('pattern'));
        expect(tool, contains('patternLabels'));
        final pattern = tool['pattern'] as List;
        final labels = tool['patternLabels'] as List;
        expect(pattern.length, equals(labels.length));
      }
    });

    test('No duplicate tool titles', () {
      final titles = kCopingTools.map((t) => t['title']).toSet();
      expect(titles.length, equals(kCopingTools.length));
    });
  });

  // ===========================================================================
  // 6. DATA INTEGRITY — Wellness Activities
  // ===========================================================================
  group('kWellnessActivities data integrity', () {
    test('Has exactly 18 activities', () {
      expect(kWellnessActivities.length, equals(18));
    });

    test('Every activity has required fields', () {
      for (final act in kWellnessActivities) {
        expect(act, contains('title'));
        expect(act, contains('category'));
        expect(act, contains('desc'));
        expect(act, contains('steps'));
        expect(act, contains('icon'));
        expect(act, contains('color'));
      }
    });

    test('Every activity has at least 5 steps', () {
      for (final act in kWellnessActivities) {
        final steps = act['steps'] as List;
        expect(steps.length, greaterThanOrEqualTo(5),
            reason: '${act['title']} has only ${steps.length} steps');
      }
    });

    test('All categories are valid', () {
      final valid = {'Meditation', 'Movement', 'Journaling', 'Nature', 'Creative', 'Self-Care', 'Social'};
      for (final act in kWellnessActivities) {
        expect(valid, contains(act['category']),
            reason: '${act['title']} has invalid category: ${act['category']}');
      }
    });

    test('No duplicate activity titles', () {
      final titles = kWellnessActivities.map((t) => t['title']).toSet();
      expect(titles.length, equals(kWellnessActivities.length));
    });
  });

  // ===========================================================================
  // 7. CHATMESSAGE MODEL
  // ===========================================================================
  group('ChatMessage model', () {
    test('User message creation', () {
      final msg = ChatMessage(text: 'Hello', isUser: true);
      expect(msg.text, 'Hello');
      expect(msg.isUser, true);
      expect(msg.isOffline, false); // default
      expect(msg.timestamp, isNotNull);
    });

    test('AI message with all fields', () {
      final msg = ChatMessage(
        text: 'AI response',
        isUser: false,
        validation: 'I hear you',
        insight: 'Consider this',
        action: 'Try breathing',
        emotion: 'anxious',
        isOffline: true,
      );
      expect(msg.validation, 'I hear you');
      expect(msg.insight, 'Consider this');
      expect(msg.action, 'Try breathing');
      expect(msg.emotion, 'anxious');
      expect(msg.isOffline, true);
    });

    test('Timestamp defaults to now', () {
      final before = DateTime.now();
      final msg = ChatMessage(text: 'test', isUser: true);
      final after = DateTime.now();
      expect(msg.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(msg.timestamp.isBefore(after.add(const Duration(seconds: 1))), true);
    });

    test('Nullable fields default to null', () {
      final msg = ChatMessage(text: 'test', isUser: true);
      expect(msg.emotion, isNull);
      expect(msg.validation, isNull);
      expect(msg.insight, isNull);
      expect(msg.action, isNull);
    });
  });

  // ===========================================================================
  // 8. EDGE CASES
  // ===========================================================================
  group('Edge Cases', () {
    test('OfflineEngine handles very long input', () {
      final longInput = 'I am stressed ' * 100;
      final r = OfflineEngine.respond(longInput);
      expect(r.containsKey('validation'), isTrue);
    });

    test('OfflineEngine handles special characters', () {
      final r = OfflineEngine.respond('I\'m feeling anxious 😢 & scared!!! @#\$%');
      expect(r.containsKey('validation'), isTrue);
    });

    test('OfflineEngine.detectEmotion handles empty string', () {
      final r = OfflineEngine.detectEmotion('');
      expect(r, equals('reflective'));
    });

    test('checkCrisisGlobal handles special characters', () {
      expect(checkCrisisGlobal('I want to kill myself!!!'), true);
      expect(checkCrisisGlobal('kill myself...'), true);
    });

    test('OfflineEngine.respond includes correct emotion field per category', () {
      // respond() uses the first keyword in each bank entry as the emotion
      final cases = {
        'I feel anxious': 'anxious',
        'I feel sad': 'sad',
        'I am stressed': 'stressed',
        'I am angry': 'angry',
        'I feel lonely': 'lonely',
        'I cannot sleep': 'sleep',
        'I feel worthless': 'worthless',
        'hello world': 'general',
      };
      for (final entry in cases.entries) {
        final r = OfflineEngine.respond(entry.key);
        expect(r['emotion'], equals(entry.value),
            reason: '"${entry.key}" should map to ${entry.value}');
      }
    });
  });
}
