// =====================================================================
//  AUTH SERVICE — Google Sign-In + Firebase + Firestore Sync
//  Singleton that manages authentication and cloud data persistence.
//  Offline-first: app works fully without sign-in.
// =====================================================================

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

class AuthService {
  // ── Singleton ──
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ── State ──
  bool _firebaseReady = false;
  User? _firebaseUser;

  // ── Getters ──
  bool get isSignedIn => _firebaseUser != null;
  bool get firebaseReady => _firebaseReady;
  User? get currentUser => _firebaseUser;
  String? get userId => _firebaseUser?.uid;
  String? get displayName => _firebaseUser?.displayName;
  String? get email => _firebaseUser?.email;
  String? get photoUrl => _firebaseUser?.photoURL;

  // Stream for auth state changes
  Stream<User?> get authStateChanges =>
      _firebaseReady ? FirebaseAuth.instance.authStateChanges() : const Stream.empty();

  // ── Token Retrieval ──
  Future<String?> getIdToken() async {
    if (_firebaseUser != null) {
      try {
        return await _firebaseUser!.getIdToken();
      } catch (e) {
        debugPrint('Failed to get ID token: $e');
      }
    }
    return null;
  }

  // ── Initialize Firebase (with timeout to prevent hang) ──
  Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('Firebase init timed out');
      });
      _firebaseReady = true;
      _firebaseUser = FirebaseAuth.instance.currentUser;
      
      FirebaseAuth.instance.authStateChanges().listen((user) {
        _firebaseUser = user;
      });
      
      debugPrint('✅ Firebase initialized — user: ${_firebaseUser?.displayName ?? "none"}');
    } catch (e) {
      _firebaseReady = false;
      debugPrint('⚠️ Firebase not available: $e');
      debugPrint('   App will run in local-only mode (SharedPreferences).');
    }
  }

  // ── Google Sign-In via Firebase Auth (no google_sign_in package needed) ──
  // Uses FirebaseAuth.signInWithProvider which opens ASWebAuthenticationSession
  // on iOS — no separate iOS OAuth client or GoogleService-Info.plist CLIENT_ID required.
  Future<User?> signInWithGoogle() async {
    if (!_firebaseReady) {
      debugPrint('❌ Firebase not ready — cannot sign in');
      return null;
    }

    try {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');

      UserCredential userCredential;
      if (kIsWeb) {
        userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        userCredential = await FirebaseAuth.instance.signInWithProvider(provider);
      }

      _firebaseUser = userCredential.user;
      debugPrint('✅ Signed in as: ${_firebaseUser?.displayName} (${_firebaseUser?.email})');
      return _firebaseUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'cancelled-popup-request' || e.code == 'web-context-cancelled') {
        debugPrint('ℹ️ Google Sign-In cancelled by user');
      } else {
        debugPrint('❌ Google Sign-In error [${e.code}]: ${e.message}');
      }
      return null;
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      return null;
    }
  }

  // ── Sign Out ──
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      _firebaseUser = null;
      debugPrint('✅ Signed out');
    } catch (e) {
      debugPrint('❌ Sign-out error: $e');
    }
  }

  // ── Firestore References ──
  DocumentReference? get _userDoc {
    if (!isSignedIn) return null;
    return FirebaseFirestore.instance.collection('users').doc(userId);
  }

  CollectionReference? get _sessionsCol {
    return _userDoc?.collection('sessions');
  }

  // ── Profile Sync: Upload to Firestore ──
  Future<void> syncProfileToCloud({
    required String name,
    required String ageGroup,
    required String voicePreference,
    required List<String> concerns,
    required List<String> copingStrategiesWorked,
    required List<String> copingStrategiesFailed,
    required String additionalNotes,
  }) async {
    if (!isSignedIn || _userDoc == null) return;

    try {
      String platform = 'unknown';
      if (kIsWeb) {
        platform = 'web';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.iOS: platform = 'ios';
          case TargetPlatform.android: platform = 'android';
          case TargetPlatform.macOS: platform = 'macos';
          case TargetPlatform.linux: platform = 'linux';
          case TargetPlatform.windows: platform = 'windows';
          case TargetPlatform.fuchsia: platform = 'fuchsia';
        }
      }
      
      final Map<String, dynamic> profileData = {
        'name': name,
        'ageGroup': ageGroup,
        'voicePreference': voicePreference,
        'concerns': concerns,
        'copingStrategiesWorked': copingStrategiesWorked,
        'copingStrategiesFailed': copingStrategiesFailed,
        'additionalNotes': additionalNotes,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'platform': platform,
        'lastActiveAt': FieldValue.serverTimestamp(),
      };

      await _userDoc!.set(profileData, SetOptions(merge: true));
      debugPrint('☁️ Profile synced to Firestore');
    } catch (e) {
      debugPrint('❌ Profile sync error: $e');
    }
  }

  // ── Profile Sync: Download from Firestore ──
  Future<Map<String, dynamic>?> loadProfileFromCloud() async {
    if (!isSignedIn || _userDoc == null) return null;

    try {
      final doc = await _userDoc!.get();
      if (doc.exists) {
        debugPrint('☁️ Profile loaded from Firestore');
        return doc.data() as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('❌ Profile load error: $e');
    }
    return null;
  }

  // ── Session: Save chat session ──
  Future<void> saveSession({
    required String sessionId,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> emotionTimeline,
    required int turnCount,
    required bool crisisDetected,
    DateTime? startedAt,
  }) async {
    if (!isSignedIn || _sessionsCol == null) return;

    try {
      await _sessionsCol!.doc(sessionId).set({
        'startedAt': startedAt ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'messages': messages,
        'emotionTimeline': emotionTimeline,
        'turnCount': turnCount,
        'crisisDetected': crisisDetected,
      }, SetOptions(merge: true));
      debugPrint('☁️ Session "$sessionId" saved (${messages.length} messages)');
    } catch (e) {
      debugPrint('❌ Session save error: $e');
    }
  }

  // ── Session: Load past sessions ──
  Future<List<Map<String, dynamic>>> loadSessions({int limit = 20}) async {
    if (!isSignedIn || _sessionsCol == null) return [];

    try {
      final query = await _sessionsCol!
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();
      return query.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
    } catch (e) {
      debugPrint('❌ Session load error: $e');
      return [];
    }
  }

  // ── Update last active timestamp ──
  Future<void> updateLastActive() async {
    if (!isSignedIn || _userDoc == null) return;
    try {
      await _userDoc!.update({'lastActiveAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  // ── Analytics: Log events to Firestore admin_events ──
  Future<void> logAnalyticsEvent(String eventType, [Map<String, dynamic>? data]) async {
    if (!isSignedIn || !_firebaseReady) return;
    try {
      String platform = 'unknown';
      if (kIsWeb) {
        platform = 'web';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.iOS: platform = 'ios';
          case TargetPlatform.android: platform = 'android';
          case TargetPlatform.macOS: platform = 'macos';
          case TargetPlatform.linux: platform = 'linux';
          case TargetPlatform.windows: platform = 'windows';
          case TargetPlatform.fuchsia: platform = 'fuchsia';
        }
      }
      await FirebaseFirestore.instance.collection('admin_events').add({
        'type': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': userId ?? '',
        'platform': platform,
        ...?data,
      });
    } catch (e) {
      debugPrint('Analytics log error: $e');
    }
  }
}
