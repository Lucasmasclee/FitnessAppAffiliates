import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'workout_generator.dart';

const String _keySavedWorkoutSplit = 'saved_workout_split';
const String _keyActiveWorkoutSession = 'active_workout_session';
const String _keyLastExerciseResults = 'last_exercise_results';
const String _keyDraftExerciseResults = 'draft_exercise_results';

/// Resultaat van één set: gewicht (kg), reps en RIR (Reps in Reserve).
typedef SetResult = ({double? weight, int? reps, int? rir});

/// Actieve workoutsessie: welke workout wordt getrackt en per oefening de set-resultaten.
class WorkoutSessionData {
  final int workoutIndex;
  final Map<String, List<SetResult>> exerciseResults;

  const WorkoutSessionData({
    required this.workoutIndex,
    required this.exerciseResults,
  });

  WorkoutSessionData copyWith({
    int? workoutIndex,
    Map<String, List<SetResult>>? exerciseResults,
  }) {
    return WorkoutSessionData(
      workoutIndex: workoutIndex ?? this.workoutIndex,
      exerciseResults: exerciseResults ?? this.exerciseResults,
    );
  }
}

/// Bepaalt of een workoutsplit valide is: minstens 1 workout met minstens 1
/// oefening met minstens 1 set (dus in totaal minstens 1 oefening).
bool isValidWorkoutSplit(SurveyResultSummary? summary) {
  final exercises = summary?.step10PerDayExercises;
  if (exercises == null || exercises.isEmpty) return false;
  for (final day in exercises) {
    for (final ex in day) {
      if (ex.sets >= 1) return true;
    }
  }
  return false;
}

/// Slaat een valide workoutsplit op het apparaat op.
Future<void> saveWorkoutSplit(SurveyResultSummary summary) async {
  if (!isValidWorkoutSplit(summary)) return;
  final prefs = await SharedPreferences.getInstance();
  final encoded = _encodeSummary(summary);
  await prefs.setString(_keySavedWorkoutSplit, encoded);
}

/// Geeft true terug als de gebruiker ooit een valide workoutsplit heeft opgeslagen.
Future<bool> hasValidWorkoutSaved() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keySavedWorkoutSplit);
  if (raw == null || raw.isEmpty) return false;
  try {
    final summary = _decodeSummary(raw);
    return isValidWorkoutSplit(summary);
  } catch (_) {
    return false;
  }
}

/// Laadt de opgeslagen workoutsplit, of null als er geen is.
Future<SurveyResultSummary?> loadSavedWorkoutSplit() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keySavedWorkoutSplit);
  if (raw == null || raw.isEmpty) return null;
  try {
    return _decodeSummary(raw);
  } catch (_) {
    return null;
  }
}

String _encodeSummary(SurveyResultSummary s) {
  final perDay = s.step10PerDayExercises
      ?.map((day) => day
          .map((e) => {
                'name': e.name,
                'sets': e.sets,
                'reps': e.reps,
                'restTime': e.restTime,
                'rir': e.rir,
                'restSeconds': e.restSeconds,
              })
          .toList())
      .toList();
  final map = <String, dynamic>{
    'availableDays': s.availableDays,
    'step6ResultPattern': s.step6ResultPattern,
    'step6ResultDays': s.step6ResultDays,
    'step10PerDayExercises': perDay,
    'scheduledDaysPerWorkout': s.scheduledDaysPerWorkout,
    'workoutNames': s.workoutNames,
  };
  return jsonEncode(map);
}

SurveyResultSummary _decodeSummary(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final availableDays =
      (map['availableDays'] as List<dynamic>?)?.cast<String>() ?? [];
  final pattern = map['step6ResultPattern'] as String?;
  final step6ResultDays =
      (map['step6ResultDays'] as List<dynamic>?)?.cast<String>();
  final perDayRaw = map['step10PerDayExercises'] as List<dynamic>?;
  List<List<Stap10ExerciseEntry>>? step10PerDayExercises;
  if (perDayRaw != null) {
    step10PerDayExercises = perDayRaw.map((day) {
      return (day as List<dynamic>)
          .map((e) {
            final m = e as Map<String, dynamic>;
            return (
              name: m['name'] as String? ?? '',
              sets: (m['sets'] as num?)?.toInt() ?? 0,
              reps: m['reps'] as String? ?? '',
              restTime: m['restTime'] as String? ?? '',
              rir: m['rir'] as String? ?? '',
              restSeconds: (m['restSeconds'] as num?)?.toInt() ?? 0,
            );
          })
          .toList();
    }).toList();
  }
  List<List<String>>? scheduledDaysPerWorkout;
  final scheduledRaw = map['scheduledDaysPerWorkout'] as List<dynamic>?;
  if (scheduledRaw == null) {
    // Backward compatibility: oude key
    final oldRaw = map['scheduledDayPerWorkout'] as List<dynamic>?;
    if (oldRaw != null) {
      scheduledDaysPerWorkout = oldRaw
          .map((e) => e == null ? <String>[] : [e as String])
          .toList();
    }
  } else {
    scheduledDaysPerWorkout = scheduledRaw.map((e) {
      if (e == null) return <String>[];
      if (e is List<dynamic>) return (e).map((s) => s as String).toList();
      return [e as String];
    }).toList();
  }
  List<String>? workoutNames;
  final workoutNamesRaw = map['workoutNames'] as List<dynamic>?;
  if (workoutNamesRaw != null) {
    workoutNames = workoutNamesRaw.map((e) => e as String).toList();
  } else if (step10PerDayExercises != null) {
    workoutNames = List.generate(
      step10PerDayExercises!.length,
      (i) => 'workout ${i + 1}',
    );
  }
  return SurveyResultSummary(
    availableDays: availableDays,
    muscleOrder: const [],
    totalSetsPerWeek: 0,
    highestFreq: 0,
    caseInfo: '',
    step6ResultPattern: pattern,
    step6ResultDays: step6ResultDays,
    step10PerDayExercises: step10PerDayExercises,
    scheduledDaysPerWorkout: scheduledDaysPerWorkout,
    workoutNames: workoutNames,
  );
}

/// Slaat de actieve workoutsessie op (voor live bijhouden).
Future<void> saveActiveSession(WorkoutSessionData session) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyActiveWorkoutSession, _encodeSession(session));
}

/// Geeft true terug als er een actieve (niet beëindigde) workout op het apparaat staat.
Future<bool> hasActiveSession() async {
  final session = await loadActiveSession();
  return session != null;
}

/// Laadt de actieve workoutsessie, of null als er geen is.
Future<WorkoutSessionData?> loadActiveSession() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyActiveWorkoutSession);
  if (raw == null || raw.isEmpty) return null;
  try {
    return _decodeSession(raw);
  } catch (_) {
    return null;
  }
}

/// Verwijdert de actieve sessie (bijv. na beëindigen workout).
Future<void> clearActiveSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyActiveWorkoutSession);
}

String _encodeSession(WorkoutSessionData s) {
  final exerciseMap = <String, dynamic>{};
  s.exerciseResults.forEach((name, list) {
    exerciseMap[name] = list
        .map((e) => {'weight': e.weight, 'reps': e.reps, 'rir': e.rir})
        .toList();
  });
  final map = <String, dynamic>{
    'workoutIndex': s.workoutIndex,
    'exerciseResults': exerciseMap,
  };
  return jsonEncode(map);
}

WorkoutSessionData _decodeSession(String raw) {
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final workoutIndex = (map['workoutIndex'] as num?)?.toInt() ?? 0;
  final resultsRaw = map['exerciseResults'] as Map<String, dynamic>? ?? {};
  final exerciseResults = <String, List<SetResult>>{};
  resultsRaw.forEach((name, list) {
    final items = (list as List<dynamic>?)
        ?.map((e) {
          final m = e as Map<String, dynamic>;
          return (
            weight: (m['weight'] as num?)?.toDouble(),
            reps: (m['reps'] as num?)?.toInt(),
            rir: (m['rir'] as num?)?.toInt(),
          );
        })
        .toList() ?? [];
    exerciseResults[name] = items;
  });
  return WorkoutSessionData(
    workoutIndex: workoutIndex,
    exerciseResults: exerciseResults,
  );
}

/// Slaat het meest recente resultaat van een oefening op (voor tonen als read-only).
Future<void> saveLastExerciseResult(String exerciseName, List<SetResult> setResults) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyLastExerciseResults);
  final map = raw != null && raw.isNotEmpty
      ? Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>)
      : <String, dynamic>{};
  map[exerciseName] = setResults
      .map((e) => {'weight': e.weight, 'reps': e.reps, 'rir': e.rir})
      .toList();
  await prefs.setString(_keyLastExerciseResults, jsonEncode(map));
}

/// Laadt het meest recente opgeslagen resultaat voor een oefening.
Future<List<SetResult>?> loadLastExerciseResult(String exerciseName) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyLastExerciseResults);
  if (raw == null || raw.isEmpty) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = map[exerciseName] as List<dynamic>?;
    if (list == null) return null;
    return list
        .map((e) {
          final m = e as Map<String, dynamic>;
          return (
            weight: (m['weight'] as num?)?.toDouble(),
            reps: (m['reps'] as num?)?.toInt(),
            rir: (m['rir'] as num?)?.toInt(),
          );
        })
        .toList();
  } catch (_) {
    return null;
  }
}

/// Slaat concept-invoer voor een oefening op (nog niet op Save gedrukt).
/// Wordt gebruikt om bij heropenen de velden weer in te vullen.
Future<void> saveDraftExerciseResult(String exerciseName, List<SetResult> setResults) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyDraftExerciseResults);
  final map = raw != null && raw.isNotEmpty
      ? Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>)
      : <String, dynamic>{};
  map[exerciseName] = setResults
      .map((e) => {'weight': e.weight, 'reps': e.reps, 'rir': e.rir})
      .toList();
  await prefs.setString(_keyDraftExerciseResults, jsonEncode(map));
}

/// Laadt concept-invoer voor een oefening (voor pre-fill van het formulier).
Future<List<SetResult>?> loadDraftExerciseResult(String exerciseName) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyDraftExerciseResults);
  if (raw == null || raw.isEmpty) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = map[exerciseName] as List<dynamic>?;
    if (list == null) return null;
    return list
        .map((e) {
          final m = e as Map<String, dynamic>;
          return (
            weight: (m['weight'] as num?)?.toDouble(),
            reps: (m['reps'] as num?)?.toInt(),
            rir: (m['rir'] as num?)?.toInt(),
          );
        })
        .toList();
  } catch (_) {
    return null;
  }
}

/// Verwijdert het concept voor een oefening (na drukken op Save).
Future<void> clearDraftExerciseResult(String exerciseName) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyDraftExerciseResults);
  if (raw == null || raw.isEmpty) return;
  try {
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
    map.remove(exerciseName);
    await prefs.setString(_keyDraftExerciseResults, jsonEncode(map));
  } catch (_) {}
}
