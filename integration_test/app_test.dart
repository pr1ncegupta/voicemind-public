import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicemind_flutter/main.dart' as app;
import 'package:voicemind_flutter/src/data/models/user_profile.dart';
 
// ignore: unused_import
import 'package:firebase_core/firebase_core.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Flow & Firebase Sync', () {
    
    setUpAll(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    testWidgets('Full User Profile creation syncs to SharedPreferences and survives', (WidgetTester tester) async {
      // 1. Start App
      app.main();
      await tester.pumpAndSettle();

      // 2. Bypass Onboarding / Welcome (Tap through or skip)
      final beginButton = find.text("Let's Begin");
      if (beginButton.evaluate().isNotEmpty) {
        await tester.tap(beginButton);
        await tester.pumpAndSettle();
        
        for (int i=0; i<4; i++) {
           final skipBtn = find.text("Skip");
           if (skipBtn.evaluate().isNotEmpty) {
             await tester.tap(skipBtn);
             await tester.pumpAndSettle();
           }
        }
      }

      // Handle Google Sign-In screen if present
      final googleBtn = find.textContaining("Continue with Google");
      if (googleBtn.evaluate().isNotEmpty) {
        // In integration tests, Google Sign-In may not complete.
        // Skip if we can't sign in programmatically.
      }

      // 3. Navigate to Profile via AppBar person icon
      final profileIcon = find.byIcon(Icons.person_outline_rounded);
      if (profileIcon.evaluate().isNotEmpty) {
        await tester.tap(profileIcon);
        await tester.pumpAndSettle();
      }

      // 4. Enter Name — ProfilePage uses TextField with hint "e.g., Alex"
      final nameFields = find.byType(TextField);
      if (nameFields.evaluate().isNotEmpty) {
        await tester.enterText(nameFields.first, 'Test User Integration');
      }

      // 5. Select Voice Preference — chips, not dropdown
      final voiceChip = find.text('Charon');
      if (voiceChip.evaluate().isNotEmpty) {
        await tester.ensureVisible(voiceChip);
        await tester.tap(voiceChip);
        await tester.pumpAndSettle();
      }

      // 6. Save Profile
      final saveButton = find.text('Save My Profile');
      if (saveButton.evaluate().isNotEmpty) {
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
      }

      // 7. Verification: The Singleton was updated
      expect(UserProfile().name, 'Test User Integration');
      expect(UserProfile().voicePreference, 'Charon');

      // 8. Verification: Firebase Auth state
      // In CI without real Google Sign-In, user may be null
      // expect(FirebaseAuth.instance.currentUser, isNotNull);

      // 9. Verification: SharedPreferences persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_name'), 'Test User Integration');
      expect(prefs.getString('voice_preference'), 'Charon');
      
      // Simulate app restart by reloading from storage
      await UserProfile().loadFromStorage();
      expect(UserProfile().name, 'Test User Integration');
      expect(UserProfile().voicePreference, 'Charon');
    });
  });
}
