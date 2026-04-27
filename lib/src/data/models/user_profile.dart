import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth_service.dart';

// =====================================================================
//  USER PROFILE (Singleton + SharedPreferences)
// =====================================================================

/// Backward-compatible voice list stored in older profile records.
/// The app now enforces one empathetic default voice for consistent UX.
const Set<String> kCompanionVoiceNames = {
  'Zephyr', 'Puck', 'Charon', 'Kore', 'Fenrir', 'Leda', 'Orus', 'Aoede',
  'Callirrhoe', 'Autonoe', 'Enceladus', 'Iapetus', 'Umbriel', 'Algieba',
  'Despina', 'Erinome', 'Algenib', 'Rasalgethi', 'Laomedeia', 'Achernar',
  'Alnilam', 'Schedar', 'Gacrux', 'Pulcherrima', 'Achird', 'Zubenelgenubi',
  'Vindemiatrix', 'Sadachbia', 'Sadaltager', 'Sulafat', 'Dione',
};

const String kDefaultCompanionVoice = 'Sulafat';

class UserProfile {
  static final UserProfile _instance = UserProfile._internal();
  factory UserProfile() => _instance;
  UserProfile._internal();

  String name = "";
  String ageGroup = "";
  String voicePreference = kDefaultCompanionVoice;
  List<String> concerns = [];
  List<String> copingStrategiesWorked = [];
  List<String> copingStrategiesFailed = [];
  String additionalNotes = "";

  bool get isProfileComplete => name.isNotEmpty;

  /// Canonical companion voice name used by the app.
  String get companionVoiceName {
    // UX decision: keep one default empathetic voice, no in-app selector.
    return kDefaultCompanionVoice;
  }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    name = prefs.getString('user_name') ?? "";
    ageGroup = prefs.getString('age_group') ?? "";
    // Ignore previously saved custom values and normalize to default voice.
    voicePreference = kDefaultCompanionVoice;
    concerns = prefs.getStringList('concerns') ?? [];
    copingStrategiesWorked = prefs.getStringList('strategies_worked') ?? [];
    copingStrategiesFailed = prefs.getStringList('strategies_failed') ?? [];
    additionalNotes = prefs.getString('additional_notes') ?? "";
  }

  Future<void> saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('age_group', ageGroup);
    // Persist enforced default voice for backward compatibility with old readers.
    voicePreference = kDefaultCompanionVoice;
    await prefs.setString('voice_preference', voicePreference);
    await prefs.setStringList('concerns', concerns);
    await prefs.setStringList('strategies_worked', copingStrategiesWorked);
    await prefs.setStringList('strategies_failed', copingStrategiesFailed);
    await prefs.setString('additional_notes', additionalNotes);
  }

  /// Save locally AND sync to Firestore if signed in.
  Future<void> saveAndSync() async {
    await saveToStorage();
    final auth = AuthService();
    if (auth.isSignedIn) {
      await auth.syncProfileToCloud(
        name: name,
        ageGroup: ageGroup,
        voicePreference: voicePreference,
        concerns: concerns,
        copingStrategiesWorked: copingStrategiesWorked,
        copingStrategiesFailed: copingStrategiesFailed,
        additionalNotes: additionalNotes,
      );
    }
  }

  /// After sign-in, pull cloud profile and merge (cloud wins if non-empty).
  Future<void> loadFromCloudAndMerge() async {
    final auth = AuthService();
    if (!auth.isSignedIn) return;
    final cloud = await auth.loadProfileFromCloud();
    if (cloud == null) return;
    if ((cloud['name'] ?? '').toString().isNotEmpty) name = cloud['name'];
    if ((cloud['ageGroup'] ?? '').toString().isNotEmpty) ageGroup = cloud['ageGroup'];
    // Keep local voice fixed to default, even if old cloud docs have custom values.
    voicePreference = kDefaultCompanionVoice;
    if ((cloud['concerns'] as List?)?.isNotEmpty ?? false) {
      concerns = List<String>.from(cloud['concerns']);
    }
    if ((cloud['copingStrategiesWorked'] as List?)?.isNotEmpty ?? false) {
      copingStrategiesWorked = List<String>.from(cloud['copingStrategiesWorked']);
    }
    if ((cloud['copingStrategiesFailed'] as List?)?.isNotEmpty ?? false) {
      copingStrategiesFailed = List<String>.from(cloud['copingStrategiesFailed']);
    }
    if ((cloud['additionalNotes'] ?? '').toString().isNotEmpty) {
      additionalNotes = cloud['additionalNotes'];
    }
    await saveToStorage();
  }

  Future<void> addWorkedStrategy(String s) async {
    if (s.isNotEmpty && !copingStrategiesWorked.contains(s)) {
      copingStrategiesWorked.add(s);
      await saveAndSync();
    }
  }

  Future<void> addFailedStrategy(String s) async {
    if (s.isNotEmpty && !copingStrategiesFailed.contains(s)) {
      copingStrategiesFailed.add(s);
      await saveAndSync();
    }
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    name = ageGroup = additionalNotes = "";
    voicePreference = kDefaultCompanionVoice;
    concerns = [];
    copingStrategiesWorked = [];
    copingStrategiesFailed = [];
  }
}
