import 'package:flutter/material.dart';

import '../functionaliteit/rest_timer_service.dart';
import '../functionaliteit/workout_generator.dart';
import '../functionaliteit/workout_storage.dart';
import 'editworkout.dart';
import 'start_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final SurveyResultSummary? summary;
  /// True als dit scherm vanuit het workoutoverzicht (weekplanning) wordt getoond; dan zijn o.a. terugknop, 'End workout' en progressie-logging beschikbaar.
  final bool isWorkoutOverview;
  /// Sessiedata voor de actieve workout (welke index, welke oefeningen voltooid). Bepaalt o.a. of 'End workout' getoond wordt.
  final WorkoutSessionData? sessionData;
  /// Callback na opslaan van oefening (naam + set-resultaten).
  final void Function(String exerciseName, List<SetResult> setResults)? onSaveExercise;
  /// Callback wanneer gebruiker de workout beëindigt.
  final VoidCallback? onEndWorkout;
  /// Optioneel startindex (bijv. bij openen met bestaande sessie).
  final int? initialWorkoutIndex;
  /// Callback wanneer de gebruiker de workout bewerkt en opslaat; ontvangt het bijgewerkte summary.
  final void Function(SurveyResultSummary updatedSummary)? onWorkoutEdited;
  /// Callback wanneer de gebruiker van workoutdag wisselt (Previous/Next); ontvangt de nieuwe workoutIndex.
  final void Function(int workoutIndex)? onWorkoutIndexChanged;

  const WorkoutScreen({
    super.key,
    this.summary,
    this.isWorkoutOverview = false,
    this.sessionData,
    this.onSaveExercise,
    this.onEndWorkout,
    this.initialWorkoutIndex,
    this.onWorkoutEdited,
    this.onWorkoutIndexChanged,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late int _currentWorkoutIndex;

  @override
  void initState() {
    super.initState();
    _currentWorkoutIndex = widget.initialWorkoutIndex ?? 0;
  }

  @override
  void didUpdateWidget(WorkoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialWorkoutIndex != null &&
        widget.initialWorkoutIndex != oldWidget.initialWorkoutIndex) {
      _currentWorkoutIndex = widget.initialWorkoutIndex!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final workouts = summary?.step10PerDayExercises;

    if (summary == null || workouts == null || workouts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Workout'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No workout',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'No workout plan available. Please complete the survey first.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Clamp huidige index binnen bereik
    if (_currentWorkoutIndex >= workouts.length) {
      _currentWorkoutIndex = workouts.length - 1;
    }

    final currentExercises = workouts[_currentWorkoutIndex];
    final pattern = summary.step6ResultPattern ?? '';
    final baseTitle = (pattern.isNotEmpty &&
            _currentWorkoutIndex >= 0 &&
            _currentWorkoutIndex < pattern.length)
        ? pattern[_currentWorkoutIndex].toUpperCase()
        : 'Workout';
    // Title: gebruik workoutnaam 'workout 1', 'workout 2', … of fallback op index.
    final titleText = (summary.workoutNames != null &&
            _currentWorkoutIndex < summary.workoutNames!.length)
        ? summary.workoutNames![_currentWorkoutIndex]
        : 'workout ${_currentWorkoutIndex + 1}';
    final isFromOverview = widget.isWorkoutOverview;
    final session = widget.sessionData;
    final hasActiveSession = session != null;
    final isThisWorkoutSession =
        hasActiveSession && session.workoutIndex == _currentWorkoutIndex;

    final canPop = Navigator.of(context).canPop();
    final scaffold = Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: isFromOverview
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const StartScreen(),
                      ),
                    );
                  }
                },
              )
            : null,
        title: Text(
          summary.step6ResultDays != null &&
                  _currentWorkoutIndex >= 0 &&
                  _currentWorkoutIndex < summary.step6ResultDays!.length
              ? _displayDayName(summary.step6ResultDays![_currentWorkoutIndex])
              : 'Workout',
              
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Workout',
            onPressed: () async {
              final updated = await Navigator.of(context).push<SurveyResultSummary?>(
                MaterialPageRoute(
                  builder: (context) => EditWorkoutScreen(
                    summary: summary,
                    initialWorkoutIndex: _currentWorkoutIndex,
                  ),
                ),
              );
              if (updated != null && mounted) {
                widget.onWorkoutEdited?.call(updated);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        textAlign: TextAlign.left,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currentExercises.length} exercises - ${currentExercises.fold<int>(0, (sum, ex) => sum + ex.sets)} sets',
                        textAlign: TextAlign.left,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: currentExercises.length,
              itemBuilder: (context, index) {
                final ex = currentExercises[index];
                final isCompleted = isThisWorkoutSession &&
                    session.exerciseResults.containsKey(ex.name);
                final repsStr = ex.reps.isNotEmpty ? ex.reps : '5-7';
                final setsRepsStr = '${ex.sets} ${ex.sets == 1 ? 'set' : 'sets'}';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 2,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ex.name,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          setsRepsStr,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCompleted)
                          Icon(
                            Icons.check_circle,
                            size: 28,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        else
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _showExerciseDetails(context, ex),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentWorkoutIndex > 0
                          ? () {
                              setState(() {
                                _currentWorkoutIndex--;
                              });
                              widget.onWorkoutIndexChanged?.call(_currentWorkoutIndex);
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentWorkoutIndex < workouts.length - 1
                          ? () {
                              setState(() {
                                _currentWorkoutIndex++;
                              });
                              widget.onWorkoutIndexChanged?.call(_currentWorkoutIndex);
                            }
                          : null,
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isFromOverview && !canPop) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const StartScreen()),
            );
          }
        },
        child: scaffold,
      );
    }
    return scaffold;
  }

  String _intensityForSets(int sets) {
    if (sets <= 0) return '';
    if (sets == 1) return '0 RIR';
    final parts = <String>[];
    for (var i = 0; i < sets; i++) {
      parts.add(i == sets - 1 ? '0 RIR' : '1 RIR');
    }
    return parts.join(', ');
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

  Future<void> _showExerciseDetails(BuildContext context, Stap10ExerciseEntry ex) async {
    final intensity = _intensityForSets(ex.sets);
    final canLogProgress = widget.isWorkoutOverview && widget.onSaveExercise != null;
    final sessionResults = canLogProgress && widget.sessionData != null
        ? widget.sessionData!.exerciseResults[ex.name]
        : null;
    List<SetResult>? lastResult;
    List<SetResult>? draftResults;
    if (widget.isWorkoutOverview) {
      lastResult = await loadLastExerciseResult(ex.name);
      draftResults = await loadDraftExerciseResult(ex.name);
    }
    if (!mounted) return;
    // Session heeft voorrang; anders concept (draft) zodat eerder ingevulde sets terugkomen.
    final initialSetResults = sessionResults ?? draftResults;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _ExerciseDetailScreen(
          exercise: ex,
          intensity: intensity,
          canLogProgress: canLogProgress,
          initialSetResults: initialSetResults,
          lastResult: lastResult,
          onSave: canLogProgress && widget.onSaveExercise != null
              ? (results) => widget.onSaveExercise!(ex.name, results)
              : null,
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _ExerciseDetailScreen extends StatefulWidget {
  final Stap10ExerciseEntry exercise;
  final String intensity;
  /// Of de gebruiker progressie mag invullen (gewicht/reps/RIR) en de rusttimer kan gebruiken.
  final bool canLogProgress;
  final List<SetResult>? initialSetResults;
  /// Meest recente opgeslagen data (read-only weergave).
  final List<SetResult>? lastResult;
  final void Function(List<SetResult> setResults)? onSave;

  const _ExerciseDetailScreen({
    required this.exercise,
    required this.intensity,
    this.canLogProgress = false,
    this.initialSetResults,
    this.lastResult,
    this.onSave,
  });

  @override
  State<_ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<_ExerciseDetailScreen> {
  late List<TextEditingController> _weightControllers;
  late List<TextEditingController> _repsControllers;
  late List<TextEditingController> _rirControllers;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    final n = widget.exercise.sets;
    _weightControllers = List.generate(
      n,
      (i) {
        if (widget.initialSetResults != null &&
            i < widget.initialSetResults!.length &&
            widget.initialSetResults![i].weight != null) {
          return TextEditingController(
              text: widget.initialSetResults![i].weight.toString());
        }
        return TextEditingController();
      },
    );
    _repsControllers = List.generate(
      n,
      (i) {
        if (widget.initialSetResults != null &&
            i < widget.initialSetResults!.length &&
            widget.initialSetResults![i].reps != null) {
          return TextEditingController(
              text: widget.initialSetResults![i].reps.toString());
        }
        return TextEditingController();
      },
    );
    _rirControllers = List.generate(
      n,
      (i) {
        if (widget.initialSetResults != null &&
            i < widget.initialSetResults!.length &&
            widget.initialSetResults![i].rir != null) {
          return TextEditingController(
              text: widget.initialSetResults![i].rir.toString());
        }
        return TextEditingController();
      },
    );
  }

  @override
  void dispose() {
    // Bij wegnavigeren zonder Save: concept opslaan zodat bij heropenen de velden weer gevuld zijn.
    if (!_hasSaved && widget.onSave != null) {
      final results = _buildResultsFromControllers();
      saveDraftExerciseResult(widget.exercise.name, results);
    }
    for (final c in _weightControllers) {
      c.dispose();
    }
    for (final c in _repsControllers) {
      c.dispose();
    }
    for (final c in _rirControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<SetResult> _buildResultsFromControllers() {
    final results = <SetResult>[];
    for (var i = 0; i < widget.exercise.sets; i++) {
      final weightStr = _weightControllers[i].text.trim();
      final repsStr = _repsControllers[i].text.trim();
      final rirStr = _rirControllers[i].text.trim();
      results.add((
        weight: weightStr.isEmpty ? null : double.tryParse(weightStr.replaceAll(',', '.')),
        reps: repsStr.isEmpty ? null : int.tryParse(repsStr),
        rir: rirStr.isEmpty ? null : int.tryParse(rirStr),
      ));
    }
    return results;
  }

  Widget _buildInfoChip(BuildContext context, String label) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final intensity = widget.intensity;
    final showProgressAndTimer = widget.canLogProgress && widget.onSave != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          ex.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
          softWrap: true,
          maxLines: 2,
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoChip(
                    context,
                    [
                      'Sets: ${ex.sets}',
                      'Reps: ${ex.reps.isNotEmpty ? ex.reps : '5-7'}',
                      'Rest: ${ex.restTime.isNotEmpty ? ex.restTime : '2-3 min'}',
                      'Intensity: ${intensity.isNotEmpty ? intensity : ''}',
                    ].join('\n'),
                  ),
                  if (showProgressAndTimer) ...[
                    const SizedBox(height: 24),
                      FilledButton.icon(
                      onPressed: () async {
                        // Gebruik de rusttijd die bij deze oefening in de workout is ingesteld
                        var seconds = ex.restTime.trim().isEmpty
                            ? await getRestTimerSecondsForExercise(ex.name)
                            : parseRestTimeToSeconds(ex.restTime);
                        if (!context.mounted) return;
                        try {
                          await RestTimerService.instance.start(seconds);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Rest timer started, but the notification could not be scheduled. '
                                'Please check if notifications are allowed in the app settings.',
                              ),
                              duration: Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.timer_outlined, size: 20),
                      label: const Text('Start rest timer'),
                    ),
                  ],
                  if (widget.lastResult != null && widget.lastResult!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Text(
                      'Previous Weights',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(ex.sets, (i) {
                      final data = i < widget.lastResult!.length
                          ? widget.lastResult![i]
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text('Set ${i + 1}:',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ),
                            Expanded(
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Weight',
                                  hintText: 'kg',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                child: Text(
                                  data?.weight != null
                                      ? '${data!.weight}'
                                      : '–',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Reps',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                child: Text(
                                  data?.reps?.toString() ?? '–',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'RIR',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                child: Text(
                                  data?.rir?.toString() ?? '–',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (showProgressAndTimer) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Text(
                      'Track workout',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(ex.sets, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text('Set ${i + 1}:',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _weightControllers[i],
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Weight',
                                  hintText: 'kg',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _repsControllers[i],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Reps',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _rirControllers[i],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'RIR',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          if (showProgressAndTimer)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: _saveResults,
                  child: const Text('Save'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _saveResults() {
    _hasSaved = true;
    final results = _buildResultsFromControllers();
    widget.onSave?.call(results);
    if (mounted) Navigator.of(context).pop();
  }
}

