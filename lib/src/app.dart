import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import 'common/constants.dart';
import 'data/models/user_profile.dart';
import 'features/auth/auth_screens.dart';
import 'features/dashboard/dashboard_screen.dart';

class VoiceMindApp extends StatelessWidget {
  const VoiceMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VoiceMind',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFAF8F5),
          primaryColor: kBrandPrimary,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kBrandPrimary,
            primary: kBrandPrimary,
            secondary: const Color(0xFFC9A88B),
            tertiary: const Color(0xFFA8B5A0),
            surface: Colors.white,
            onSurface: const Color(0xFF191918),
          ),
          textTheme: GoogleFonts.interTextTheme().copyWith(
            bodyLarge: GoogleFonts.inter(color: const Color(0xFF404040), fontSize: 16, height: 1.6),
            bodyMedium: GoogleFonts.inter(color: const Color(0xFF6B6B66), fontSize: 14, height: 1.5),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFFFAF8F5),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF191918)),
            iconTheme: const IconThemeData(color: Color(0xFF6B6B66), size: 22),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            ),
          ),
        ),
        home: const AppBootstrap(),
      ),
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  final _auth = AuthService();
  final _profile = UserProfile();
  bool _ready = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _auth.init();
    await _profile.loadFromStorage();
    final prefs = await SharedPreferences.getInstance();
    _showOnboarding = !(prefs.getBool('has_seen_onboarding') ?? false);
    if (mounted) {
      setState(() => _ready = true);
    }
  }


  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) {
      setState(() => _showOnboarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF8F5),
        body: Center(child: CircularProgressIndicator(color: kBrandPrimary)),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }

    return const MainDashboard();
  }
}
