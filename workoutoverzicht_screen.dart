import 'package:flutter/material.dart';

import '../functionaliteit/workout_generator.dart';
import '../functionaliteit/workout_storage.dart';
import 'workout.dart';

/// Scherm dat het opgeslagen workoutoverzicht toont.
/// [initialWorkoutIndex] kan worden meegegeven (bijv. vanuit weekplanning) om direct
/// de bijbehorende workout te tonen.
class WorkoutoverzichtScreen extends StatefulWidget {
  const WorkoutoverzichtScreen({super.key, this.initialWorkoutIndex});

  final int? initialWorkoutIndex;

  @override
  State<WorkoutoverzichtScreen> createState() => _WorkoutoverzichtScreenState();
}

class _WorkoutoverzichtScreenState extends State<WorkoutoverzichtScreen> {
  SurveyResultSummary? _summary;
  bool _loading = true;
  String? _error;
  WorkoutSessionData? _sessionData;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final summary = await loadSavedWorkoutSplit();
    var session = await loadActiveSession();
    if (!mounted) return;
    final numWorkouts = summary?.step10PerDayExercises?.length ?? 0;
    final hasValidSummary = summary != null &&
        summary.step10PerDayExercises != null &&
        summary.step10PerDayExercises!.isNotEmpty;
    // Gebruik initialWorkoutIndex van weekplanning wanneer expliciet meegegeven.
    final targetIndex = widget.initialWorkoutIndex ?? session?.workoutIndex ?? 0;
    final indexInRange = targetIndex >= 0 && targetIndex < numWorkouts;
    final workoutIndex = indexInRange ? targetIndex : 0;
    if (hasValidSummary) {
      if (session == null) {
        session = WorkoutSessionData(
          workoutIndex: workoutIndex,
          exerciseResults: {},
        );
        await saveActiveSession(session);
      } else if (widget.initialWorkoutIndex != null &&
          session.workoutIndex != workoutIndex) {
        // Vanuit weekplanning op een dag geklikt: toon de gekozen workout.
        session = WorkoutSessionData(
          workoutIndex: workoutIndex,
          exerciseResults: session.exerciseResults,
        );
        await saveActiveSession(session);
      }
    }
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _sessionData = session;
      _loading = false;
      if (summary == null ||
          summary.step10PerDayExercises == null ||
          summary.step10PerDayExercises!.isEmpty) {
        _error =
            'No saved workout found. Please create a valid workout via the survey first.';
      }
    });
  }

  void _onWorkoutIndexChanged(int workoutIndex) {
    setState(() {
      _sessionData = WorkoutSessionData(
        workoutIndex: workoutIndex,
        exerciseResults: {},
      );
    });
    saveActiveSession(_sessionData!);
  }

  Future<void> _onSaveExercise(String exerciseName, List<SetResult> setResults) async {
    await clearDraftExerciseResult(exerciseName);
    await saveLastExerciseResult(exerciseName, setResults);
    if (_sessionData != null) {
      final updated = Map<String, List<SetResult>>.from(_sessionData!.exerciseResults);
      updated[exerciseName] = setResults;
      setState(() {
        _sessionData = _sessionData!.copyWith(exerciseResults: updated);
      });
      await saveActiveSession(_sessionData!);
    }
  }

  Future<void> _onEndWorkout() async {
    await clearActiveSession();
    if (!mounted) return;
    setState(() {
      _sessionData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Workout overview'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Workout overview'),
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
                  _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }
    return WorkoutScreen(
      summary: _summary,
      isWorkoutOverview: true,
      sessionData: _sessionData,
      onSaveExercise: _onSaveExercise,
      onEndWorkout: _onEndWorkout,
      initialWorkoutIndex: _sessionData?.workoutIndex ?? widget.initialWorkoutIndex,
      onWorkoutEdited: (updatedSummary) {
        setState(() => _summary = updatedSummary);
      },
      onWorkoutIndexChanged: _onWorkoutIndexChanged,
    );
  }
}
