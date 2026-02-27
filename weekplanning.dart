import 'package:flutter/material.dart';

import '../app_navigator_observer.dart';
import '../functionaliteit/workout_generator.dart';
import '../functionaliteit/workout_storage.dart';
import 'editworkout.dart';
import 'survey.dart';
import 'workoutoverzicht_screen.dart';

/// Scherm met de weekplanning: 7 dagen onder elkaar, met navigatie
/// naar vorige/volgende week (maximaal 1 jaar terug en 1 jaar vooruit).
/// Als er een opgeslagen workout is, staat bij elke dag de juiste workoutnaam (A, B, C, …).
class WeekplanningScreen extends StatefulWidget {
  const WeekplanningScreen({super.key});

  @override
  State<WeekplanningScreen> createState() => _WeekplanningScreenState();
}

class _WeekplanningScreenState extends State<WeekplanningScreen>
    with RouteAware {
  static const List<String> _dagNamen = [
    'Maandag',
    'Dinsdag',
    'Woensdag',
    'Donderdag',
    'Vrijdag',
    'Zaterdag',
    'Zondag',
  ];

  /// Maandag van de geselecteerde week (zonder tijd).
  late DateTime _selectedWeekStart;
  late DateTime _minWeekStart;
  late DateTime _maxWeekStart;

  SurveyResultSummary? _summary;
  bool _loading = true;

  /// Dagnaam -> lijst van workout-indices die op die dag gepland staan.
  /// Ondersteunt meerdere workouts per dag.
  Map<String, List<int>> get _dagNaarWorkoutIndices {
    final scheduled = _summary?.scheduledDaysPerWorkout;
    final exercises = _summary?.step10PerDayExercises;
    final numWorkouts = exercises?.length ?? 0;
    final map = <String, List<int>>{};
    if (numWorkouts == 0) return map;
    if (scheduled != null && scheduled.length >= numWorkouts) {
      for (var i = 0; i < numWorkouts; i++) {
        for (final day in scheduled[i]) {
          if (day.isNotEmpty) {
            map.putIfAbsent(day, () => []).add(i);
          }
        }
      }
    } else {
      final pattern = _summary?.step6ResultPattern;
      final days = _summary?.step6ResultDays;
      if (pattern != null && days != null) {
        for (var i = 0; i < days.length && i < pattern.length; i++) {
          map.putIfAbsent(days[i], () => []).add(i);
        }
      }
    }
    return map;
  }

  /// Geeft de weergavenaam voor een workout (bijv. "workout 1", "workout 2").
  String _workoutNaamVoorIndex(int index) {
    final names = _summary?.workoutNames;
    if (names != null && index < names.length) return names[index];
    return 'workout ${index + 1}';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedWeekStart = _maandagVanWeek(now);
    _minWeekStart = _maandagVanWeek(now.subtract(const Duration(days: 365)));
    _maxWeekStart = _maandagVanWeek(now.add(const Duration(days: 365)));
    _loadWorkout();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Gebruiker keert terug naar weekplanning (bijv. na bewerken workout); refresh data.
    _loadWorkout();
  }

  Future<void> _loadWorkout() async {
    final summary = await loadSavedWorkoutSplit();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  /// Geeft de maandag (00:00) van de week waarin [date] valt.
  DateTime _maandagVanWeek(DateTime date) {
    final weekday = date.weekday;
    final daysToMonday = weekday - DateTime.monday;
    final monday = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysToMonday));
    return monday;
  }

  void _vorigeWeek() {
    final next = _selectedWeekStart.subtract(const Duration(days: 7));
    if (next.isBefore(_minWeekStart)) return;
    setState(() => _selectedWeekStart = next);
  }

  void _volgendeWeek() {
    final next = _selectedWeekStart.add(const Duration(days: 7));
    if (next.isAfter(_maxWeekStart)) return;
    setState(() => _selectedWeekStart = next);
  }

  bool get _kanVorigeWeek => _selectedWeekStart.isAfter(_minWeekStart);

  bool get _kanVolgendeWeek => _selectedWeekStart.isBefore(_maxWeekStart);

  String _weekRangeText() {
    final end = _selectedWeekStart.add(const Duration(days: 6));
    final fmt = (DateTime d) => '${d.day} ${_maandLabels[d.month - 1]}';
    return '${fmt(_selectedWeekStart)} – ${fmt(end)}';
  }

  static const List<String> _maandLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _datumTekst(DateTime d) {
    return '${d.day} ${_maandLabels[d.month - 1]}';
  }

  String _displayDayName(String dagNaam) {
    switch (dagNaam) {
      case 'Maandag':
        return 'Monday';
      case 'Dinsdag':
        return 'Tuesday';
      case 'Woensdag':
        return 'Wednesday';
      case 'Donderdag':
        return 'Thursday';
      case 'Vrijdag':
        return 'Friday';
      case 'Zaterdag':
        return 'Saturday';
      case 'Zondag':
        return 'Sunday';
      default:
        return dagNaam;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Workout schedule'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
        actions: [
          if (_summary != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Workout',
              onPressed: () async {
                await Navigator.of(context).push<SurveyResultSummary?>(
                  MaterialPageRoute(
                    builder: (context) => EditWorkoutScreen(summary: _summary!),
                  ),
                );
                if (mounted) _loadWorkout();
              },
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Generate new workout',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Center(
                    child: Text(
                      'Generate a new workout?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actionsPadding: const EdgeInsets.only(bottom: 8),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SurveyScreen(),
                          ),
                        );
                      },
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Week-navigatie
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text(
                //   'Week',
                //   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                //         fontWeight: FontWeight.bold,
                //       ),
                // ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filled(
                      onPressed: _kanVorigeWeek ? _vorigeWeek : null,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous week',
                    ),
                    Expanded(
                      child: Text(
                        _weekRangeText(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                            ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _kanVolgendeWeek ? _volgendeWeek : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next week',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 7 dagen onder elkaar
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final dagNaam = _dagNamen[index];
                      final dagDatum =
                          _selectedWeekStart.add(Duration(days: index));
                      final isVandaag = _isZelfdeDag(dagDatum, DateTime.now());
                      final workoutIndices =
                          _dagNaarWorkoutIndices[dagNaam] ?? [];
                      final hasWorkouts = workoutIndices.isNotEmpty;
                      final onlyOneWorkout =
                          hasWorkouts && workoutIndices.length == 1;
                      final content = Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _displayDayName(dagNaam),
                                  style: TextStyle(
                                    fontWeight: isVandaag
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _datumTekst(dagDatum),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: isVandaag
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : null,
                                      ),
                                ),
                              ],
                            ),
                            if (hasWorkouts) ...[
                              // const SizedBox(height: 8),
                              ...workoutIndices.map((workoutIndex) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            WorkoutoverzichtScreen(
                                          initialWorkoutIndex: workoutIndex,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.fitness_center,
                                            size: 20,
                                            color: Theme.of(context)
                                                .colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _workoutNaamVoorIndex(workoutIndex),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme.primary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        color: isVandaag
                            ? Colors.blue.shade100
                            : null,
                        child: onlyOneWorkout
                            ? InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          WorkoutoverzichtScreen(
                                        initialWorkoutIndex:
                                            workoutIndices.single,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: content,
                              )
                            : content,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  bool _isZelfdeDag(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
