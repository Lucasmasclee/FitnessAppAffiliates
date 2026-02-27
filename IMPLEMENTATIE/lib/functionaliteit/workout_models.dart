/// Domeinmodellen voor het genereren van workouts.
///
/// Deze classes volgen de stappen uit `AAA_Documentatie.md` en `googledoc.md`:
/// - Stap 1–4: frequentie & volume per spier / spiergroep + sets per week
/// - Stap 5: spiervolgorde (prioriteit)
/// - Stap 6: trainingsdagen & split‑patroon (A/B/C)
/// - Stap 7–9: concrete workouts met oefeningen

/// Resultaat van stap 2: volume & frequentie per individuele spier.
class MuscleTrainingPlan {
  /// Naam zoals gebruikt in de survey (bijv. 'Biceps', 'Upper chest').
  final String muscleName;

  /// Hoe vaak deze spier per week getraind wordt.
  final int frequencyPerWeek;

  /// Aantal sets per training voor deze spier.
  final int setsPerWorkout;

  /// Groei‑niveau uit de survey (0–6).
  final int growthLevel;

  /// Volume‑niveau uit de tabellen (1–3).
  final int volumeLevel;

  /// Gekozen ranking (1–10) volgens de tabel Groei Niveau → Ranking.
  final int ranking;

  const MuscleTrainingPlan({
    required this.muscleName,
    required this.frequencyPerWeek,
    required this.setsPerWorkout,
    required this.growthLevel,
    required this.volumeLevel,
    required this.ranking,
  });
}

/// Resultaat van stap 3: volume & frequentie per spierGROEP.
class MuscleGroupTrainingPlan {
  /// Naam van de spiergroep (bijv. 'Chest', 'Shoulders', 'Quadriceps & Glutes').
  final String groupName;

  /// Hoe vaak de spiergroep per week getraind wordt.
  final int frequencyPerWeek;

  /// Aantal sets per training voor deze spiergroep.
  ///
  /// Lengte van de lijst hoort gelijk te zijn aan [frequencyPerWeek].
  final List<int> setsPerSession;

  /// Alle individuele spieren (survey‑namen) die in deze groep vallen.
  final List<String> muscles;

  const MuscleGroupTrainingPlan({
    required this.groupName,
    required this.frequencyPerWeek,
    required this.setsPerSession,
    required this.muscles,
  });

  /// Totaal aantal sets voor deze spiergroep per week (stap 4).
  int get weeklySets =>
      setsPerSession.fold<int>(0, (previous, element) => previous + element);
}

/// Resultaat van stap 4: sets per week samengevat.
class WeeklyWorkloadSummary {
  /// Sets per week per spiergroep, bijv. { 'Chest': 12, 'Biceps': 9 }.
  final Map<String, int> setsPerWeekPerGroup;

  /// Totaal aantal sets per week (som van alle spiergroepen).
  final int totalSetsPerWeek;

  /// Hoogste frequentie van alle spiergroepen (1–3).
  final int highestGroupFrequency;

  const WeeklyWorkloadSummary({
    required this.setsPerWeekPerGroup,
    required this.totalSetsPerWeek,
    required this.highestGroupFrequency,
  });
}

/// Resultaat van stap 5: prioriteitsvolgorde van spiergroepen.
class MuscleGroupPriorityOrder {
  /// Volgorde van spiergroepen, van meeste naar minste prioriteit.
  ///
  /// Namen komen overeen met de namen in de survey / stap 3–4.
  final List<String> orderedGroups;

  const MuscleGroupPriorityOrder(this.orderedGroups);
}

/// Type workoutdag volgens het A/B/C‑systeem uit de documentatie.
enum WorkoutDayType {
  /// A = Full Body (alle spiergroepen).
  a,

  /// B = helft van de spiergroepen (meest prioritaire helft).
  b,

  /// C = andere helft van de spiergroepen.
  c,
}

/// Eén concrete trainingsdag in de week met een type (A, B of C).
class WorkoutDayDefinition {
  /// Weekdag, bijv. 'Maandag', 'Woensdag'.
  final String weekday;

  /// Type van de workout (A/B/C).
  final WorkoutDayType type;

  const WorkoutDayDefinition({
    required this.weekday,
    required this.type,
  });
}

/// Input voor stap 6: alles wat nodig is om de split te bepalen.
class WorkoutSplitInput {
  /// Beschikbare dagen per week (bijv. ['Maandag', 'Woensdag', 'Zaterdag']).
  final List<String> availableDays;

  /// Overzicht van sets per week en hoogste frequentie uit stap 4.
  final WeeklyWorkloadSummary workloadSummary;

  /// Prioriteitsvolgorde van spiergroepen uit stap 5.
  final MuscleGroupPriorityOrder priorityOrder;

  const WorkoutSplitInput({
    required this.availableDays,
    required this.workloadSummary,
    required this.priorityOrder,
  });
}

/// Resultaat van stap 6: gekozen split‑patroon en bijbehorende dagen.
class WorkoutSplitPattern {
  /// Patroon in letters (bijv. 'A', 'AA', 'AAA', 'BC', 'BCBC', 'BCB', 'BCA').
  final String pattern;

  /// Trainingsdagen met type en weekdag (bijv. Maandag = A, Woensdag = C).
  final List<WorkoutDayDefinition> days;

  const WorkoutSplitPattern({
    required this.pattern,
    required this.days,
  });
}

/// Eén oefening binnen een workout (stap 7–9).
class WorkoutExercise {
  /// Uniek ID of key van de oefening (optioneel, maar handig voor opslag).
  final String id;

  /// Naam van de oefening, zoals in `oefeninglijst.json`.
  final String name;

  /// Alle spieren die tijdens deze oefening getraind worden.
  final List<String> trainedMuscles;

  /// Aantal sets dat in deze workout voor deze oefening gedaan wordt.
  final int sets;

  const WorkoutExercise({
    required this.id,
    required this.name,
    required this.trainedMuscles,
    required this.sets,
  });
}

/// Eén complete workout op een bepaalde dag.
class Workout {
  /// Label of ID van de workout (bijv. 'Workout A1', 'Maandag A').
  final String id;

  /// Weekdag waarop deze workout in het schema valt.
  final String weekday;

  /// Type van de workout (A/B/C), zodat hij te koppelen is aan het split‑patroon.
  final WorkoutDayType type;

  /// Alle oefeningen met bijbehorende sets.
  final List<WorkoutExercise> exercises;

  const Workout({
    required this.id,
    required this.weekday,
    required this.type,
    required this.exercises,
  });
}

