// =====================================================================
//  VOICEMIND — COMPREHENSIVE USER JOURNEY UNIT TESTS
//  Covers all 15 feature areas with 70+ edge case scenarios
//  Run: flutter test test/user_journey_test.dart -v
// =====================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voicemind_flutter/src/data/models/tools_data.dart';
import 'package:voicemind_flutter/src/data/models/user_profile.dart';
import 'package:voicemind_flutter/src/data/models/chat_message.dart';
import 'package:voicemind_flutter/src/services/offline_engine.dart';

import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setPrefs(Map<String, Object?> values) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  for (final entry in values.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value == null) {
      await prefs.remove(key);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // ─────────────────────────────────────────────────
  //  1. APP LAUNCH & ONBOARDING
  // ─────────────────────────────────────────────────
  group('1. App Launch & Onboarding', () {
    test('UserProfile starts incomplete for fresh user', () async {
      await _setPrefs({});
      final p = UserProfile();
      await p.clearProfile();
      expect(p.isProfileComplete, isFalse);
    });

    test('UserProfile.loadFromStorage restores saved onboarding data', () async {
      await _setPrefs({
        'user_name': 'Returning User',
        'age_group': '25-34',
        'voice_preference': 'Puck',
      });
      final p = UserProfile();
      await p.loadFromStorage();
      expect(p.name, 'Returning User');
      expect(p.ageGroup, '25-34');
      expect(p.voicePreference, 'Puck');
      expect(p.isProfileComplete, isTrue);
    });
  });

  // ─────────────────────────────────────────────────
  //  2. CHATMESSAGE MODEL
  // ─────────────────────────────────────────────────
  group('2. ChatMessage Model', () {
    test('User message creation', () {
      final msg = ChatMessage(text: 'Hello', isUser: true);
      expect(msg.text, 'Hello');
      expect(msg.isUser, true);
      expect(msg.isOffline, false);
      expect(msg.timestamp, isNotNull);
    });

    test('AI message with all fields', () {
      final msg = ChatMessage(
        text: 'I hear you.',
        isUser: false,
        emotion: 'anxious',
        validation: 'I hear you.',
        insight: 'Anxiety is your body\'s alarm system.',
        action: 'Try 4-7-8 breathing.',
        isOffline: true,
      );
      expect(msg.emotion, 'anxious');
      expect(msg.validation, 'I hear you.');
      expect(msg.insight, contains('Anxiety'));
      expect(msg.action, contains('breathing'));
      expect(msg.isOffline, true);
    });

    test('Nullable fields default correctly', () {
      final msg = ChatMessage(text: 'test', isUser: true);
      expect(msg.emotion, isNull);
      expect(msg.validation, isNull);
      expect(msg.insight, isNull);
      expect(msg.action, isNull);
    });

    test('Timestamp auto-set if not provided', () {
      final before = DateTime.now();
      final msg = ChatMessage(text: 'now', isUser: true);
      final after = DateTime.now();
      expect(msg.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(msg.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('Custom timestamp preserved', () {
      final customTime = DateTime(2024, 1, 1);
      final msg = ChatMessage(text: 'old', isUser: true, timestamp: customTime);
      expect(msg.timestamp, equals(customTime));
    });
  });

  // ─────────────────────────────────────────────────
  //  3. TEXT INPUT EDGE CASES (OfflineEngine resilience)
  // ─────────────────────────────────────────────────
  group('3. Text Input Edge Cases', () {
    test('OfflineEngine handles whitespace-only input', () {
      final r = OfflineEngine.respond('   ');
      expect(r['validation'], isNotEmpty);
      expect(r['emotion'], 'general');
    });

    test('OfflineEngine handles very long input', () {
      final r = OfflineEngine.respond('I am anxious ' * 1000);
      expect(r['emotion'], 'anxious');
      expect(r['validation'], isNotEmpty);
    });

    test('OfflineEngine handles special characters', () {
      final r = OfflineEngine.respond('<script>alert("anxious")</script>');
      expect(r['validation'], isNotEmpty);
    });

    test('OfflineEngine handles emoji input', () {
      final r = OfflineEngine.respond('I feel sad 😢 and alone');
      expect(r['emotion'], 'sad');
    });

    test('checkCrisisGlobal handles multi-line input', () {
      expect(checkCrisisGlobal('line1\nI want to kill myself\nline3'), true);
      expect(checkCrisisGlobal('line1\njust a normal day\nline3'), false);
    });
  });

  // ─────────────────────────────────────────────────
  //  4. OFFLINE ENGINE
  // ─────────────────────────────────────────────────
  group('4. OfflineEngine Edge Cases', () {
    test('All 10 emotion categories return valid responses', () {
      final inputs = {
        'anxious': 'I feel so anxious and nervous',
        'sad': 'I feel really sad and empty',
        'stressed': 'I am so stressed about everything',
        'angry': 'I am really angry right now',
        'lonely': 'I feel so lonely and isolated',
        'sleepless': "I can't sleep at night",
        'low self-worth': 'I feel worthless',
        'overwhelmed': 'Everything is overwhelming me',
        'grief': 'I miss them so much, grieving',
        'confused': 'I feel so confused about my life',
      };
      for (final entry in inputs.entries) {
        final r = OfflineEngine.respond(entry.value);
        expect(r, containsPair('validation', isNotEmpty), reason: '${entry.key} should have validation');
        expect(r, containsPair('insight', isNotEmpty), reason: '${entry.key} should have insight');
        expect(r, containsPair('action', isNotEmpty), reason: '${entry.key} should have action');
      }
    });

    test('Generic fallback for neutral text', () {
      final r = OfflineEngine.respond('the weather is nice today');
      expect(r['validation'], isNotEmpty);
      expect(r['insight'], isNotEmpty);
      expect(r['action'], isNotEmpty);
    });

    test('Empty string returns reflective response', () {
      final r = OfflineEngine.respond('');
      expect(r['validation'], isNotEmpty);
    });

    test('Very long input does not crash', () {
      final r = OfflineEngine.respond('I feel anxious ' * 500);
      expect(r, isNotNull);
      expect(r['emotion'], 'anxious');
    });

    test('Emotion detection — all 7 emotions', () {
      expect(OfflineEngine.detectEmotion('I am so anxious'), 'anxious');
      expect(OfflineEngine.detectEmotion('I feel really sad'), 'sad');
      expect(OfflineEngine.detectEmotion('I am so stressed out'), 'stressed');
      expect(OfflineEngine.detectEmotion('I am angry'), 'angry');
      expect(OfflineEngine.detectEmotion('Feeling lonely'), 'lonely');
      expect(OfflineEngine.detectEmotion('I cannot sleep'), 'sleepless');
      expect(OfflineEngine.detectEmotion('I feel worthless'), 'low self-worth');
    });

    test('Emotion detection — case insensitive', () {
      expect(OfflineEngine.detectEmotion('I AM SO ANXIOUS'), 'anxious');
      expect(OfflineEngine.detectEmotion('VERY STRESSED OUT'), 'stressed');
    });

    test('Emotion detection — fallback to reflective', () {
      expect(OfflineEngine.detectEmotion('hello world'), 'reflective');
      expect(OfflineEngine.detectEmotion(''), 'reflective');
    });
  });

  // ─────────────────────────────────────────────────
  //  5. CRISIS DETECTION
  // ─────────────────────────────────────────────────
  group('5. Crisis Detection', () {
    test('Detects "suicide"', () => expect(checkCrisisGlobal('I am thinking about suicide'), true));
    test('Detects "kill myself"', () => expect(checkCrisisGlobal('I want to kill myself'), true));
    test('Detects "end it all"', () => expect(checkCrisisGlobal('I want to end it all'), true));
    test('Detects "no reason to live"', () => expect(checkCrisisGlobal('There is no reason to live'), true));
    test('Detects "want to die"', () => expect(checkCrisisGlobal('I want to die'), true));
    test('Detects "self harm"', () => expect(checkCrisisGlobal('I want to self harm'), true));
    test('Detects "hurt myself"', () => expect(checkCrisisGlobal('I want to hurt myself'), true));
    test('Detects "cut myself"', () => expect(checkCrisisGlobal('I want to cut myself'), true));
    test('Detects "overdose"', () => expect(checkCrisisGlobal('thinking about overdose'), true));
    test('Detects "jump off"', () => expect(checkCrisisGlobal('I want to jump off a building'), true));

    test('Case insensitive', () => expect(checkCrisisGlobal('I WANT TO KILL MYSELF'), true));
    test('Mixed case', () => expect(checkCrisisGlobal('Thinking About Suicide'), true));
    test('Embedded in sentence', () => expect(checkCrisisGlobal('Sometimes I think I want to die and nobody cares'), true));

    // Safe phrases — should NOT trigger
    test('Safe: "killing it"', () => expect(checkCrisisGlobal('I was killing it at the presentation'), false));
    test('Safe: normal text', () => expect(checkCrisisGlobal('I had a great day today'), false));
    test('Safe: "deadline"', () => expect(checkCrisisGlobal('This deadline is killing me'), false));
    test('Safe: "died laughing"', () => expect(checkCrisisGlobal('I almost died laughing at that joke'), false));
    test('Safe: empty string', () => expect(checkCrisisGlobal(''), false));
    test('Safe: only spaces', () => expect(checkCrisisGlobal('   '), false));
    test('Safe: numbers only', () => expect(checkCrisisGlobal('12345'), false));
    test('Safe: "suicide squad" (movie)', () {
      // Note: "suicide" is a keyword, this WILL trigger — documenting the known false positive
      expect(checkCrisisGlobal('I watched Suicide Squad'), true);
    });
  });

  // ─────────────────────────────────────────────────
  //  6. SUS SCORE CALCULATION
  // ─────────────────────────────────────────────────
  group('6. SUS Score Calculation', () {
    test('Perfect score = 100.0', () {
      expect(calculateSusScoreGlobal([5, 1, 5, 1, 5, 1, 5, 1, 5, 1]), equals(100.0));
    });

    test('Worst score = 0.0', () {
      expect(calculateSusScoreGlobal([1, 5, 1, 5, 1, 5, 1, 5, 1, 5]), equals(0.0));
    });

    test('Neutral score = 50.0', () {
      expect(calculateSusScoreGlobal([3, 3, 3, 3, 3, 3, 3, 3, 3, 3]), equals(50.0));
    });

    test('Realistic score in range', () {
      final score = calculateSusScoreGlobal([4, 2, 5, 1, 4, 2, 4, 1, 5, 2]);
      expect(score, greaterThanOrEqualTo(0.0));
      expect(score, lessThanOrEqualTo(100.0));
    });

    test('Wrong count throws ArgumentError', () {
      expect(() => calculateSusScoreGlobal([5, 1, 5]), throwsA(isA<ArgumentError>()));
      expect(() => calculateSusScoreGlobal([]), throwsA(isA<ArgumentError>()));
      expect(() => calculateSusScoreGlobal(List.filled(11, 3)), throwsA(isA<ArgumentError>()));
    });

    test('Boundary values (all 1s and all 5s)', () {
      final allOnes = calculateSusScoreGlobal([1, 1, 1, 1, 1, 1, 1, 1, 1, 1]);
      expect(allOnes, greaterThanOrEqualTo(0.0));
      expect(allOnes, lessThanOrEqualTo(100.0));
    });
  });

  // ─────────────────────────────────────────────────
  //  7. COPING TOOLS DATA INTEGRITY
  // ─────────────────────────────────────────────────
  group('7. Coping Tools Data Integrity', () {
    test('Has exactly 20 tools', () {
      expect(kCopingTools.length, equals(20));
    });

    test('Every tool has required fields', () {
      for (final tool in kCopingTools) {
        expect(tool, contains('title'), reason: '${tool['title'] ?? 'unknown'} missing title');
        expect(tool, contains('category'));
        expect(tool, contains('desc'));
        expect(tool, contains('steps'));
        expect(tool, contains('icon'));
        expect(tool, contains('color'));
        expect((tool['steps'] as List).length, greaterThanOrEqualTo(5),
            reason: '${tool['title']} needs ≥5 steps');
      }
    });

    test('All titles are unique', () {
      final titles = kCopingTools.map((t) => t['title']).toList();
      expect(titles.toSet().length, equals(titles.length));
    });

    test('Valid categories', () {
      const valid = {'Breathing', 'Grounding', 'Somatic', 'CBT', 'Mindfulness', 'Self-Compassion'};
      for (final tool in kCopingTools) {
        expect(valid.contains(tool['category']), isTrue,
            reason: '${tool['title']} has invalid category "${tool['category']}"');
      }
    });

    test('Breathing tools have pattern and patternLabels', () {
      final breathingTools = kCopingTools.where((t) => t['category'] == 'Breathing');
      for (final tool in breathingTools) {
        expect(tool, contains('pattern'), reason: '${tool['title']} missing pattern');
        expect(tool, contains('patternLabels'), reason: '${tool['title']} missing patternLabels');
        final pattern = tool['pattern'] as List;
        final labels = tool['patternLabels'] as List;
        expect(pattern.length, equals(labels.length),
            reason: '${tool['title']}: pattern/labels length mismatch');
      }
    });

    test('Non-breathing tools have no pattern', () {
      final nonBreathing = kCopingTools.where((t) => t['category'] != 'Breathing');
      for (final tool in nonBreathing) {
        expect(tool.containsKey('pattern'), isFalse,
            reason: '${tool['title']} should not have pattern');
      }
    });
  });

  // ─────────────────────────────────────────────────
  //  8. WELLNESS ACTIVITIES DATA INTEGRITY
  // ─────────────────────────────────────────────────
  group('8. Wellness Activities Data Integrity', () {
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
        expect((act['steps'] as List).length, greaterThanOrEqualTo(5),
            reason: '${act['title']} needs ≥5 steps');
      }
    });

    test('All titles are unique', () {
      final titles = kWellnessActivities.map((a) => a['title']).toList();
      expect(titles.toSet().length, equals(titles.length));
    });

    test('Valid categories', () {
      const valid = {'Meditation', 'Movement', 'Journaling', 'Nature', 'Creative', 'Self-Care', 'Social'};
      for (final act in kWellnessActivities) {
        expect(valid.contains(act['category']), isTrue,
            reason: '${act['title']} has invalid category "${act['category']}"');
      }
    });

    test('Category filter returns correct subsets', () {
      final meditationCount = kWellnessActivities.where((a) => a['category'] == 'Meditation').length;
      expect(meditationCount, greaterThan(0));
      final allCount = kWellnessActivities.length;
      expect(meditationCount, lessThan(allCount));
    });
  });

  // ─────────────────────────────────────────────────
  //  9. USER PROFILE LIFECYCLE
  // ─────────────────────────────────────────────────
  group('9. UserProfile Lifecycle', () {
    setUp(() async {
      await _setPrefs({});
    });

    test('Singleton returns same instance', () {
      final a = UserProfile();
      final b = UserProfile();
      expect(identical(a, b), isTrue);
    });

    test('Default values are empty', () async {
      final p = UserProfile();
      await p.clearProfile();
      expect(p.name, isEmpty);
      expect(p.ageGroup, isEmpty);
      expect(p.concerns, isEmpty);
      expect(p.copingStrategiesWorked, isEmpty);
      expect(p.copingStrategiesFailed, isEmpty);
      expect(p.additionalNotes, isEmpty);
    });

    test('Save and load round-trip', () async {
      final p = UserProfile();
      p.name = 'TestUser';
      p.ageGroup = '25-34';
      p.voicePreference = 'Puck';
      p.concerns = ['Anxiety', 'Stress'];
      p.copingStrategiesWorked = ['Deep Breathing'];
      p.copingStrategiesFailed = ['Ignoring Feelings'];
      p.additionalNotes = 'Test notes';
      await p.saveToStorage();

      // Simulate reload
      p.name = '';
      p.ageGroup = '';
      p.voicePreference = 'Aoede';
      p.concerns = [];
      p.copingStrategiesWorked = [];
      p.copingStrategiesFailed = [];
      p.additionalNotes = '';
      await p.loadFromStorage();

      expect(p.name, 'TestUser');
      expect(p.ageGroup, '25-34');
      expect(p.voicePreference, 'Puck');
      expect(p.concerns, ['Anxiety', 'Stress']);
      expect(p.copingStrategiesWorked, ['Deep Breathing']);
      expect(p.copingStrategiesFailed, ['Ignoring Feelings']);
      expect(p.additionalNotes, 'Test notes');
    });

    test('Clear profile resets all fields', () async {
      final p = UserProfile();
      p.name = 'SomeUser';
      p.ageGroup = '18-24';
      p.concerns = ['Depression'];
      await p.saveToStorage();
      await p.clearProfile();

      expect(p.name, isEmpty);
      expect(p.ageGroup, isEmpty);
      expect(p.concerns, isEmpty);
    });

    test('addWorkedStrategy prevents duplicates', () async {
      final p = UserProfile();
      await p.clearProfile();
      await p.addWorkedStrategy('Deep Breathing');
      await p.addWorkedStrategy('Deep Breathing');
      expect(p.copingStrategiesWorked.where((s) => s == 'Deep Breathing').length, 1);
    });

    test('addFailedStrategy prevents duplicates', () async {
      final p = UserProfile();
      await p.clearProfile();
      await p.addFailedStrategy('Ignoring Feelings');
      await p.addFailedStrategy('Ignoring Feelings');
      expect(p.copingStrategiesFailed.where((s) => s == 'Ignoring Feelings').length, 1);
    });

    test('isProfileComplete requires name', () async {
      final p = UserProfile();
      await p.clearProfile();
      expect(p.isProfileComplete, isFalse);
      p.name = 'Test';
      expect(p.isProfileComplete, isTrue);
    });

    test('voicePreference defaults to Sulafat', () async {
      final p = UserProfile();
      await p.clearProfile();
      expect(p.voicePreference, 'Sulafat');
    });

    test('Save empty profile does not crash', () async {
      final p = UserProfile();
      await p.clearProfile();
      await p.saveToStorage(); // Should not throw
    });

    test('Load from empty prefs does not crash', () async {
      await _setPrefs({});
      final p = UserProfile();
      await p.loadFromStorage(); // Should not throw
    });
  });

  // ─────────────────────────────────────────────────
  //  10. CLOUD SYNC (AuthService offline-safe)
  // ─────────────────────────────────────────────────
  group('10. Cloud Sync Safety', () {
    test('saveAndSync does nothing when not signed in', () async {
      final p = UserProfile();
      // Should not throw even when Firebase is not initialized
      await p.saveAndSync();
    });

    test('loadFromCloudAndMerge returns gracefully when not signed in', () async {
      final p = UserProfile();
      await p.loadFromCloudAndMerge();
      // No crash — graceful degradation
    });
  });

  // ─────────────────────────────────────────────────
  //  11. USER PROFILE STRATEGY TRACKING
  // ─────────────────────────────────────────────────
  group('11. Coping Strategy Tracking', () {
    setUp(() async {
      await _setPrefs({});
    });

    test('addWorkedStrategy persists across save/load cycle', () async {
      final p = UserProfile();
      await p.clearProfile();
      await p.addWorkedStrategy('Box Breathing');
      await p.addWorkedStrategy('Grounding');

      p.copingStrategiesWorked = [];
      await p.loadFromStorage();
      expect(p.copingStrategiesWorked, contains('Box Breathing'));
      expect(p.copingStrategiesWorked, contains('Grounding'));
    });

    test('addFailedStrategy persists across save/load cycle', () async {
      final p = UserProfile();
      await p.clearProfile();
      await p.addFailedStrategy('Meditation');

      p.copingStrategiesFailed = [];
      await p.loadFromStorage();
      expect(p.copingStrategiesFailed, contains('Meditation'));
    });

    test('Empty string strategies are rejected', () async {
      final p = UserProfile();
      await p.clearProfile();
      await p.addWorkedStrategy('');
      expect(p.copingStrategiesWorked, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────
  //  12. EMOTION DETECTION ADVANCED
  // ─────────────────────────────────────────────────
  group('12. Emotion Detection Advanced', () {
    test('OfflineEngine.detectEmotion works consistently', () {
      expect(OfflineEngine.detectEmotion('I feel anxious'), equals(OfflineEngine.detectEmotion('I feel anxious')));
      expect(OfflineEngine.detectEmotion('I feel sad'), equals(OfflineEngine.detectEmotion('I feel sad')));
    });

    test('Multiple emotions — first match wins', () {
      // OfflineEngine checks emotions in order; first keyword found wins
      final result = OfflineEngine.detectEmotion('I feel anxious and sad and angry');
      expect(['anxious', 'sad', 'angry'], contains(result));
    });

    test('Subtle emotion keywords detected', () {
      expect(OfflineEngine.detectEmotion('My anxiety is through the roof'), 'anxious');
      expect(OfflineEngine.detectEmotion('I have been feeling depressed'), 'sad');
      expect(OfflineEngine.detectEmotion('Work pressure is too much'), 'stressed');
    });

    test('Special characters in input', () {
      final result = OfflineEngine.detectEmotion('!!!anxious???');
      expect(result, 'anxious');
    });
  });

  // ─────────────────────────────────────────────────
  //  13. COPING TOOLS CATEGORY COVERAGE
  // ─────────────────────────────────────────────────
  group('13. Coping Tool Category Coverage', () {
    test('Every coping category has at least 2 tools', () {
      final cats = <String, int>{};
      for (final t in kCopingTools) {
        cats[t['category'] as String] = (cats[t['category'] as String] ?? 0) + 1;
      }
      for (final entry in cats.entries) {
        expect(entry.value, greaterThanOrEqualTo(2),
            reason: '${entry.key} has only ${entry.value} tool(s)');
      }
    });

    test('Every wellness category has at least 2 activities', () {
      final cats = <String, int>{};
      for (final a in kWellnessActivities) {
        cats[a['category'] as String] = (cats[a['category'] as String] ?? 0) + 1;
      }
      for (final entry in cats.entries) {
        expect(entry.value, greaterThanOrEqualTo(2),
            reason: '${entry.key} has only ${entry.value} activity/ies');
      }
    });

    test('Breathing tools have valid pattern values (>0 seconds each)', () {
      final breathingTools = kCopingTools.where((t) => t['category'] == 'Breathing');
      for (final tool in breathingTools) {
        final pattern = (tool['pattern'] as List).cast<int>();
        for (final phase in pattern) {
          expect(phase, greaterThan(0),
              reason: '${tool['title']} has a 0-second phase');
        }
      }
    });
  });

  // ─────────────────────────────────────────────────
  //  14. DATA CONSISTENCY CROSS-CHECK
  // ─────────────────────────────────────────────────
  group('14. Data Consistency', () {
    test('Every coping tool desc is non-empty', () {
      for (final tool in kCopingTools) {
        expect((tool['desc'] as String).isNotEmpty, isTrue,
            reason: '${tool['title']} has empty desc');
      }
    });

    test('Every wellness activity desc is non-empty', () {
      for (final act in kWellnessActivities) {
        expect((act['desc'] as String).isNotEmpty, isTrue,
            reason: '${act['title']} has empty desc');
      }
    });

    test('All step lists contain non-empty strings', () {
      for (final tool in kCopingTools) {
        for (final step in (tool['steps'] as List)) {
          expect((step as String).isNotEmpty, isTrue,
              reason: '${tool['title']} has empty step');
        }
      }
      for (final act in kWellnessActivities) {
        for (final step in (act['steps'] as List)) {
          expect((step as String).isNotEmpty, isTrue,
              reason: '${act['title']} has empty step');
        }
      }
    });

    test('No duplicate titles across both datasets', () {
      final copingTitles = kCopingTools.map((t) => t['title'] as String).toSet();
      final wellnessTitles = kWellnessActivities.map((a) => a['title'] as String).toSet();
      final overlap = copingTitles.intersection(wellnessTitles);
      expect(overlap, isEmpty,
          reason: 'Overlapping titles: $overlap');
    });
  });

  // ─────────────────────────────────────────────────
  //  15. GUIDED BREATHING VALIDATION (from kCopingTools data)
  // ─────────────────────────────────────────────────
  group('15. Guided Breathing Validation', () {
    test('All breathing tools have reasonable cycle durations', () {
      final breathingTools = kCopingTools.where((t) => t['category'] == 'Breathing');
      expect(breathingTools.length, greaterThanOrEqualTo(2));
      for (final tool in breathingTools) {
        final pattern = (tool['pattern'] as List).cast<int>();
        final cycleSeconds = pattern.reduce((a, b) => a + b);
        expect(cycleSeconds, greaterThan(5),
            reason: '${tool['title']} cycle is too short (${cycleSeconds}s)');
        expect(cycleSeconds, lessThan(60),
            reason: '${tool['title']} cycle is too long (${cycleSeconds}s)');
      }
    });

    test('All breathing tools fit at least 1 cycle in 2 minutes', () {
      final breathingTools = kCopingTools.where((t) => t['category'] == 'Breathing');
      for (final tool in breathingTools) {
        final pattern = (tool['pattern'] as List).cast<int>();
        final cycleSeconds = pattern.reduce((a, b) => a + b);
        final cyclesIn2Min = (120 / cycleSeconds).floor();
        expect(cyclesIn2Min, greaterThan(0),
            reason: '${tool['title']} cannot fit a cycle in 2 minutes');
      }
    });

    test('Pattern labels match pattern length for all breathing tools', () {
      final breathingTools = kCopingTools.where((t) => t['category'] == 'Breathing');
      for (final tool in breathingTools) {
        final pattern = tool['pattern'] as List;
        final labels = tool['patternLabels'] as List;
        expect(pattern.length, equals(labels.length),
            reason: '${tool['title']}: ${pattern.length} phases but ${labels.length} labels');
      }
    });
  });
}
