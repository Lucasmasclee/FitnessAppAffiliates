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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('affiliate_code', code);
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
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('affiliate_code');

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

