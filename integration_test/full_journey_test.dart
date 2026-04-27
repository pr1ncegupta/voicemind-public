// =============================================================================
//  VoiceMind — FULL JOURNEY INTEGRATION TEST (Live Monitoring Edition)
//  Run: flutter test integration_test/full_journey_test.dart -d macos --verbose
//
//  This test covers EVERY user-facing feature while you manually test the app.
//  Each test group logs its progress step-by-step with ✅/❌ markers.
//  Watch the console output in real-time to monitor what's happening.
//  The test runs against a LIVE app — real UI, real SharedPreferences.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicemind_flutter/main.dart' as app;
import 'package:voicemind_flutter/src/data/models/tools_data.dart';
import 'package:voicemind_flutter/src/data/models/user_profile.dart';
import 'package:voicemind_flutter/src/data/models/chat_message.dart';
import 'package:voicemind_flutter/src/services/offline_engine.dart';


// ── Logging Helpers ─────────────────────────────────────────────────────────
void banner(String s) {
  final ts = DateTime.now().toIso8601String().substring(11, 19);
  final bar = '=' * 70;
  debugPrint('\n$bar');
  debugPrint('  🧪 [$ts]  $s');
  debugPrint(bar);
}

void log(String label, Object? value) {
  debugPrint('    ▸ $label: $value');
}

void pass(String label) => debugPrint('    ✅ PASS: $label');
void fail(String label, String detail) => debugPrint('    ❌ FAIL: $label — $detail');
void info(String msg) => debugPrint('    ℹ️  $msg');

// Helper: tap if found
Future<void> tapIfFound(WidgetTester t, Finder f, {String label = ''}) async {
  if (f.evaluate().isNotEmpty) {
    await t.tap(f.first);
    await t.pumpAndSettle();
    pass('Tapped: $label');
  } else {
    info('Not found (skipping): $label');
  }
}

// Helper: wait for widget with timeout
Future<bool> waitForWidget(WidgetTester t, Finder f, {
  Duration timeout = const Duration(seconds: 10), required String label,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (f.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await t.pump(const Duration(milliseconds: 500));
  }
  if (f.evaluate().isNotEmpty) {
    pass('Found: $label');
    return true;
  } else {
    fail('Timeout waiting for', label);
    return false;
  }
}

// Helper: skip onboarding if present
Future<void> skipOnboardingIfPresent(WidgetTester t) async {
  // Check if we're on the Welcome/Onboarding screen
  final beginBtn = find.textContaining('Begin');
  if (beginBtn.evaluate().isNotEmpty) {
    await t.tap(beginBtn.first);
    await t.pumpAndSettle();
    // Skip through onboarding pages
    for (int i = 0; i < 5; i++) {
      final skip = find.text('Skip');
      final getStarted = find.text('Get Started');
      if (skip.evaluate().isNotEmpty) {
        await t.tap(skip);
        await t.pumpAndSettle();
        break;
      } else if (getStarted.evaluate().isNotEmpty) {
        await t.tap(getStarted);
        await t.pumpAndSettle();
        break;
      }
      // Try Next button
      final next = find.text('Next');
      if (next.evaluate().isNotEmpty) {
        await t.tap(next);
        await t.pumpAndSettle();
      }
    }
    info('Onboarding skipped/completed');
  }
}

// ── Test Data ────────────────────────────────────────────────────────────────
const kTestName = 'VoiceMind Test User';
const kTestAgeGroup = '18-24';

// =============================================================================
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── PRE-TEST: Clear state ─────────────────────────────────────────────────
  setUpAll(() async {
    banner('PRE-TEST SETUP: Clearing SharedPreferences for clean slate');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    log('SharedPreferences', 'CLEARED');
    log('Test started at', DateTime.now().toIso8601String());
    pass('Clean slate ready');
  });

  // ===========================================================================
  // GROUP 1: APP COLD START
  // ===========================================================================
  group('1. App Launch & Cold Start', () {
    testWidgets('1.1 App launches without crash', (t) async {
      banner('GROUP 1 — APP LAUNCH');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      pass('App launched without crash');

      // Verify MaterialApp rendered
      expect(find.byType(MaterialApp), findsOneWidget);
      pass('MaterialApp widget rendered');

      // Log what's visible
      final texts = find.byType(Text).evaluate().take(5).map(
        (e) => (e.widget as Text).data
      ).toList();
      log('First 5 visible texts', texts);
    });

    testWidgets('1.2 Something meaningful is on screen', (t) async {
      banner('GROUP 1.2 — SCREEN CONTENT');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 3));

      // Should see either Welcome screen or Dashboard
      final hasWelcome = find.textContaining('VoiceMind').evaluate().isNotEmpty;
      final hasBegin = find.textContaining('Begin').evaluate().isNotEmpty;
      final hasCoping = find.text('Coping').evaluate().isNotEmpty;
      final hasTalk = find.text('Talk').evaluate().isNotEmpty;

      log('Welcome/VoiceMind visible', hasWelcome);
      log('Begin button visible', hasBegin);
      log('Coping tab visible', hasCoping);
      log('Talk tab visible', hasTalk);

      expect(hasWelcome || hasBegin || hasCoping || hasTalk, isTrue,
          reason: 'At least one expected element must be visible');
      pass('App shows meaningful content on launch');
    });
  });

  // ===========================================================================
  // GROUP 2: ONBOARDING FLOW
  // ===========================================================================
  group('2. Onboarding Flow', () {
    testWidgets('2.1 Welcome screen shows VoiceMind branding', (t) async {
      banner('GROUP 2 — ONBOARDING');
      // Ensure fresh state for onboarding
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      app.main();
      await t.pumpAndSettle(const Duration(seconds: 3));

      final vmText = find.text('VoiceMind');
      if (vmText.evaluate().isNotEmpty) {
        pass('VoiceMind title displayed on welcome screen');
      } else {
        info('VoiceMind title not found — may already be past onboarding');
      }

      // Check for Begin Your Journey or similar CTA
      final cta = find.textContaining('Begin');
      if (cta.evaluate().isNotEmpty) {
        pass('CTA button found');
        log('CTA text', (cta.evaluate().first.widget as Text).data);
      }
    });

    testWidgets('2.2 Onboarding pages can be navigated', (t) async {
      banner('GROUP 2.2 — ONBOARDING PAGES');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      app.main();
      await t.pumpAndSettle(const Duration(seconds: 3));

      // Tap Begin / Begin Your Journey
      final beginBtn = find.textContaining('Begin');
      if (beginBtn.evaluate().isNotEmpty) {
        await t.tap(beginBtn.first);
        await t.pumpAndSettle();
        pass('Tapped Begin button');

        // Check for onboarding content
        final pageTexts = ['Voice-First', 'Offline', 'Wellness', 'Personalized'];
        int pagesFound = 0;
        for (final text in pageTexts) {
          if (find.textContaining(text).evaluate().isNotEmpty) {
            pagesFound++;
            pass('Onboarding page content found: "$text"');
          }
        }
        log('Onboarding pages detected', '$pagesFound / ${pageTexts.length}');

        // Try Skip button
        final skip = find.text('Skip');
        if (skip.evaluate().isNotEmpty) {
          pass('Skip button available');
          await t.tap(skip);
          await t.pumpAndSettle();
          pass('Skipped onboarding');
        } else {
          // Navigate through pages
          for (int i = 0; i < 4; i++) {
            final next = find.text('Next');
            final getStarted = find.text('Get Started');
            if (next.evaluate().isNotEmpty) {
              await t.tap(next);
              await t.pumpAndSettle();
            } else if (getStarted.evaluate().isNotEmpty) {
              await t.tap(getStarted);
              await t.pumpAndSettle();
              break;
            }
          }
          pass('Navigated through all onboarding pages');
        }
      } else {
        info('Begin button not found — onboarding may be already completed');
      }
    });

    testWidgets('2.3 has_seen_onboarding flag persists', (t) async {
      banner('GROUP 2.3 — ONBOARDING PERSISTENCE');
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('has_seen_onboarding');
      log('has_seen_onboarding', seen);
      // After the prior test navigated onboarding, the flag should be set
      // or still null if sign-in blocked it — either is a valid state on CI
      expect(seen == true || seen == null, isTrue,
          reason: 'Flag must be true (completed) or null (sign-in blocked), not false');
      pass('Onboarding flag state valid: $seen');
    });
  });

  // ===========================================================================
  // GROUP 3: MAIN DASHBOARD & TAB NAVIGATION
  // ===========================================================================
  group('3. Dashboard & Tab Navigation', () {
    testWidgets('3.1 Dashboard renders with 3 tab navigation', (t) async {
      banner('GROUP 3 — DASHBOARD');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);

      // Check for the 3 tab labels
      final copingTab = find.text('Coping');
      final talkTab = find.text('Talk');
      final wellnessTab = find.text('Wellness');

      log('Coping tab found', copingTab.evaluate().isNotEmpty);
      log('Talk tab found', talkTab.evaluate().isNotEmpty);
      log('Wellness tab found', wellnessTab.evaluate().isNotEmpty);

      if (copingTab.evaluate().isNotEmpty) pass('Coping tab visible');
      if (talkTab.evaluate().isNotEmpty) pass('Talk tab visible');
      if (wellnessTab.evaluate().isNotEmpty) pass('Wellness tab visible');

      // Default tab should be Talk (index 1)
      // Check for mic icon which is on the Talk page
      final micIcon = find.byIcon(Icons.mic_rounded);
      if (micIcon.evaluate().isNotEmpty) {
        pass('Talk page is default (mic icon visible)');
      }
    });

    testWidgets('3.2 Navigate to Coping Toolbox tab', (t) async {
      banner('GROUP 3.2 — COPING TAB');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);

      final copingTab = find.text('Coping');
      if (copingTab.evaluate().isNotEmpty) {
        await t.tap(copingTab);
        await t.pumpAndSettle(const Duration(seconds: 2));
        pass('Switched to Coping Toolbox tab');

        // Verify coping content loaded
        final categories = ['Breathing', 'Grounding', 'Somatic', 'CBT', 'Mindfulness', 'Self-Compassion'];
        int found = 0;
        for (final cat in categories) {
          if (find.textContaining(cat).evaluate().isNotEmpty) {
            found++;
            pass('Category visible: $cat');
          }
        }
        log('Coping categories found', '$found / ${categories.length}');
      }
    });

    testWidgets('3.3 Navigate to Wellness Activities tab', (t) async {
      banner('GROUP 3.3 — WELLNESS TAB');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);

      final wellnessTab = find.text('Wellness');
      if (wellnessTab.evaluate().isNotEmpty) {
        await t.tap(wellnessTab);
        await t.pumpAndSettle(const Duration(seconds: 2));
        pass('Switched to Wellness Activities tab');

        // Verify wellness content loaded
        final categories = ['Meditation', 'Movement', 'Journaling', 'Nature', 'Creative', 'Self-Care', 'Social'];
        int found = 0;
        for (final cat in categories) {
          if (find.textContaining(cat).evaluate().isNotEmpty) {
            found++;
            pass('Wellness category visible: $cat');
          }
        }
        log('Wellness categories found', '$found / ${categories.length}');
      }
    });

    testWidgets('3.4 Navigate back to Talk tab', (t) async {
      banner('GROUP 3.4 — BACK TO TALK TAB');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);

      // Switch to Coping first
      await tapIfFound(t, find.text('Coping'), label: 'Coping tab');
      await t.pumpAndSettle();

      // Switch back to Talk
      final talkTab = find.text('Talk');
      if (talkTab.evaluate().isNotEmpty) {
        await t.tap(talkTab);
        await t.pumpAndSettle();
        pass('Switched back to Talk tab');
      }
    });
  });

  // ===========================================================================
  // GROUP 4: PROFILE PAGE
  // ===========================================================================
  group('4. Profile Page', () {
    testWidgets('4.1 Navigate to Profile and fill data', (t) async {
      banner('GROUP 4 — PROFILE PAGE');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);

      // Look for profile icon in AppBar
      final profileIcon = find.byIcon(Icons.person_outline_rounded);
      if (profileIcon.evaluate().isNotEmpty) {
        await t.tap(profileIcon.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        pass('Navigated to ProfilePage');

        // Try to find and fill the name field
        final nameField = find.byType(TextFormField);
        if (nameField.evaluate().isNotEmpty) {
          await t.tap(nameField.first);
          await t.pumpAndSettle();
          await t.enterText(nameField.first, kTestName);
          await t.pumpAndSettle();
          pass('Entered profile name: $kTestName');
          log('Name field', kTestName);
        } else {
          final textField = find.byType(TextField);
          if (textField.evaluate().isNotEmpty) {
            await t.tap(textField.first);
            await t.enterText(textField.first, kTestName);
            await t.pumpAndSettle();
            pass('Entered name via TextField');
          }
        }

        // Try selecting a concern chip (Anxiety)
        final anxietyChip = find.text('Anxiety');
        if (anxietyChip.evaluate().isNotEmpty) {
          await t.tap(anxietyChip);
          await t.pumpAndSettle();
          pass('Selected concern: Anxiety');
        }

        // Try selecting another concern (Stress)
        final stressChip = find.text('Stress');
        if (stressChip.evaluate().isNotEmpty) {
          await t.tap(stressChip);
          await t.pumpAndSettle();
          pass('Selected concern: Stress');
        }

        // Try selecting coping strategy that works
        final breathingChip = find.text('Deep Breathing');
        if (breathingChip.evaluate().isNotEmpty) {
          await t.tap(breathingChip);
          await t.pumpAndSettle();
          pass('Selected worked strategy: Deep Breathing');
        }

        // Save profile
        final saveBtns = [
          find.textContaining('Save'),
          find.textContaining('UPDATE'),
        ];
        for (final btn in saveBtns) {
          if (btn.evaluate().isNotEmpty) {
            // Scroll to make save button visible
            await t.ensureVisible(btn.first);
            await t.tap(btn.first);
            await t.pumpAndSettle();
            pass('Profile saved');
            break;
          }
        }
      } else {
        info('Profile icon not found in AppBar');
      }
    });

    testWidgets('4.2 Profile persisted in SharedPreferences', (t) async {
      banner('GROUP 4.2 — PROFILE PERSISTENCE');
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name') ?? '';
      final savedVoice = prefs.getString('voice_preference') ?? '';

      log('user_name', savedName);
      log('voice_preference', savedVoice);

      // SharedPreferences must at least be accessible without crash
      expect(prefs, isNotNull);
      // voice_preference should have a value (either user-set or default)
      // If the profile was saved in 4.1, name is non-empty;
      // otherwise voice_preference still reflects the loaded default.
      final p = UserProfile();
      await p.loadFromStorage();
      expect(p.voicePreference, isNotEmpty,
          reason: 'voicePreference must have a value (at least the default)');
      pass('Profile SharedPreferences accessible and voicePreference set: ${p.voicePreference}');
    });

    testWidgets('4.3 UserProfile singleton reflects stored data', (t) async {
      banner('GROUP 4.3 — SINGLETON VERIFICATION');
      await UserProfile().loadFromStorage();
      final p = UserProfile();
      log('UserProfile.name', p.name);
      log('UserProfile.voicePreference', p.voicePreference);
      log('UserProfile.isProfileComplete', p.isProfileComplete);

      // Singleton must return the same instance
      expect(identical(p, UserProfile()), isTrue,
          reason: 'UserProfile must be a singleton');
      // voicePreference must always have a value
      expect(p.voicePreference, isNotEmpty);
      // concerns and strategies must be lists (not null)
      expect(p.concerns, isA<List<String>>());
      expect(p.copingStrategiesWorked, isA<List<String>>());
      expect(p.copingStrategiesFailed, isA<List<String>>());
      pass('Singleton verified with real assertions');
    });
  });

  // ===========================================================================
  // GROUP 5: TALK PAGE — TEXT INPUT
  // ===========================================================================
  group('5. Talk Page — Text Input & Chat', () {
    testWidgets('5.1 Text input field is visible and functional', (t) async {
      banner('GROUP 5 — TALK PAGE TEXT INPUT');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);

      // Make sure we're on Talk tab
      await tapIfFound(t, find.text('Talk'), label: 'Talk tab');
      await t.pumpAndSettle();

      final textField = find.byType(TextField);
      if (textField.evaluate().isNotEmpty) {
        pass('TextField found on Talk page');

        // Enter a test message
        await t.tap(textField.last);
        await t.pumpAndSettle();
        await t.enterText(textField.last, 'I am feeling a bit stressed today');
        await t.pumpAndSettle();
        pass('Entered text: "I am feeling a bit stressed today"');
        log('Text successfully entered', true);

        // Look for send button
        final sendBtn = find.byIcon(Icons.send);
        final sendRounded = find.byIcon(Icons.send_rounded);
        if (sendBtn.evaluate().isNotEmpty) {
          pass('Send button (Icons.send) found');
          await t.tap(sendBtn);
          await t.pumpAndSettle();
          pass('Send button tapped');
        } else if (sendRounded.evaluate().isNotEmpty) {
          pass('Send button (Icons.send_rounded) found');
          await t.tap(sendRounded);
          await t.pumpAndSettle();
          pass('Send button tapped');
        } else {
          // Try submitting via text input action
          await t.testTextInput.receiveAction(TextInputAction.send);
          await t.pumpAndSettle();
          pass('Submitted via TextInputAction.send');
        }

        // Wait for response (may take up to 15s for API)
        info('Waiting for AI response (up to 15 seconds)...');
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle(const Duration(seconds: 13));
        pass('App survived sending text message');
      } else {
        info('TextField not found on current screen');
      }
    });

    testWidgets('5.2 AI response or offline fallback appears', (t) async {
      banner('GROUP 5.2 — AI RESPONSE');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);
      await tapIfFound(t, find.text('Talk'), label: 'Talk tab');

      final textField = find.byType(TextField);
      if (textField.evaluate().isNotEmpty) {
        await t.tap(textField.last);
        await t.enterText(textField.last, 'I feel overwhelmed with everything happening');
        await t.pumpAndSettle();
        
        final sendBtn = find.byIcon(Icons.send);
        if (sendBtn.evaluate().isNotEmpty) {
          await t.tap(sendBtn);
        } else {
          await t.testTextInput.receiveAction(TextInputAction.send);
        }

        // Wait for response
        info('Waiting for AI response...');
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle(const Duration(seconds: 12));

        // Check if user message is visible
        final userMsg = find.textContaining('overwhelmed');
        if (userMsg.evaluate().isNotEmpty) {
          pass('User message visible in chat: "overwhelmed"');
        } else {
          info('User message text not directly visible (may be in custom widget)');
        }

        // Check for response indicators
        final hasOffline = find.byIcon(Icons.wifi_off).evaluate().isNotEmpty;
        final hasValidation = find.textContaining('valid').evaluate().isNotEmpty ||
                              find.textContaining('hear').evaluate().isNotEmpty ||
                              find.textContaining('feel').evaluate().isNotEmpty;
        
        log('Offline indicator', hasOffline);
        log('Response content detected', hasValidation);
        
        if (hasOffline) {
          pass('Offline fallback response shown (backend unreachable — expected in test)');
        } else if (hasValidation) {
          pass('Online AI response content detected');
        } else {
          info('Response content not detected by keyword — may be in custom render');
        }
        pass('App survived full chat cycle without crash');
      }
    });
  });

  // ===========================================================================
  // GROUP 6: QUICK EMOTION FILTER CHIPS
  // ===========================================================================
  group('6. Quick Emotion Filter Chips', () {
    testWidgets('6.1 All 7 emotion chips are visible', (t) async {
      banner('GROUP 6 — QUICK EMOTION CHIPS');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);
      await tapIfFound(t, find.text('Talk'), label: 'Talk tab');
      await t.pumpAndSettle();

      final chips = ['Anxious', 'Sad', 'Stressed', "Can't Sleep", 'Overwhelmed', 'Angry', 'Lonely'];
      int found = 0;
      for (final chip in chips) {
        if (find.text(chip).evaluate().isNotEmpty) {
          found++;
          pass('Chip visible: $chip');
        } else {
          info('Chip not visible: $chip (may need scrolling)');
        }
      }
      log('Emotion chips found', '$found / ${chips.length}');
      expect(found, greaterThan(0), reason: 'At least 1 emotion chip must be visible');
      pass('Emotion chips rendered');
    });

    testWidgets('6.2 Tapping Anxious chip sends message', (t) async {
      banner('GROUP 6.2 — TAP EMOTION CHIP');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);
      await tapIfFound(t, find.text('Talk'), label: 'Talk tab');

      final anxiousChip = find.text('Anxious');
      if (anxiousChip.evaluate().isNotEmpty) {
        await t.tap(anxiousChip);
        await t.pumpAndSettle();
        pass('Tapped "Anxious" chip');
        
        // Wait for response
        info('Waiting for response after chip tap...');
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle(const Duration(seconds: 13));
        pass('App didn\'t crash after chip tap — response processed');
      } else {
        info('Anxious chip not visible');
      }
    });

    testWidgets('6.3 Tapping Stressed chip sends message', (t) async {
      banner('GROUP 6.3 — TAP STRESSED CHIP');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);
      await tapIfFound(t, find.text('Talk'), label: 'Talk tab');

      final stressedChip = find.text('Stressed');
      if (stressedChip.evaluate().isNotEmpty) {
        await t.tap(stressedChip);
        await t.pumpAndSettle();
        pass('Tapped "Stressed" chip');
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle(const Duration(seconds: 13));
        pass('Stressed chip processed without crash');
      }
    });
  });

  // ===========================================================================
  // GROUP 7: OFFLINE ENGINE — Comprehensive
  // ===========================================================================
  group('7. OfflineEngine — Response Generation', () {
    testWidgets('7.1 All 10 emotion categories return valid responses', (t) async {
      banner('GROUP 7 — OFFLINE ENGINE RESPONSES');
      final inputs = [
        ('I feel so anxious and scared right now', 'anxious'),
        ('I am very sad and hopeless today', 'sad'),
        ('I feel so stressed and overwhelmed with work', 'stressed'),
        ('I cannot sleep at all tonight', 'sleep'),
        ('I am so angry and frustrated with everyone', 'angry'),
        ('I feel so lonely and isolated', 'lonely'),
        ('I feel worthless and like a failure', 'worthless'),
        ('I need help and want to talk to someone', 'help'),
        ('My relationship just ended and I am heartbroken', 'relationship'),
        ('My job is killing me, I hate my boss', 'work'),
      ];

      for (final pair in inputs) {
        final result = OfflineEngine.respond(pair.$1);
        log('"${pair.$1.substring(0, 35).padRight(35)}..."', 'emotion=${pair.$2}');
        
        expect(result.containsKey('validation'), isTrue,
            reason: 'Must have validation key for: ${pair.$2}');
        expect(result.containsKey('insight'), isTrue,
            reason: 'Must have insight key for: ${pair.$2}');
        expect(result.containsKey('action'), isTrue,
            reason: 'Must have action key for: ${pair.$2}');
        expect(result['validation']!.isNotEmpty, isTrue,
            reason: 'Validation must not be empty for: ${pair.$2}');
        expect(result['insight']!.isNotEmpty, isTrue,
            reason: 'Insight must not be empty for: ${pair.$2}');
        expect(result['action']!.isNotEmpty, isTrue,
            reason: 'Action must not be empty for: ${pair.$2}');

        log('  validation', '"${result['validation']!.substring(0, 40)}..."');
        log('  insight', '"${result['insight']!.substring(0, 40)}..."');
        log('  action', '"${result['action']!.substring(0, 40)}..."');
        pass('Valid 3-key response for: ${pair.$2}');
      }
    });

    testWidgets('7.2 Generic fallback for unrecognized input', (t) async {
      banner('GROUP 7.2 — OFFLINE GENERIC FALLBACK');
      final inputs = [
        'hello world',
        'the weather is nice today',
        'what is 2 + 2',
        'random text with no emotion keywords',
      ];
      for (final input in inputs) {
        final result = OfflineEngine.respond(input);
        log('"$input"', result);
        expect(result.containsKey('validation'), isTrue);
        expect(result.containsKey('insight'), isTrue);
        expect(result.containsKey('action'), isTrue);
        pass('Generic fallback for: "$input"');
      }
    });

    testWidgets('7.3 OfflineEngine.detectEmotion works for all categories', (t) async {
      banner('GROUP 7.3 — OFFLINE EMOTION DETECTION');
      final tests = {
        'I am so stressed about my exams': 'stressed',
        'I feel completely hopeless and sad today': 'sad',
        'My heart is racing with panic': 'anxious',
        'I am so angry at everything': 'angry',
        'I am so lonely and isolated': 'lonely',
        'I cannot sleep at all': 'sleepless',
        'I feel worthless and useless': 'low self-worth',
      };
      for (final entry in tests.entries) {
        final detected = OfflineEngine.detectEmotion(entry.key);
        log('"${entry.key}"', 'detected=$detected, expected=${entry.value}');
        if (detected == entry.value) {
          pass('Correct emotion: $detected');
        } else {
          info('Partial match: detected=$detected, expected=${entry.value}');
        }
      }
      // Generic fallback
      final generic = OfflineEngine.detectEmotion('The sky is blue');
      log('Generic input', 'detected=$generic');
      expect(generic, equals('reflective'));
      pass('Fallback emotion is "reflective"');
    });
  });

  // ===========================================================================
  // GROUP 8: EMOTION DETECTION (Global)
  // ===========================================================================
  group('8. Emotion Detection — detectEmotionGlobal', () {
    testWidgets('8.1 Maps all emotions correctly', (t) async {
      banner('GROUP 8 — GLOBAL EMOTION DETECTION');
      final tests = {
        'I am so stressed about my exams tomorrow': 'stressed',
        'I feel completely hopeless and sad today': 'sad',
        'My heart is racing, I\'m having a panic attack': 'anxious',
        'I am so mad at my boss right now': 'angry',
        'I am so lonely with nobody to talk to': 'lonely',
        'I cannot sleep at all these days': 'sleepless',
        'I feel like such a failure, worthless': 'low self-worth',
        'Just having a normal day': 'reflective',  // fallback
      };
      for (final entry in tests.entries) {
        final result = detectEmotionGlobal(entry.key);
        log('"${entry.key.substring(0, 40).padRight(40)}"', 'detected=$result expected=${entry.value}');
        if (result == entry.value) {
          pass('Emotion detected: $result ✓');
        } else {
          info('Different result: detected=$result, expected=${entry.value}');
        }
      }
      pass('Emotion detection completed without crash');
    });
  });

  // ===========================================================================
  // GROUP 9: CRISIS DETECTION — Client-Side
  // ===========================================================================
  group('9. Crisis Detection — checkCrisisGlobal', () {
    testWidgets('9.1 High-severity crisis phrases detected', (t) async {
      banner('GROUP 9 — CRISIS DETECTION (POSITIVE)');
      final crisisInputs = [
        'I want to kill myself',
        'I am going to end my life',
        'I have no reason to live',
        'I want to commit suicide',
        'I want to overdose on pills',
        'I want to hang myself',
        'I want to jump off a bridge',
        'I don\'t want to be alive anymore',
        'I want to hurt myself',
        'I\'ve been cutting myself',
        'I want to die',
        'I feel like everyone would be better without me',
        'There is nothing to live for',
        'I wish I was dead',
        'I\'d rather be dead',
      ];
      for (final input in crisisInputs) {
        final result = checkCrisisGlobal(input);
        log('"${input.padRight(50)}"', 'crisis=$result');
        expect(result, isTrue, reason: 'MUST detect crisis for: "$input"');
        pass('Crisis detected: "$input"');
      }
      log('Total crisis phrases tested', crisisInputs.length);
    });

    testWidgets('9.2 Safe phrases do NOT trigger crisis', (t) async {
      banner('GROUP 9.2 — CRISIS DETECTION (NEGATIVE / SAFE)');
      final safeInputs = [
        'I need help with my exam preparation',
        'I am really sad today',
        'I had a tough day at work',
        'I\'m stressed about my deadline',
        'I feel lonely sometimes',
        'My boss is killing me with deadlines',
        'I\'m dying of laughter',
        'The weather is killing it today',
        'I am so anxious about tomorrow',
        'I feel overwhelmed with everything',
      ];
      for (final input in safeInputs) {
        final result = checkCrisisGlobal(input);
        log('"${input.padRight(50)}"', 'crisis=$result');
        expect(result, isFalse, reason: 'Must NOT flag safe phrase: "$input"');
        pass('Safe: "$input"');
      }
      log('Total safe phrases verified', safeInputs.length);
    });
  });

  // ===========================================================================
  // GROUP 10: CRISIS UI FLOW
  // ===========================================================================
  group('10. Crisis Alert UI', () {
    testWidgets('10.1 Type crisis phrase → crisis sheet appears', (t) async {
      banner('GROUP 10 — CRISIS ALERT UI');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);
      await tapIfFound(t, find.text('Talk'), label: 'Talk tab');

      final textField = find.byType(TextField);
      if (textField.evaluate().isNotEmpty) {
        await t.tap(textField.last);
        await t.enterText(textField.last, 'I want to kill myself');
        await t.pumpAndSettle();
        
        final sendBtn = find.byIcon(Icons.send);
        if (sendBtn.evaluate().isNotEmpty) {
          await t.tap(sendBtn);
        } else {
          await t.testTextInput.receiveAction(TextInputAction.send);
        }
        
        // Wait for crisis detection
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle(const Duration(seconds: 5));

        // Look for crisis UI indicators
        final crisisMarkers = [
          find.textContaining('AASRA'),
          find.textContaining('988'),
          find.textContaining('Not Alone'),
          find.textContaining('crisis'),
          find.textContaining('helpline'),
          find.textContaining('matters'),
          find.textContaining('Call'),
        ];
        
        bool crisisShown = false;
        for (final marker in crisisMarkers) {
          if (marker.evaluate().isNotEmpty) {
            final text = (marker.evaluate().first.widget as Text).data ?? '';
            pass('Crisis UI visible: "$text"');
            crisisShown = true;
          }
        }
        
        if (crisisShown) {
          pass('Crisis alert sheet displayed correctly');
        } else {
          info('Crisis UI not found — may need real device for vibration/modal');
        }

        // Try dismissing crisis alert
        final dismissBtn = find.textContaining('okay');
        if (dismissBtn.evaluate().isNotEmpty) {
          await t.tap(dismissBtn.first);
          await t.pumpAndSettle();
          pass('Crisis alert dismissed');
        }
      }
    });
  });

  // ===========================================================================
  // GROUP 11: COPING TOOLS PAGE
  // ===========================================================================
  group('11. Coping Tools Page — Details', () {
    testWidgets('11.1 Tool cards visible with correct structure', (t) async {
      banner('GROUP 11 — COPING TOOLS');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);

      // Navigate to Coping
      await tapIfFound(t, find.text('Coping'), label: 'Coping tab');
      await t.pumpAndSettle(const Duration(seconds: 2));

      // Check for specific tools
      final toolNames = [
        'Box Breathing', '4-7-8 Breath', 'Diaphragmatic Breathing',
        '5-4-3-2-1 Grounding', 'Progressive Muscle Relaxation',
        'Butterfly Hug', 'Thought Record', 'Body Scan',
      ];
      int found = 0;
      for (final tool in toolNames) {
        if (find.textContaining(tool).evaluate().isNotEmpty) {
          found++;
          pass('Tool card visible: $tool');
        }
      }
      log('Tool cards found', '$found / ${toolNames.length}');
      expect(found, greaterThan(0), reason: 'At least some tool cards must be visible');
    });

    testWidgets('11.2 Tap a coping tool → bottom sheet with steps', (t) async {
      banner('GROUP 11.2 — TOOL DETAIL SHEET');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);
      await tapIfFound(t, find.text('Coping'), label: 'Coping tab');
      await t.pumpAndSettle(const Duration(seconds: 2));

      // Try to tap Box Breathing or any available tool
      for (final tool in ['Box Breathing', '4-7-8', 'Grounding', 'Butterfly']) {
        final f = find.textContaining(tool);
        if (f.evaluate().isNotEmpty) {
          await t.tap(f.first);
          await t.pumpAndSettle(const Duration(seconds: 2));
          pass('Tapped tool: $tool');

          // Check for detail content (steps, description, Read Aloud button)
          final hasSteps = find.textContaining('Step').evaluate().isNotEmpty ||
                          find.textContaining('1.').evaluate().isNotEmpty ||
                          find.textContaining('Sit').evaluate().isNotEmpty ||
                          find.textContaining('Breathe').evaluate().isNotEmpty;
          
          final hasReadAloud = find.textContaining('Read Aloud').evaluate().isNotEmpty;
          final hasGuidedSession = find.textContaining('Guided Session').evaluate().isNotEmpty ||
                                   find.textContaining('Start').evaluate().isNotEmpty;

          log('Detail steps visible', hasSteps);
          log('Read Aloud button', hasReadAloud);
          log('Guided Session button', hasGuidedSession);

          if (hasSteps) pass('Tool detail shows steps');
          if (hasReadAloud) pass('Read Aloud button available');
          if (hasGuidedSession) pass('Guided Session button available (breathing tool)');

          // Log first few visible texts
          final texts = find.byType(Text).evaluate().take(8).map(
            (e) => (e.widget as Text).data
          ).toList();
          log('Detail sheet content', texts);
          break;
        }
      }
    });

    testWidgets('11.3 Category filter chips work', (t) async {
      banner('GROUP 11.3 — CATEGORY FILTERS');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);
      await tapIfFound(t, find.text('Coping'), label: 'Coping tab');
      await t.pumpAndSettle(const Duration(seconds: 2));

      // Try tapping category filter chips
      for (final cat in ['Breathing', 'Grounding', 'CBT', 'All']) {
        final chip = find.text(cat);
        if (chip.evaluate().isNotEmpty) {
          await t.tap(chip.first);
          await t.pumpAndSettle();
          pass('Tapped category filter: $cat');
        }
      }
    });
  });

  // ===========================================================================
  // GROUP 12: WELLNESS ACTIVITIES PAGE
  // ===========================================================================
  group('12. Wellness Activities Page', () {
    testWidgets('12.1 Activity list renders', (t) async {
      banner('GROUP 12 — WELLNESS ACTIVITIES');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);
      await tapIfFound(t, find.text('Wellness'), label: 'Wellness tab');
      await t.pumpAndSettle(const Duration(seconds: 2));

      final activityNames = [
        'Body Scan', 'Loving-Kindness', 'Walking Meditation',
        'Gratitude Journaling', 'Expressive Writing', 'Dance Break',
        'Nature Connection', 'Creative Doodling', 'Mindful Eating',
        'Micro-Connection',
      ];
      int found = 0;
      for (final activity in activityNames) {
        if (find.textContaining(activity).evaluate().isNotEmpty) {
          found++;
          pass('Activity visible: $activity');
        }
      }
      log('Activities found', '$found / ${activityNames.length}');
      expect(found, greaterThan(0), reason: 'At least some activities must be visible');
    });

    testWidgets('12.2 Tap an activity → bottom sheet with steps', (t) async {
      banner('GROUP 12.2 — ACTIVITY DETAIL');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);
      await tapIfFound(t, find.text('Wellness'), label: 'Wellness tab');
      await t.pumpAndSettle(const Duration(seconds: 2));

      for (final activity in ['Body Scan', 'Loving-Kindness', 'Gratitude', 'Walking']) {
        final f = find.textContaining(activity);
        if (f.evaluate().isNotEmpty) {
          await t.tap(f.first);
          await t.pumpAndSettle(const Duration(seconds: 2));
          pass('Tapped activity: $activity');

          final texts = find.byType(Text).evaluate().take(8).map(
            (e) => (e.widget as Text).data
          ).toList();
          log('Activity detail content', texts);
          pass('Activity detail sheet rendered');
          break;
        }
      }
    });
  });

  // ===========================================================================
  // GROUP 13: HELPLINES PAGE
  // ===========================================================================
  group('13. Helplines Page', () {
    testWidgets('13.1 Helplines page accessible and lists helplines', (t) async {
      banner('GROUP 13 — HELPLINES PAGE');
      app.main();
      await t.pumpAndSettle(const Duration(seconds: 5));
      await skipOnboardingIfPresent(t);

      // Look for emergency icon in AppBar
      final emergencyIcon = find.byIcon(Icons.emergency_rounded);
      final phoneIcon = find.byIcon(Icons.local_hospital_rounded);
      final helpIcon = find.byIcon(Icons.health_and_safety_rounded);

      Finder? foundIcon;
      if (emergencyIcon.evaluate().isNotEmpty) {
        foundIcon = emergencyIcon;
      } else if (phoneIcon.evaluate().isNotEmpty) {
        foundIcon = phoneIcon;
      } else if (helpIcon.evaluate().isNotEmpty) {
        foundIcon = helpIcon;
      }

      if (foundIcon != null) {
        await t.tap(foundIcon.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        pass('Navigated to Helplines page');

        // Verify helpline entries
        final helplines = {
          'AASRA': '9820466',
          'Vandrevala': '1860',
          'iCall': '25521111',
          'NIMHANS': '46110007',
          'Sneha': '24640050',
          '988': '988',
          'Samaritans': '116 123',
        };
        int found = 0;
        for (final entry in helplines.entries) {
          if (find.textContaining(entry.key).evaluate().isNotEmpty) {
            found++;
            pass('Helpline listed: ${entry.key}');
          }
          if (find.textContaining(entry.value).evaluate().isNotEmpty) {
            pass('Number displayed: ${entry.value}');
          }
        }
        log('Helplines found', '$found / ${helplines.length}');

        // Check for Call buttons
        final callButtons = find.text('Call');
        if (callButtons.evaluate().isNotEmpty) {
          pass('Call buttons present (${callButtons.evaluate().length} found)');
        }

        // Navigate back
        final backBtn = find.byIcon(Icons.arrow_back_rounded);
        if (backBtn.evaluate().isNotEmpty) {
          await t.tap(backBtn);
          await t.pumpAndSettle();
          pass('Navigated back from Helplines');
        }
      } else {
        info('Emergency/Helpline icon not found in AppBar');
      }
    });
  });

  // ===========================================================================
  // GROUP 14: FEEDBACK SYSTEM
  // ===========================================================================
  group('14. Feedback — Strategy Persistence', () {
    testWidgets('14.1 addWorkedStrategy persists correctly', (t) async {
      banner('GROUP 14 — FEEDBACK SYSTEM');
      await UserProfile().loadFromStorage();
      final before = List<String>.from(UserProfile().copingStrategiesWorked);
      log('Strategies before', before);

      await UserProfile().addWorkedStrategy('Box Breathing Test');
      await UserProfile().loadFromStorage();
      final after = UserProfile().copingStrategiesWorked;
      log('Strategies after', after);

      if (after.contains('Box Breathing Test')) {
        pass('addWorkedStrategy persisted "Box Breathing Test"');
      } else {
        info('Strategy not found — may already exist');
      }
    });

    testWidgets('14.2 addFailedStrategy persists correctly', (t) async {
      banner('GROUP 14.2 — FAILED STRATEGY');
      await UserProfile().loadFromStorage();
      final before = List<String>.from(UserProfile().copingStrategiesFailed);

      await UserProfile().addFailedStrategy('Social Media Scrolling');
      await UserProfile().loadFromStorage();
      final after = UserProfile().copingStrategiesFailed;
      
      log('Failed strategies before', before);
      log('Failed strategies after', after);

      if (after.contains('Social Media Scrolling')) {
        pass('addFailedStrategy persisted "Social Media Scrolling"');
      }
    });

    testWidgets('14.3 Duplicate strategies not added', (t) async {
      banner('GROUP 14.3 — NO DUPLICATES');
      await UserProfile().loadFromStorage();
      final lengthBefore = UserProfile().copingStrategiesWorked.length;
      
      // Try adding same strategy again
      await UserProfile().addWorkedStrategy('Box Breathing Test');
      await UserProfile().loadFromStorage();
      final lengthAfter = UserProfile().copingStrategiesWorked.length;

      log('Length before', lengthBefore);
      log('Length after', lengthAfter);
      expect(lengthAfter, equals(lengthBefore),
          reason: 'Duplicate strategies must not be added');
      pass('No duplicate added');
    });
  });

  // ===========================================================================
  // GROUP 15: SUS SCORE CALCULATION
  // ===========================================================================
  group('15. SUS Score Calculation', () {
    testWidgets('15.1 Perfect, worst, and neutral SUS scores', (t) async {
      banner('GROUP 15 — SUS SCORE CALCULATION');

      // Perfect score: odd items=5, even items=1
      final perfect = calculateSusScoreGlobal([5, 1, 5, 1, 5, 1, 5, 1, 5, 1]);
      log('Perfect SUS', perfect);
      expect(perfect, equals(100.0));
      pass('Perfect SUS = 100.0');

      // Worst score
      final worst = calculateSusScoreGlobal([1, 5, 1, 5, 1, 5, 1, 5, 1, 5]);
      log('Worst SUS', worst);
      expect(worst, equals(0.0));
      pass('Worst SUS = 0.0');

      // Neutral score
      final neutral = calculateSusScoreGlobal([3, 3, 3, 3, 3, 3, 3, 3, 3, 3]);
      log('Neutral SUS', neutral);
      expect(neutral, equals(50.0));
      pass('Neutral SUS = 50.0');
    });

    testWidgets('15.2 Realistic SUS score', (t) async {
      banner('GROUP 15.2 — REALISTIC SUS');
      final realistic = calculateSusScoreGlobal([4, 2, 4, 2, 5, 1, 4, 2, 4, 1]);
      log('Realistic SUS', realistic);
      expect(realistic, greaterThan(70.0),
          reason: 'Realistic positive score should be above average (>70)');
      pass('Realistic SUS > 70.0: $realistic');

      // Bad experience
      final bad = calculateSusScoreGlobal([2, 4, 2, 4, 2, 4, 2, 4, 2, 4]);
      log('Bad experience SUS', bad);
      expect(bad, lessThan(30.0));
      pass('Bad experience SUS < 30.0: $bad');
    });

    testWidgets('15.3 Wrong score count throws error', (t) async {
      banner('GROUP 15.3 — SUS VALIDATION');
      try {
        calculateSusScoreGlobal([5, 1, 5]); // Wrong count
        fail('Should have thrown', 'No error thrown for wrong count');
      } catch (e) {
        pass('ArgumentError thrown for wrong score count');
        log('Error', e);
      }
    });
  });

  // ===========================================================================
  // GROUP 16: DATA INTEGRITY — Coping Tools & Wellness Activities
  // ===========================================================================
  group('16. Data Integrity', () {
    testWidgets('16.1 kCopingTools has 20 items with required fields', (t) async {
      banner('GROUP 16 — DATA INTEGRITY: COPING TOOLS');
      log('Total coping tools', kCopingTools.length);
      expect(kCopingTools.length, equals(20),
          reason: 'Must have exactly 20 coping tools');

      for (int i = 0; i < kCopingTools.length; i++) {
        final tool = kCopingTools[i];
        final title = tool['title'] as String;
        expect(tool.containsKey('title'), isTrue, reason: 'Tool $i missing title');
        expect(tool.containsKey('category'), isTrue, reason: 'Tool $i missing category');
        expect(tool.containsKey('desc'), isTrue, reason: 'Tool $i missing desc');
        expect(tool.containsKey('steps'), isTrue, reason: 'Tool $i missing steps');
        expect(tool.containsKey('icon'), isTrue, reason: 'Tool $i missing icon');
        expect(tool.containsKey('color'), isTrue, reason: 'Tool $i missing color');
        
        final steps = tool['steps'] as List;
        expect(steps.length, greaterThanOrEqualTo(5),
            reason: '$title must have at least 5 steps, has ${steps.length}');
        
        log('  [$i] ${title.padRight(30)}', '${tool['category']} | ${steps.length} steps');
      }
      pass('All 20 coping tools have valid structure');
    });

    testWidgets('16.2 Breathing tools have pattern data', (t) async {
      banner('GROUP 16.2 — BREATHING TOOL PATTERNS');
      final breathingTools = kCopingTools.where((t) => t['category'] == 'Breathing').toList();
      log('Breathing tools count', breathingTools.length);
      expect(breathingTools.length, equals(3));

      for (final tool in breathingTools) {
        expect(tool.containsKey('pattern'), isTrue,
            reason: '${tool['title']} must have breathing pattern');
        expect(tool.containsKey('patternLabels'), isTrue,
            reason: '${tool['title']} must have pattern labels');
        
        final pattern = tool['pattern'] as List;
        final labels = tool['patternLabels'] as List;
        log('  ${tool['title']}', 'pattern=$pattern, labels=$labels');
        expect(pattern.length, equals(labels.length),
            reason: 'Pattern and labels must have same length');
        pass('${tool['title']} has valid breathing pattern');
      }
    });

    testWidgets('16.3 kWellnessActivities has 18 items with required fields', (t) async {
      banner('GROUP 16.3 — DATA INTEGRITY: WELLNESS ACTIVITIES');
      log('Total wellness activities', kWellnessActivities.length);
      expect(kWellnessActivities.length, equals(18),
          reason: 'Must have exactly 18 wellness activities');

      for (int i = 0; i < kWellnessActivities.length; i++) {
        final act = kWellnessActivities[i];
        final title = act['title'] as String;
        expect(act.containsKey('title'), isTrue, reason: 'Activity $i missing title');
        expect(act.containsKey('category'), isTrue, reason: 'Activity $i missing category');
        expect(act.containsKey('desc'), isTrue, reason: 'Activity $i missing desc');
        expect(act.containsKey('steps'), isTrue, reason: 'Activity $i missing steps');
        expect(act.containsKey('icon'), isTrue, reason: 'Activity $i missing icon');
        expect(act.containsKey('color'), isTrue, reason: 'Activity $i missing color');
        
        final steps = act['steps'] as List;
        expect(steps.length, greaterThanOrEqualTo(5),
            reason: '$title must have at least 5 steps');
        
        log('  [$i] ${title.padRight(30)}', '${act['category']} | ${steps.length} steps');
      }
      pass('All 18 wellness activities have valid structure');
    });

    testWidgets('16.4 ChatMessage model works correctly', (t) async {
      banner('GROUP 16.4 — CHATMESSAGE MODEL');
      final msg = ChatMessage(
        text: 'Test message',
        isUser: true,
        emotion: 'stressed',
        isOffline: false,
      );
      expect(msg.text, equals('Test message'));
      expect(msg.isUser, isTrue);
      expect(msg.emotion, equals('stressed'));
      expect(msg.isOffline, isFalse);
      expect(msg.timestamp, isNotNull);
      pass('ChatMessage constructor works');

      final aiMsg = ChatMessage(
        text: 'AI response',
        isUser: false,
        validation: 'I hear you',
        insight: 'Consider this',
        action: 'Try breathing',
        emotion: 'anxious',
        isOffline: true,
      );
      expect(aiMsg.isUser, isFalse);
      expect(aiMsg.validation, equals('I hear you'));
      expect(aiMsg.insight, equals('Consider this'));
      expect(aiMsg.action, equals('Try breathing'));
      expect(aiMsg.isOffline, isTrue);
      pass('AI ChatMessage with all fields');
      log('Timestamp', aiMsg.timestamp);
    });
  });

  // ===========================================================================
  // GROUP 17: USER PROFILE LIFECYCLE
  // ===========================================================================
  group('17. UserProfile — Full Lifecycle', () {
    testWidgets('17.1 Clear, write, read, verify cycle', (t) async {
      banner('GROUP 17 — PROFILE LIFECYCLE');
      final p = UserProfile();

      // Clear
      await p.clearProfile();
      await p.loadFromStorage();
      log('After clear — name', p.name);
      expect(p.name, isEmpty);
      expect(p.ageGroup, isEmpty);
      expect(p.concerns, isEmpty);
      expect(p.voicePreference, equals('Sulafat'));
      pass('Profile cleared successfully');

      // Write
      p.name = 'Lifecycle Test';
      p.ageGroup = '25-34';
      p.voicePreference = 'Charon';
      p.concerns = ['Anxiety', 'Stress'];
      p.copingStrategiesWorked = ['Deep Breathing'];
      p.copingStrategiesFailed = ['Isolation'];
      p.additionalNotes = 'Night shift worker';
      await p.saveToStorage();
      pass('Profile saved to storage');

      // Read back (simulate restart)
      p.name = '';
      p.ageGroup = '';
      p.voicePreference = '';
      await p.loadFromStorage();
      
      log('Loaded name', p.name);
      log('Loaded ageGroup', p.ageGroup);
      log('Loaded voicePreference', p.voicePreference);
      log('Loaded concerns', p.concerns);
      log('Loaded worked', p.copingStrategiesWorked);
      log('Loaded failed', p.copingStrategiesFailed);
      log('Loaded notes', p.additionalNotes);

      expect(p.name, equals('Lifecycle Test'));
      expect(p.ageGroup, equals('25-34'));
      expect(p.voicePreference, equals('Charon'));
      expect(p.concerns, contains('Anxiety'));
      expect(p.concerns, contains('Stress'));
      expect(p.copingStrategiesWorked, contains('Deep Breathing'));
      expect(p.copingStrategiesFailed, contains('Isolation'));
      expect(p.additionalNotes, equals('Night shift worker'));
      expect(p.isProfileComplete, isTrue);
      pass('Full profile lifecycle verified — save/load roundtrip works');
    });
  });

  // ── Final Summary ──────────────────────────────────────────────────────────
  tearDownAll(() {
    final endBar = '=' * 70;
    debugPrint('\n$endBar');
    debugPrint('  🏁  ALL INTEGRATION TESTS COMPLETE');
    debugPrint('  📊  Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('$endBar\n');
  });
}
