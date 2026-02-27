import 'package:flutter/material.dart';

import '../functionaliteit/workout_storage.dart';
import '../functionaliteit/subscription_service.dart';
import 'survey.dart';
import 'weekplanning.dart';
import 'workoutoverzicht_screen.dart';
import 'subscription_paywall.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  /// Onthoudt of we deze app-sessie al eens naar workoutoverzicht hebben doorgestuurd.
  /// Zo blijft dit behouden als de gebruiker teruggaat naar het startscherm.
  static bool _didRedirectToActiveWorkoutThisSession = false;

  bool _hasValidWorkout = false;
  bool _hasActiveSession = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkValidWorkout();
  }

  Future<void> _checkValidWorkout() async {
    final hasValid = await hasValidWorkoutSaved();
    final session = await loadActiveSession();
    if (!mounted) return;
    final hasSub = SubscriptionService.instance.hasActiveSubscription;
    setState(() {
      _hasValidWorkout = hasValid;
      _hasActiveSession = session != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // if (!_loading && _hasActiveSession && !_didRedirectToActiveWorkoutThisSession) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (_didRedirectToActiveWorkoutThisSession || !mounted) return;
    //     _didRedirectToActiveWorkoutThisSession = true;
    //     Navigator.of(context).pushReplacement(
    //       MaterialPageRoute(
    //         builder: (context) => const WorkoutoverzichtScreen(),
    //       ),
    //     );
    //   });
    // }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Lift Better'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start the survey to create your workout, or view your weekly schedule.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: Icon(
                        Icons.assignment_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'Create new workout',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      subtitle: const Text(
                        'Get your personalized workout',
                        style: TextStyle(fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SurveyScreen(),
                          ),
                        ).then((_) => _checkValidWorkout());
                      },
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: Icon(
                        Icons.calendar_month_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'Workout Schedule',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      subtitle: Text(
                        _hasValidWorkout
                            ? 'View your workout schedule'
                            : 'Complete the survey first',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        if (!_hasValidWorkout) {
                          // Eerst altijd de survey afronden.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SurveyScreen(),
                            ),
                          ).then((_) => _checkValidWorkout());
                          return;
                        }

                        if (!SubscriptionService
                            .instance.hasActiveSubscription) {
                          // Geen abonnement: toon eerst de paywall.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SubscriptionPaywallScreen(),
                            ),
                          ).then((_) => _checkValidWorkout());
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WeekplanningScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
