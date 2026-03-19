import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Eenvoudige helper om met Supabase te praten.
class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService instance = SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  static const String _prefsKeyAffiliateAttributedCode = 'affiliate_attributed_code';
  static const String _prefsKeyAffiliateLegacyCode = 'affiliate_code';
  static const String _prefsKeyAffiliateDownloadReported = 'affiliate_download_reported';

  /// Store affiliate code only if none is set yet.
  /// Returns true if the code was stored, false if a code already existed.
  Future<bool> setAffiliateCodeFirstWins(String code) async {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getString(_prefsKeyAffiliateAttributedCode) ??
            prefs.getString(_prefsKeyAffiliateLegacyCode) ??
            '')
        .trim();

    if (existing.isNotEmpty) return false;

    await prefs.setString(_prefsKeyAffiliateAttributedCode, normalized);
    // Keep legacy key in sync for older code paths.
    await prefs.setString(_prefsKeyAffiliateLegacyCode, normalized);
    return true;
  }

  /// Read the attributed affiliate code (first code wins).
  Future<String?> getAffiliateAttributedCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = (prefs.getString(_prefsKeyAffiliateAttributedCode) ??
            prefs.getString(_prefsKeyAffiliateLegacyCode))
        ?.trim()
        .toLowerCase();
    return (code != null && code.isNotEmpty) ? code : null;
  }

  /// Register a "download" when the user enters a valid affiliate code in paywall.
  /// Only registers once per device.
  Future<bool> registerAffiliateDownload({required String affiliateCode}) async {
    final code = affiliateCode.trim().toLowerCase();
    if (code.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKeyAffiliateDownloadReported) ?? false) {
      return true;
    }

    const functionUrl = String.fromEnvironment('AFFILIATE_DOWNLOAD_URL');
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

    Uri? uri;
    if (functionUrl.isNotEmpty) {
      uri = Uri.tryParse(functionUrl);
    } else if (supabaseUrl.isNotEmpty) {
      uri = Uri.tryParse('$supabaseUrl/functions/v1/affiliate-download');
    }
    if (uri == null) return false;

    final body = jsonEncode({
      'affiliate_code': code,
      'platform': defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'other'),
    });

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await prefs.setBool(_prefsKeyAffiliateDownloadReported, true);
      return true;
    }
    return false;
  }

  /// Haal de affiliate_code op voor een gebruiker met dit e‑mailadres,
  /// print de waarde in de console (debugPrint) en sla de code lokaal op.
  ///
  /// Pas [tableName] aan naar de naam van jouw Supabase‑tabel.
  Future<void> printAffiliateCodeForEmail(
    String email, {
    String tableName = 'affiliates',
  }) async {
    try {
      final row = await client
          .from(tableName)
          .select('affiliate_code, phone')
          .eq('email', email)
          .maybeSingle();

      if (row == null) {
        debugPrint('Supabase: geen rij gevonden voor email=$email');
        return;
      }

      final code = row['affiliate_code'] as String?;
      final phone = row['phone'];
      debugPrint('Supabase: affiliate_code voor $email = $code, phone = $phone');

      if (code != null && code.isNotEmpty) {
        // Only set if none exists yet (first code wins).
        final stored = await setAffiliateCodeFirstWins(code);
        if (!stored) {
          debugPrint('Supabase: affiliate_code already set locally; not overwriting.');
        }
        debugPrint('Supabase: affiliate_code lokaal opgeslagen: $code');
      }
    } catch (e, stack) {
      debugPrint('Supabase: fout bij ophalen affiliate_code: $e\n$stack');
    }
  }

  /// Registreer een succesvolle affiliate‑subscriptie.
  ///
  /// Dit roept de Edge Function `affiliate-subscription` aan, die:
  /// - de juiste affiliate opzoekt op basis van affiliate_code
  /// - een rij in affiliate_transactions aanmaakt
  /// - affiliate_stats (monthly_subs / yearly_subs) bijwerkt.
  Future<void> registerAffiliateSubscription({required bool isYearly}) async {
    try {
      final code = await getAffiliateAttributedCode();

      if (code == null || code.isEmpty) {
        debugPrint(
            'Supabase: geen affiliate_code lokaal opgeslagen, skip affiliate-subscription.');
        return;
      }

      // Prefer een expliciete function-URL als environment variable,
      // anders bouwen we de URL op basis van SUPABASE_URL.
      const functionUrl =
          String.fromEnvironment('AFFILIATE_SUBSCRIPTION_URL');
      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

      Uri? uri;
      if (functionUrl.isNotEmpty) {
        uri = Uri.tryParse(functionUrl);
      } else if (supabaseUrl.isNotEmpty) {
        uri = Uri.tryParse(
            '$supabaseUrl/functions/v1/affiliate-subscription');
      }

      if (uri == null) {
        debugPrint(
            'Supabase: geen geldige AFFILIATE_SUBSCRIPTION_URL of SUPABASE_URL, skip affiliate-subscription.');
        return;
      }

      final body = jsonEncode({
        'affiliate_code': code,
        'subscription_type': isYearly ? 'yearly' : 'monthly',
      });

      debugPrint(
          'Supabase: POST affiliate-subscription naar $uri (code=$code, isYearly=$isYearly)');

      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint(
            'Supabase: affiliate-subscription geregistreerd voor code=$code (status ${response.statusCode}).');
      } else {
        debugPrint(
            'Supabase: affiliate-subscription call mislukt (status ${response.statusCode}): ${response.body}');
      }
    } catch (e, stack) {
      debugPrint(
          'Supabase: fout bij registerAffiliateSubscription: $e\n$stack');
    }
  }
}

