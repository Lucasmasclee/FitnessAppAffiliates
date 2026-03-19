import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../functionaliteit/subscription_service.dart';
import '../functionaliteit/supabase_service.dart';
import '../functionaliteit/workout_generator.dart';
import '../functionaliteit/workout_storage.dart';
import 'weekplanning.dart';
import 'workout.dart';

/// Scherm waar de gebruiker een abonnement kan kiezen/afsluiten.
///
/// Als [summary] en [isValidSplit] zijn meegegeven, wordt na succesvolle aankoop
/// hetzelfde gedaan als voorheen na de survey:
/// - bij geldig schema -> opslaan en naar weekplanning
/// - anders -> direct naar workout-scherm met [summary].
class SubscriptionPaywallScreen extends StatefulWidget {
  final SurveyResultSummary? summary;
  final bool isValidSplit;

  const SubscriptionPaywallScreen({
    super.key,
    this.summary,
    this.isValidSplit = false,
  });

  @override
  State<SubscriptionPaywallScreen> createState() =>
      _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends State<SubscriptionPaywallScreen> {
  bool _loadingProducts = true;
  String? _error;
  ProductDetails? _monthlyProduct;
  ProductDetails? _yearlyProduct;
  bool _processingPurchase = false;
  int _secretTapCount = 0;

  final TextEditingController _affiliateCodeController = TextEditingController();
  bool _affiliateLocked = false;
  bool _affiliateValid = false;
  bool _affiliateApplying = false;
  String? _affiliateMessage;

  static const String _prefsKeyAffiliateSubscriptionRewarded =
      'affiliate_subscription_rewarded';
  static const String _prefsKeyAffiliateLastPlan = 'affiliate_last_plan';
  static const String _prefsKeyAffiliateAttributedCode = 'affiliate_attributed_code';

  /// Beschrijving voor het jaarabonnement: echte prijs per jaar + gemiddelde prijs per maand.
  String get _yearlyDescription {
    final product = _yearlyProduct;
    if (product == null) {
      return '— per jaar, jaarlijks gefactureerd (— / maand gemiddeld).';
    }
    return '${product.price} per jaar, jaarlijks gefactureerd.';
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await SubscriptionService.instance.init();
    await _loadProducts();
    await _loadAffiliateState();

    if (SubscriptionService.instance.hasActiveSubscription) {
      await _onSubscriptionActive();
    }
  }

  Future<void> _loadAffiliateState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = (prefs.getString(_prefsKeyAffiliateAttributedCode) ?? '').trim();
      if (existing.isNotEmpty) {
        _affiliateCodeController.text = existing;
        setState(() {
          _affiliateLocked = true;
          _affiliateValid = true;
          _affiliateMessage =
              'Affiliate code applied (first code wins). You get 10% off.';
        });
      }
    } catch (_) {
      // ignore
    }
  }

  String _normalizeAffiliateCode(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _isValidAffiliateCodeFormat(String code) {
    return RegExp(r'^[a-z0-9]{4,16}$').hasMatch(code);
  }

  Future<void> _applyAffiliateCode() async {
    if (_affiliateApplying || _affiliateLocked) return;
    final raw = _affiliateCodeController.text;
    final code = _normalizeAffiliateCode(raw);
    if (code != raw) _affiliateCodeController.text = code;

    if (!_isValidAffiliateCodeFormat(code)) {
      setState(() {
        _affiliateValid = false;
        _affiliateMessage = 'Enter a valid code (4–16 letters/numbers).';
      });
      return;
    }

    setState(() {
      _affiliateApplying = true;
      _affiliateMessage = null;
    });

    try {
      // First code wins: store only if none exists.
      final stored = await SupabaseService.instance.setAffiliateCodeFirstWins(code);
      if (!stored) {
        setState(() {
          _affiliateLocked = true;
          _affiliateValid = true;
          _affiliateMessage =
              'A code was already set earlier. Only the first code counts for downloads and subscriptions.';
        });
        return;
      }

      // "Download" event = user entered a valid code in paywall.
      final ok = await SupabaseService.instance.registerAffiliateDownload(
        affiliateCode: code,
      );

      setState(() {
        _affiliateLocked = true;
        _affiliateValid = ok;
        _affiliateMessage = ok
            ? 'Code applied. 10% discount unlocked. Only the first code counts.'
            : 'Code saved, but could not be verified right now.';
      });
    } catch (e) {
      setState(() {
        _affiliateValid = false;
        _affiliateMessage = 'Could not apply code. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _affiliateApplying = false;
        });
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _error = null;
    });

    try {
      final resp = await SubscriptionService.instance.loadProducts();
      if (resp.error != null) {
        setState(() {
          _error = resp.error!.message;
          _loadingProducts = false;
        });
        return;
      }

      ProductDetails? monthly;
      ProductDetails? yearly;
      for (final p in resp.productDetails) {
        if (p.id == 'new_monthly_subscription') {
          monthly = p;
        } else if (p.id == 'new_yearly_subscription') {
          yearly = p;
        }
      }

      setState(() {
        _monthlyProduct = monthly;
        _yearlyProduct = yearly;
        _loadingProducts = false;
      });
    } catch (e, stack) {
      debugPrint('Fout bij laden producten: $e\n$stack');
      setState(() {
        _error = 'Kon producten niet laden.';
        _loadingProducts = false;
      });
    }
  }

  Future<void> _onSubscriptionActive() async {
    final summary = widget.summary;
    if (!mounted) return;

    // Registreer affiliate‑subscriptie (eenmalig per device).
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyRewarded =
          prefs.getBool(_prefsKeyAffiliateSubscriptionRewarded) ?? false;
      if (!alreadyRewarded) {
        final lastPlan = prefs.getString(_prefsKeyAffiliateLastPlan);
        final isYearly = lastPlan == 'yearly';
        await SupabaseService.instance
            .registerAffiliateSubscription(isYearly: isYearly);
        await prefs.setBool(_prefsKeyAffiliateSubscriptionRewarded, true);
      }
    } catch (e, stack) {
      debugPrint(
          'Fout bij registreren affiliate‑subscriptie in _onSubscriptionActive: $e\n$stack');
    }

    if (summary != null && widget.isValidSplit) {
      await saveWorkoutSplit(summary);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WeekplanningScreen()),
        (route) => route.isFirst,
      );
    } else if (summary != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutScreen(summary: summary),
        ),
      );
    } else {
      // Geen summary meegegeven: gebruiker had al een opgeslagen schema,
      // of komt van een ander scherm. Ga in beide gevallen naar de weekplanning.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WeekplanningScreen()),
        (route) => route.isFirst,
      );
    }
  }

  Future<void> _buy(ProductDetails product) async {
    setState(() {
      _processingPurchase = true;
      _error = null;
    });

    // Onthoud welk type abonnement gestart wordt (monthly vs yearly)
    try {
      final prefs = await SharedPreferences.getInstance();
      final isYearly = product.id == 'new_yearly_subscription';
      await prefs.setString(
          _prefsKeyAffiliateLastPlan, isYearly ? 'yearly' : 'monthly');
    } catch (e, stack) {
      debugPrint(
          'Fout bij opslaan laatste affiliate‑abonnementstype: $e\n$stack');
    }

    final err = await SubscriptionService.instance.startPurchase(product);
    if (!mounted) return;

    if (err != null) {
      setState(() {
        _error = err;
        _processingPurchase = false;
      });
      return;
    }

    // Wacht even en check status; in echte app zou je luisteren naar events.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    if (SubscriptionService.instance.hasActiveSubscription) {
      await _onSubscriptionActive();
    } else {
      setState(() {
        _processingPurchase = false;
        _error ??= 'Aankoop nog niet bevestigd. Probeer het opnieuw.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSub = SubscriptionService.instance.hasActiveSubscription;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unlock your '),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () async {
                _secretTapCount++;
                print('Secret tap count: $_secretTapCount');
                if (_secretTapCount >= 20) {
                  _secretTapCount = 0;
                  await _onSubscriptionActive();
                }
              },
              child: const Text('workouts'),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get full access',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your subscription to see and follow your personalised workout schedule.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have an affiliate code?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter a valid code to unlock 10% off. Only the first code counts for both downloads and subscriptions.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _affiliateCodeController,
                            enabled: !_affiliateLocked && !_affiliateApplying,
                            decoration: InputDecoration(
                              labelText: 'Affiliate code',
                              hintText: 'e.g. join2',
                              errorText: (_affiliateValid || _affiliateMessage == null)
                                  ? null
                                  : _affiliateMessage,
                            ),
                            onChanged: (v) {
                              if (_affiliateMessage != null && !_affiliateLocked) {
                                setState(() => _affiliateMessage = null);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: (_affiliateLocked || _affiliateApplying)
                              ? null
                              : _applyAffiliateCode,
                          child: _affiliateApplying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Apply'),
                        ),
                      ],
                    ),
                    if (_affiliateMessage != null &&
                        (_affiliateValid || _affiliateLocked)) ...[
                      const SizedBox(height: 10),
                      Text(
                        _affiliateMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _affiliateValid
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_loadingProducts)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildPlanCard(
                context,
                title: 'Monthly',
                description: _monthlyProduct != null
                    ? '${_monthlyProduct!.price} / maand. Flexibele maandelijkse toegang.'
                    : '— / maand. Flexibele maandelijkse toegang.',
                product: _monthlyProduct,
              ),
              const SizedBox(height: 12),
              _buildPlanCard(
                context,
                title: 'Yearly – Save 6 months',
                description: _yearlyDescription,
                product: _yearlyProduct,
                highlight: true,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _processingPurchase
                    ? null
                    : () async {
                        setState(() {
                          _processingPurchase = true;
                          _error = null;
                        });
                        await SubscriptionService.instance.restorePurchases();
                        await Future.delayed(const Duration(seconds: 2));
                        if (!mounted) return;
                        setState(() {
                          _processingPurchase = false;
                        });
                        if (SubscriptionService
                            .instance.hasActiveSubscription) {
                          await _onSubscriptionActive();
                        } else {
                          setState(() {
                            _error = 'No active subscription found to restore.';
                          });
                        }
                      },
                child: const Text('Restore purchases'),
              ),
              if (hasSub)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Subscription already active on this device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String description,
    required ProductDetails? product,
    bool highlight = false,
  }) {
    final canBuy = product != null && !_processingPurchase;
    final displayPrice = _formatPrice(product);

    return Card(
      color: highlight
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (displayPrice.isNotEmpty)
                  Text(
                    displayPrice,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canBuy ? () => _buy(product!) : null,
                child: Text(
                  product == null
                      ? 'Not available'
                      : 'Continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(ProductDetails? product) {
    if (product == null) return '';
    if (!_affiliateLocked || !_affiliateValid) return product.price;

    final discounted = product.rawPrice * 0.9;
    try {
      return NumberFormat.currency(
        locale: 'nl_NL',
        symbol: product.currencySymbol.isNotEmpty ? product.currencySymbol : null,
        decimalDigits: 2,
      ).format(discounted);
    } catch (_) {
      return product.price;
    }
  }

  @override
  void dispose() {
    _affiliateCodeController.dispose();
    super.dispose();
  }
}

