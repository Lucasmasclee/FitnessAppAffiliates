import 'dart:io' show Platform;

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_navigator_observer.dart';
import 'functionaliteit/rest_timer_service.dart';
import 'screens/start_screen.dart';
import 'screens/weekplanning.dart';
import 'widgets/rest_timer_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AffiliateTracker.instance.init();
  runApp(const MyApp());
}

class AffiliateTracker {
  AffiliateTracker._internal();
  static final AffiliateTracker instance = AffiliateTracker._internal();

  final String _afDevKey = const String.fromEnvironment('APPSFLYER_DEV_KEY');
  final String _afAppId = const String.fromEnvironment('APPSFLYER_APP_ID');
  final String _affiliateDownloadUrl =
      const String.fromEnvironment('AFFILIATE_DOWNLOAD_URL');

  AppsflyerSdk? _sdk;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (_afDevKey.isEmpty) {
      return;
    }

    final options = AppsFlyerOptions(
      afDevKey: _afDevKey,
      appId: _afAppId,
      showDebug: !kReleaseMode,
    );

    final sdk = AppsflyerSdk(options);

    await sdk.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
    );

    _sdk = sdk;
    _initialized = true;

    _listenToConversionData();
  }

  void _listenToConversionData() {
    final sdk = _sdk;
    if (sdk == null) return;

    sdk.onInstallConversionData((res) async {
      try {
        debugPrint('AppsFlyer onInstallConversionData raw: $res');

        // Different SDK versions use either "data" or "payload"
        final dynamic rawData = res['data'] ?? res['payload'];
        if (rawData is! Map) {
          debugPrint('AppsFlyer conversion data is not a Map: $rawData');
          return;
        }

        final data = Map<String, dynamic>.from(rawData);
        debugPrint('AppsFlyer conversion data: $data');

        final status = data['af_status'] as String?;
        final affiliateCode = data['af_sub1'] as String?;

        if (status != 'Non-organic' ||
            affiliateCode == null ||
            affiliateCode.isEmpty) {
          debugPrint(
              'No valid affiliate conversion (status=$status, af_sub1=$affiliateCode)');
          return;
        }

        debugPrint(
            'Valid affiliate conversion detected. Affiliate code: $affiliateCode');

        await _reportDownloadToSupabase(affiliateCode);
      } catch (e, stack) {
        debugPrint(
            'Error handling AppsFlyer conversion data: $e\n$stack');
      }
    });
  }

  Future<void> _reportDownloadToSupabase(String affiliateCode) async {
    if (_affiliateDownloadUrl.isEmpty) {
      debugPrint(
          'AFFILIATE_DOWNLOAD_URL is empty, skipping report for $affiliateCode');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = 'affiliate_download_reported_$affiliateCode';
    if (prefs.getBool(key) ?? false) {
      debugPrint('Affiliate download already reported for $affiliateCode');
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
        await prefs.setBool(key, true);
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
      home: const StartScreen(),
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
