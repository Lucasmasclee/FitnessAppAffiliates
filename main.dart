import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_navigator_observer.dart';
import 'functionaliteit/rest_timer_service.dart';
import 'functionaliteit/subscription_service.dart';
import 'functionaliteit/supabase_service.dart';
import 'functionaliteit/workout_storage.dart';
import 'referrer_android.dart' if (dart.library.html) 'referrer_stub.dart';
import 'screens/survey.dart';
import 'screens/weekplanning.dart';
import 'widgets/rest_timer_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initSupabase();
  await SubscriptionService.instance.init();
  await AffiliateTracker.instance.init();
  runApp(const MyApp());
}

Future<void> _initSupabase() async {
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint(
        'Supabase niet geïnitialiseerd: SUPABASE_URL of SUPABASE_ANON_KEY is leeg.');
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  debugPrint('Supabase succesvol geïnitialiseerd.');
}

class AffiliateTracker {
  AffiliateTracker._internal();
  static final AffiliateTracker instance = AffiliateTracker._internal();

  final String _affiliateDownloadUrl =
      const String.fromEnvironment('AFFILIATE_DOWNLOAD_URL');

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _tryCaptureAndReportDownload();
  }

  static final RegExp _affiliateCodeRegex = RegExp(r'^[a-z0-9]{4,16}$');

  String? _normalizeCandidate(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    final cleaned = v.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (_affiliateCodeRegex.hasMatch(cleaned)) return cleaned;
    return null;
  }

  String? _extractAffiliateCodeFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final t = text.trim();

    // 1) Query-style: affiliate_code=xxxx or code=xxxx
    final mQuery = RegExp(r'(?:affiliate_code|code)=([a-z0-9]{4,16})',
            caseSensitive: false)
        .firstMatch(t);
    if (mQuery != null) return _normalizeCandidate(mQuery.group(1));

    // 2) Path-style: https://liftbetter.cloud/{code}
    final mPath = RegExp(r'/(?:[a-z0-9]{4,16})(?:\b|/|\?|#)',
            caseSensitive: false)
        .firstMatch(t);
    if (mPath != null) {
      final seg = mPath.group(0)?.replaceAll(RegExp(r'[^a-z0-9]'), '');
      return _normalizeCandidate(seg);
    }

    // 3) Raw code pasted
    return _normalizeCandidate(t);
  }

  Future<void> _tryCaptureAndReportDownload() async {
    final prefs = await SharedPreferences.getInstance();

    // If we already reported a download once, don't do anything.
    if (prefs.getBool('affiliate_download_reported') ?? false) {
      return;
    }

    String? affiliateCode = prefs.getString('affiliate_attributed_code');
    affiliateCode = _normalizeCandidate(affiliateCode);

    if (affiliateCode == null) {
      if (Platform.isAndroid) {
        final raw = await getInstallReferrerString();
        affiliateCode = _extractAffiliateCodeFromText(raw);
        if (kDebugMode) {
          debugPrint('Install referrer raw: $raw');
          debugPrint('Parsed affiliate code from referrer: $affiliateCode');
        }
      } else if (Platform.isIOS) {
        // iOS has no install referrer. Best-effort: read clipboard once.
        try {
          final data = await Clipboard.getData('text/plain');
          affiliateCode = _extractAffiliateCodeFromText(data?.text);
          if (kDebugMode) {
            debugPrint('Clipboard text parsed affiliate code: $affiliateCode');
          }
        } catch (_) {
          // ignore
        }
      }
    }

    if (affiliateCode == null) return;

    await prefs.setString('affiliate_attributed_code', affiliateCode);
    await _reportDownloadToSupabase(affiliateCode);
  }

  Future<void> _reportDownloadToSupabase(String affiliateCode) async {
    if (_affiliateDownloadUrl.isEmpty) {
      debugPrint(
          'AFFILIATE_DOWNLOAD_URL is empty, skipping report for $affiliateCode');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('affiliate_download_reported') ?? false) {
      debugPrint('Affiliate download already reported');
      return;
    }

    final platform = Platform.isIOS
        ? 'ios'
        : (Platform.isAndroid ? 'android' : 'unknown');
    if (platform == 'unknown') {
      debugPrint(
          'Unknown platform, not reporting affiliate download for $affiliateCode');
      return;
    }

    try {
      debugPrint(
          'Posting affiliate download to $_affiliateDownloadUrl with code=$affiliateCode, platform=$platform');

      final response = await http.post(
        Uri.parse(_affiliateDownloadUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body:
            '{"affiliate_code": "$affiliateCode", "platform": "$platform"}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setBool('affiliate_download_reported', true);
        debugPrint(
            'Successfully reported affiliate download for $affiliateCode (status ${response.statusCode})');
      } else {
        debugPrint(
            'Failed to report affiliate download for $affiliateCode. Status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e, stack) {
      debugPrint(
          'Network error while reporting affiliate download for $affiliateCode: $e\n$stack');
    }
  }
}

/// Bepaalt bij het opstarten waar de gebruiker heen moet.
/// - Nieuwe gebruikers (geen abonnement / geen workout) -> Survey
/// - Gebruikers met abonnement én een geldige workout -> Weekplanning
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  @override
  void initState() {
    super.initState();
    _decideStartRoute();
  }

  Future<void> _decideStartRoute() async {
    final hasSub = SubscriptionService.instance.hasActiveSubscription;
    final hasWorkout = await hasValidWorkoutSaved();

    if (!mounted) return;

    if (hasSub && hasWorkout) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WeekplanningScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SurveyScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    RestTimerService.instance.ensureInitialized();
    RestTimerService.instance.addListener(_onTimerUpdate);

    // Voorbeeld: affiliate_code voor een specifieke gebruiker ophalen en printen.
    // Pas het e‑mailadres en eventueel de tabelnaam aan.
    SupabaseService.instance
        .printAffiliateCodeForEmail('test@test.test', tableName: 'affiliates');
  }

  void _onTimerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RestTimerService.instance.removeListener(_onTimerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      navigatorObservers: [appRouteObserver],
      home: const RootScreen(),
      routes: {
        '/weekplanning': (_) => const WeekplanningScreen(),
      },
      builder: (context, child) {
        return Stack(
          fit: StackFit.passthrough,
          children: [
            if (child != null) child,
            const Positioned.fill(
              child: RestTimerOverlay(),
            ),
          ],
        );
      },
    );
  }
}
