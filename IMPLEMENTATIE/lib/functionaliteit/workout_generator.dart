import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'workout_models.dart';
import 'alle_opties_ingevuld_met_routines.dart';

/// Alle benodigde data voor het genereren van een workout.
/// GroeiNiveau (0-6) -> BesteTrainingRanking (0-10)
/// In de PDF staat dit als "Beste Training" getallen (0,9,6,5,3,2,1),
/// maar functioneel is het een mapping naar een ranking.
/// (Ranking 10 = 0/0 training)
const Map<int, int> groeiNiveauToBesteTrainingRanking = {
  0: 10, // 0 training
  1: 9,
  2: 6,
  3: 4,
  4: 3,
  5: 2,
  6: 1,
};

class TrainingSpec {
  final int frequency;
  final int volume;
  const TrainingSpec({required this.frequency, required this.volume});
}

/// Ranking (1-10) -> Frequency + Volume
const Map<int, TrainingSpec> rankingToTrainingSpec = {
  1: TrainingSpec(frequency: 3, volume: 3),
  2: TrainingSpec(frequency: 3, volume: 2),
  3: TrainingSpec(frequency: 2, volume: 3),
  4: TrainingSpec(frequency: 3, volume: 1),
  5: TrainingSpec(frequency: 2, volume: 2),
  6: TrainingSpec(frequency: 2, volume: 1),
  7: TrainingSpec(frequency: 1, volume: 3),
  8: TrainingSpec(frequency: 1, volume: 2),
  9: TrainingSpec(frequency: 1, volume: 1),
  10: TrainingSpec(frequency: 0, volume: 0),
};

/// Per ranking (1-9): welke volume-niveaus (1, 2 of 3) die ranking wél mogen gebruiken.
/// Als het volume-niveau van de spier hier niet in zit → ga door naar 1 ranking lager.
/// Ranking 10 heeft geen beperking (0/0).
/// Per ranking (1-10): welke volume-niveaus (1, 2, 3 of 4) die ranking wél mogen gebruiken.
/// (Zie PDF: elke mapping = "Wel: ... Niet: ..." vereisten.)
const Map<int, List<int>> rankingToAllowedVolumeNiveaus = {
  1: [4],             // Wel: 4. Niet: 1, 2 & 3
  2: [2, 3, 4],       // Wel: 2, 3 & 4. Niet: 1
  3: [4],             // Wel: 4. Niet: 1, 2 & 3
  4: [1, 2, 3, 4],    // Wel: 1, 2, 3 & 4
  5: [2, 3, 4],       // Wel: 2, 3 & 4. Niet: 1
  6: [1, 2, 3, 4],    // Wel: 1, 2, 3 & 4
  7: [2, 3, 4],       // Wel: 2, 3 & 4. Niet: 1
  8: [1, 2, 3, 4],    // Wel: 1, 2, 3 & 4
  9: [1, 2, 3, 4],    // Wel: 1, 2, 3 & 4
  10: [1, 2, 3, 4],   // Wel: 1, 2, 3 & 4
};

const Map<String, int> spiergroepToVolumeNiveau = {
  'Biceps': 3,
  'Triceps': 3,
  'Mid chest': 2,
  'Upper chest': 1,
  'Side delts': 4,
  'Front delts': 2,
  'Lats': 4,
  'Rear delts': 2,
  'Mid traps': 2,
  'Upper traps': 2,
  'Spinal Erectors': 2,
  'Abs': 2,
  'Obliques': 2,
  'Forearms': 2,
  'Rectus Femoris': 2,
  'Vastus Muscles': 3,
  'Gluteus Maximus': 3,
  'Upper Glutes': 2,
  'Hamstrings': 2,
  'Adductors': 2,
  'Calves': 2,
};


/// Helper: groeiNiveau -> (frequency, volume) volgens de tabellen.
/// Je kunt hierna nog clampen op Beschikbare Frequentie.
TrainingSpec specForGroeiNiveau(int groeiNiveau) {
  final ranking = groeiNiveauToBesteTrainingRanking[groeiNiveau] ?? 10;
  return rankingToTrainingSpec[ranking] ?? const TrainingSpec(frequency: 0, volume: 0);
}





/// Samenvatting van de survey-verwerking voor weergave op het workoutscherm.
class SurveyResultSummary {
  final List<String> availableDays;
  final List<String> muscleOrder;
  final int totalSetsPerWeek;
  final int highestFreq;
  final String caseInfo;
  /// Stap 6 resultaat uit lookup (pattern + dagen).
  final String? step6ResultPattern;
  final List<String>? step6ResultDays;
  /// Verwachte waarden voor vergelijking (bijv. uit testinput).
  final String? step6ExpectedPattern;
  final List<String>? step6ExpectedDays;
  /// Samenvatting van stap 7: verdeling spiergroepen per dag.
  final String? step7Info;
  /// Stap 10: per dag de gekozen oefeningen (naam + sets).
  final List<List<Stap10ExerciseEntry>>? step10PerDayExercises;
  /// Per workout de ingeplande dagen (Maandag–Zondag); meerdere dagen per workout mogelijk. Gebruikt in weekplanning.
  final List<List<String>>? scheduledDaysPerWorkout;
  /// Weergavenamen per workout: 'workout 1', 'workout 2', … 'workout x'.
  final List<String>? workoutNames;

  const SurveyResultSummary({
    required this.availableDays,
    required this.muscleOrder,
    required this.totalSetsPerWeek,
    required this.highestFreq,
    required this.caseInfo,
    this.step6ResultPattern,
    this.step6ResultDays,
    this.step6ExpectedPattern,
    this.step6ExpectedDays,
    this.step7Info,
    this.step10PerDayExercises,
    this.scheduledDaysPerWorkout,
    this.workoutNames,
  });

  String toDisplayText() {
    var text = 'Beschikbare dagen: $availableDays\n'
        'Totaal sets per week (stap 4): $totalSetsPerWeek\n'
        'Hoogste spier-frequentie: $highestFreq\n'
        '$caseInfo';
    final resultP = step6ResultPattern;
    final resultD = step6ResultDays;
    if (resultP != null && resultD != null) {
      text += '\n\nResultaat:\nPattern: $resultP, Days: $resultD';
    }
    if (step7Info != null && step7Info!.isNotEmpty) {
      text += '\n\nStap 7 – Spieren per dag:\n$step7Info';
    }
    return text;
  }
}

/// Verwerkt de survey‑resultaten.
///
/// [data] verwacht een Map met:
/// - 'days': Map<String, bool>
/// - 'maxWorkoutMinutes': int
/// - 'muscles': Map<String, { level: int, label: String }>
Future<SurveyResultSummary> handleSurveyResult(Map<String, dynamic> data) async {
  
  final pretty = const JsonEncoder.withIndent('  ').convert(data);

  debugPrint('===== Survey resultaten (Dart) =====');
  debugPrint(pretty);

  final days = Map<String, dynamic>.from(data['days'] ?? {});
  final maxMinutes = data['maxWorkoutMinutes'];
  final muscles = Map<String, dynamic>.from(data['muscles'] ?? {});

  debugPrint('\nTrainingsdagen:');
  days.forEach((day, canTrain) {
    final status = (canTrain == true) ? 'Beschikbaar' : 'niet beschikbaar';
    debugPrint('  - $day: $status');
  });

  debugPrint('\nMaximale duur per workout:');
  debugPrint('  - $maxMinutes minuten');

  debugPrint('\nSpiergroepen & intensiteit:');
  muscles.forEach((name, info) {
    final infoMap = Map<String, dynamic>.from(info as Map);
    final level = infoMap['level'];
    final label = infoMap['label'];
    final bias = infoMap['bias'];
    final biasLabel = infoMap['biasLabel'];
    if (bias != null && biasLabel != null) {
      debugPrint('  - $name: level=$level, label=$label, bias=$bias ($biasLabel)');
    } else {
      debugPrint('  - $name: level=$level, label=$label');
    }
  });

  final muscleOrder = (data['muscleOrder'] as List<dynamic>?)
      ?.map((e) => e.toString())
      .toList();

  final availableDays = days.entries
      .where((e) => e.value == true)
      .map((e) => e.key.toString())
      .toList();

  // Speciale modus: directe stap‑6 test via lookup-tabel (alleen pattern + dagen).
  final lookupGivenSets = data['lookupGivenSets'] as String?;
  final lookupGivenFreq = data['lookupGivenFreq']?.toString();
  if (lookupGivenSets != null && lookupGivenFreq != null) {
    debugPrint('\n[handleSurveyResult] Stap 6 direct via lookup‑tabel');
    final step6Only = workouts_stap_6_directLookup(
      availableDays,
      lookupGivenSets,
      lookupGivenFreq,
    );

    return SurveyResultSummary(
      availableDays: availableDays,
      muscleOrder: const [],
      totalSetsPerWeek: step6Only.$1,
      highestFreq: step6Only.$2,
      caseInfo: step6Only.$3,
      step6ResultPattern:
          step6Only.$4.pattern.isNotEmpty ? step6Only.$4.pattern : null,
      step6ResultDays: step6Only.$4.days.isNotEmpty
          ? step6Only.$4.days.map((d) => d.weekday).toList()
          : null,
      step6ExpectedPattern: null,
      step6ExpectedDays: null,
    );
  }

  debugPrint('\nStap 1 - Trainingsfrequentie:');
  final (beschikbareFrequentie, chosenTrainingDays) =
      workouts_stap_1(availableDays);

  debugPrint('\nStap 2 - Volume & frequentie per spier:');
  final stap2Result = workouts_stap_2(muscles, muscleOrder, beschikbareFrequentie);

  debugPrint('\nStap 3 - Training per spiergroep uitrekenen:');
  final stap3Result = await workouts_stap_3(stap2Result, muscleOrder);

  debugPrint('\nStap 4 - Sets per week bepalen:');
  workouts_stap_4(stap3Result);

  debugPrint('\nStap 5 - Spiervolgorde bepalen:');
  workouts_stap_5(muscles, muscleOrder);

  debugPrint('\nStap 6 - Trainingsdagen / split bepalen:');
  final expectedPattern = data['expectedPattern'] as String?;
  final expectedPatternDays =
      (data['expectedPatternDays'] as List<dynamic>?)?.cast<String>();

  // ===============================
  // PASS 1 (SetsBerekenen = true)
  // ===============================
  // Doel: run t/m stap 10 zonder 25-cap om `totaalSetsPerWeek` te bepalen,
  // map daarna naar `givenSets` zodat pass 2 de juiste split kan opzoeken.
  final stap6Pass1 = workouts_stap_6(
    availableDays,
    stap3Result,
    muscleOrder,
    setsBerekenen: true,
  );

  final stap7Pass1 = workouts_stap_7(
    stap6Pass1.$4.pattern.split(''),
    muscleOrder ?? <String>[],
    stap3Result,
  );

  final stap8Pass1 = await workouts_stap_8(
    stap7Pass1,
    stap2Result,
    stap3Result,
    stap6Pass1.$4.pattern.split(''),
    stap6Days: stap6Pass1.$4.days,
  );

  final weekdaysFromStep6Pass1 = stap6Pass1.$4.days.isNotEmpty
      ? stap6Pass1.$4.days.map((d) => d.weekday).toList()
      : null;
  final numDaysForStep10Pass1 = stap8Pass1.perDayMuscleSets.length;
  final weekdaysPerDayPass1 =
      (weekdaysFromStep6Pass1 != null && weekdaysFromStep6Pass1.length >= numDaysForStep10Pass1)
          ? weekdaysFromStep6Pass1
          : chosenTrainingDays.length >= numDaysForStep10Pass1
              ? chosenTrainingDays.take(numDaysForStep10Pass1).toList()
              : null;

  final totaalSetsPerWeekPass1 = await workouts_stap_10(
    stap8Pass1,
    muscleOrder ?? <String>[],
    muscles,
    weekdaysPerDay: weekdaysPerDayPass1,
    setsBerekenen: true,
  );
  debugPrint('\n[Pass 1] totaalSetsPerWeek=$totaalSetsPerWeekPass1');

  // ===============================
  // PASS 2 (SetsBerekenen = false)
  // ===============================
  // Doel: genereer het volledige schema; stap 6 lookup gebruikt totalSetsPerWeek uit stap3
  // en zoekt de juiste range in de tabel op (days + givenFreq + range).
  final stap6Result = workouts_stap_6(
    availableDays,
    stap3Result,
    muscleOrder,
    expectedPattern: expectedPattern,
    expectedPatternDays: expectedPatternDays,
    setsBerekenen: false,
    setsoverride: totaalSetsPerWeekPass1,
  );

  debugPrint('\nStap 7 - Spieren toevoegen aan workouts:');
  final stap7Result = workouts_stap_7(
    stap6Result.$4.pattern.split(''),
    muscleOrder ?? <String>[],
    stap3Result,
  );

  debugPrint('\nStap 8 - Spiergroepen → subspieren met sets:');
  final stap8Result = await workouts_stap_8(
    stap7Result,
    stap2Result,
    stap3Result,
    stap6Result.$4.pattern.split(''),
    stap6Days: stap6Result.$4.days,
  );
  debugPrint('  Stap 8 resultaat: ${stap8Result.perDayMuscleSets.length} dagen');

  debugPrint('\nStap 9 - Workouts inkorten tot max 25 sets:');
  await workouts_stap_9(stap8Result, muscleOrder ?? <String>[], muscles);

  debugPrint('\nStap 10 - Sets toevoegen (condities):');
  final weekdaysFromStep6 = stap6Result.$4.days.isNotEmpty
      ? stap6Result.$4.days.map((d) => d.weekday).toList()
      : null;
  final numDaysForStep10 = stap8Result.perDayMuscleSets.length;
  final weekdaysPerDay = (weekdaysFromStep6 != null && weekdaysFromStep6.length >= numDaysForStep10)
      ? weekdaysFromStep6
      : chosenTrainingDays.length >= numDaysForStep10
          ? chosenTrainingDays.take(numDaysForStep10).toList()
          : null;
  await workouts_stap_10(
    stap8Result,
    muscleOrder ?? <String>[],
    muscles,
    weekdaysPerDay: weekdaysPerDay,
    setsBerekenen: false,
  );

  debugPrint('\nStap 11 - Oefeningen toewijzen:');
  final stap10Result = await workouts_stap_11(stap8Result, muscles);

  debugPrint('\n===== Einde survey resultaten (Dart) =====');

  final perDay = stap10Result.perDayExercises;
  final workoutNames = List<String>.generate(
    perDay.length,
    (i) => 'workout ${i + 1}',
  );

  return SurveyResultSummary(
    availableDays: chosenTrainingDays,
    muscleOrder: muscleOrder ?? [],
    totalSetsPerWeek: stap6Result.$1,
    highestFreq: stap6Result.$2,
    caseInfo: stap6Result.$3,
    step6ResultPattern: stap6Result.$4.pattern.isNotEmpty ? stap6Result.$4.pattern : null,
    step6ResultDays: stap6Result.$4.days.isNotEmpty
        ? stap6Result.$4.days.map((d) => d.weekday).toList()
        : null,
    step6ExpectedPattern: stap6Result.expectedPattern,
    step6ExpectedDays: stap6Result.expectedPatternDays,
    step7Info: stap7Result.infoText,
    step10PerDayExercises: perDay,
    workoutNames: workoutNames,
  );
}

// Bepaal een representatief aantal sets binnen de gegeven range string (bijv. '51-75').
int _approxTotalSetsFromGivenSets(String givenSets) {
  final parts = givenSets.split('-');
  if (parts.length == 2) {
    final min = int.tryParse(parts[0]) ?? 0;
    final max = int.tryParse(parts[1]) ?? min;
    if (min > 0 && max >= min) {
      return ((min + max) / 2).round();
    }
  }
  return 0;
}

/// Controleer of [totalSetsPerWeek] binnen de range [givenSets] valt (bijv. "26-50").
/// De stap-6 tabel heeft per (days, givenFreq) meerdere ranges die niet altijd aansluiten;
/// lookup moet daarom op range gebeuren, niet op een vaste mapping.
bool _isTotalSetsInGivenSetsRange(int totalSetsPerWeek, String givenSets) {
  final parts = givenSets.split('-');
  if (parts.length != 2) return false;
  final min = int.tryParse(parts[0]);
  final max = int.tryParse(parts[1]);
  if (min == null || max == null || min > max) return false;
  return totalSetsPerWeek >= min && totalSetsPerWeek <= max;
}

// Stap 1 — Trainingsfrequentie bepalen
// Volgens googledoc.md: Bepaal hoe vaak iemand per week kan trainen, uitgaande van
// minimaal één volledige rustdag tussen elke training. Selecteer de maximale set
// trainingsdagen die aan deze rustregel voldoet.
// Speciaal: als maandag een trainingsdag is, mag zondag geen trainingsdag worden.
// Input: lijst beschikbare dagen (bijv ["Maandag","Woensdag","Donderdag","Zaterdag"])
// Output: (frequency, chosenTrainingDays).
(int, List<String>) workouts_stap_1(List<String> availableDays) {
  const weekOrder = [
    'Maandag',
    'Dinsdag',
    'Woensdag',
    'Donderdag',
    'Vrijdag',
    'Zaterdag',
    'Zondag',
  ];

  debugPrint('Input beschikbare dagen: $availableDays');

  final sortedAvailable =
      weekOrder.where((day) => availableDays.contains(day)).toList();
  debugPrint('Gesorteerde beschikbare dagen: $sortedAvailable');

  final chosenTrainingDays = <String>[];

  for (final day in sortedAvailable) {
    if (chosenTrainingDays.isEmpty) {
      chosenTrainingDays.add(day);
      continue;
    }

    final lastChosen = chosenTrainingDays.last;
    final lastIndex = weekOrder.indexOf(lastChosen);
    final currentIndex = weekOrder.indexOf(day);
    final diff = currentIndex - lastIndex;

    // Alleen toevoegen als er minimaal 1 rustdag tussen zit (diff >= 2)
    if (diff < 2) continue;

    // Notitie uit document: als maandag een trainingsdag is, mag zondag geen
    // trainingsdag worden (ze zijn adjacent in de weekcyclus)
    if (day == 'Zondag' && chosenTrainingDays.contains('Maandag')) continue;

    chosenTrainingDays.add(day);
  }

  final frequency = chosenTrainingDays.length;

  debugPrint('Gekozen trainingsdagen (met rust ertussen): $chosenTrainingDays');
  debugPrint('Output trainingsfrequentie: $frequency per week');

  return (frequency, chosenTrainingDays);
}







// Stap 2 — Volume & frequentie per spier bepalen
// Per spier: Groei Niveau (0-6) → Start Ranking → Frequency & Volume.
// Een ranking kan niet gebruikt worden als: volume-niveau van de spier staat niet in
// "Wel" voor die ranking, OF freq > beschikbare frequentie. Als "Niet" → ga door naar 1 ranking lager.
// (De regel dat sets ≤ volume-niveau moet zijn vervalt; alleen Wel/Niet per ranking telt.)
// Output: per spier {freqPerWeek, setsPerWorkout}.
Map<String, Map<String, int>> workouts_stap_2(
  Map<String, dynamic> muscles,
  List<String>? muscleOrder,
  int beschikbareFrequentie,
) {
  debugPrint('Input beschikbare frequentie (uit stap 1): $beschikbareFrequentie');
  debugPrint('Input spieren uit survey: ${muscles.keys.toList()}');
  debugPrint('Input spiervolgorde: $muscleOrder');

  final result = <String, Map<String, int>>{};

  for (final entry in muscles.entries) {
    final spier = entry.key;
    final infoMap = Map<String, dynamic>.from(entry.value as Map);

    final groeiNiveau = (infoMap['level'] as int?) ?? 0;
    final volumeNiveau = spiergroepToVolumeNiveau[spier] ?? 2;

    var ranking = groeiNiveauToBesteTrainingRanking[groeiNiveau] ?? 10;
    var spec = rankingToTrainingSpec[ranking] ??
        const TrainingSpec(frequency: 0, volume: 0);

    // Downgrade ranking totdat geldig: volume-niveau in "Wel" voor deze ranking EN freq <= beschikbareFrequentie
    while (ranking < 10) {
      final allowedVolumes = rankingToAllowedVolumeNiveaus[ranking];
      final volumeNiveauOk = allowedVolumes != null && allowedVolumes.contains(volumeNiveau);
      final freqTeHoog = spec.frequency > beschikbareFrequentie;

      if (volumeNiveauOk && !freqTeHoog) break;

      ranking++;
      spec = rankingToTrainingSpec[ranking] ?? spec;
    }

    final freq = spec.frequency;
    final sets = spec.volume;

    result[spier] = {'freq': freq, 'sets': sets};

    debugPrint(
      '  $spier: groeiNiveau=$groeiNiveau, volumeNiveau=$volumeNiveau, '
      'ranking=$ranking → Freq=$freq, Sets=$sets',
    );
  }

  debugPrint('\nOutput stap 2 (per spier Freq + Sets):');
  for (final e in result.entries) {
    debugPrint('  ${e.key}: Freq=${e.value['freq']} Sets=${e.value['sets']}');
  }
  return result;
}







/// Mapping van spiernamen uit spiergroepen.json naar survey/oefeninglijst-namen.
/// Keys = exacte "naam" uit spiergroepen.json; values = naam zoals in oefeninglijst/survey.
const Map<String, String> _spiergroepJsonNaamToSurvey = {
  'Mid chest': 'Mid chest',
  'Upper chest': 'Upper chest',
  'Front delts': 'Front delts',
  'Side delts': 'Side delts',
  'Rear delts': 'Rear delts',
  'Mid traps': 'Mid traps',
  'Upper traps': 'Upper traps',
  'Lateral + Medial head': 'Triceps',
  'Long head': 'Triceps',
  'Lower lats': 'Lats',
  'Upper lats': 'Lats',
  'Vastus muscles': 'Vastus Muscles',
  'Rectus femoris': 'Rectus Femoris',
  'Gluteus maximus': 'Gluteus Maximus',
  'Upper glutes': 'Upper glutes',
  'Wrist extensors': 'Forearms',
  'Wrist flexors': 'Forearms',
  'Elbow Flexers': 'Biceps',
  'Brachialis & Brachioradialis': 'Biceps',
};

/// Normaliseert spiernaam voor vergelijking (case-insensitive, spaties).
String _normSpier(String s) {
  return s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]'), ''); // verwijdert spaties, &, _, etc.
}


// Stap 3 — Training per spiergroep uitrekenen
// Combineert individuele spieren tot spiergroepen en berekent sets per training per spiergroep.
// Houdt rekening met oefening-overlap op basis van de oefeninglijst:
// - Delen spieren dezelfde oefening, dan tel je sets niet dubbel (max nemen).
// - Hebben spieren aparte oefeningen, dan tel je sets per training op.
// Output: per spiergroep Freq=X Sets=A,B,C.
Future<Map<String, Map<String, dynamic>>> workouts_stap_3(
  Map<String, Map<String, int>> spierFreqSets,
  List<String>? muscleOrder,
) async {
  debugPrint('Input stap 3: spierFreqSets uit stap 2');
  for (final e in spierFreqSets.entries) {
    debugPrint('  ${e.key}: Freq=${e.value['freq']} Sets=${e.value['sets']}');
  }

  final spiergroepenJson = await rootBundle.loadString(
    'lib/workouts_info/spiergroepen.json',
  );
  final spiergroepenData = jsonDecode(spiergroepenJson) as Map<String, dynamic>;
  final spiergroepenList = spiergroepenData['spiergroepen'] as List<dynamic>;

  final oefeninglijstJson = await rootBundle.loadString(
    'lib/workouts_info/oefeninglijst.json',
  );
  final oefeninglijst = jsonDecode(oefeninglijstJson) as Map<String, dynamic>;
  final exerciseList = oefeninglijst['exerciseList'] as List<dynamic>;

  debugPrint('Spiergroepen geladen: ${spiergroepenList.length}, oefeninglijst: ${exerciseList.length}');

  final result = <String, Map<String, dynamic>>{};

  for (final entry in spiergroepenList) {
    final map = entry as Map<String, dynamic>;
    final spiergroep = map['naam'] as String? ?? '';
    final spierenRaw = map['spieren'] as List<dynamic>? ?? [];
    final subspieren = spierenRaw
        .map((s) {
          final naam = (s as Map<String, dynamic>)['naam'] as String? ?? '';
          return _spiergroepJsonNaamToSurvey[naam] ?? naam;
        })
        .toSet()
        .toList();

    if (spiergroep.isEmpty) continue;

    // Haal (freq, sets) voor elke subspier uit stap 2 (match op genormaliseerde naam)
    final spierSpecs = <String, Map<String, int>>{};
    for (final sub in subspieren) {
      final key = spierFreqSets.keys
          .where((k) => _normSpier(k) == _normSpier(sub))
          .cast<String>()
          .firstOrNull;
      if (key != null && spierFreqSets[key] != null) {
        spierSpecs[sub] = spierFreqSets[key]!;
      }
    }

    if (spierSpecs.isEmpty) {
      debugPrint('  [$spiergroep] Geen subspieren gevonden in stap 2 → skip');
      result[spiergroep] = {'freq': 0, 'setsPerSession': <int>[]};
      continue;
    }

    final maxFreq = spierSpecs.values
        .map((s) => s['freq'] ?? 0)
        .reduce((a, b) => a > b ? a : b);

    if (maxFreq == 0) {
      result[spiergroep] = {'freq': 0, 'setsPerSession': <int>[]};
      continue;
    }

    // Per sessie: per unieke oefening max(remainingSets), dan remainingSets afboeken
    final setsPerSession = <int>[];
    for (var sessie = 0; sessie < maxFreq; sessie++) {
      var totaalSets = 0;
      final processedExercises = <String>{};

      // Remaining sets per subspier voor deze sessie
      final remaining = <String, int>{};
      for (final entry in spierSpecs.entries) {
        final sub = entry.key;
        final freq = entry.value['freq'] ?? 0;
        final sets = entry.value['sets'] ?? 0;
        remaining[sub] = (freq > sessie) ? sets : 0;
      }

      // Uitzonderingen per spiergroep (zie googledoc.md)
      final useException = switch (spiergroep) {
        'Shoulders' => true,
        'Upper Back' => true,
        'Quadriceps & Glutes' => true,
        _ => false,
      };

      if (useException) {
        if (spiergroep == 'Shoulders') {
          // Side Delts & Front Delts, Shoulder Press & Cable Lateral Raises
          // SD, FD, SP, CR
          // 0,0 → 0 SP 0 CR
          // 0,1 → 1 SP 0 CR
          // 0,2 → 2 SP 0 CR
          // 0,3 → 3 SP 0 CR
          // 1,0 → 1 SP 0 CR
          // 1,1 → 1 SP 0 CR
          // 1,2 → 2 SP 0 CR
          // 1,3 → 3 SP 0 CR
          // 2,0 → 2 SP 0 CR
          // 2,1 → 2 SP 0 CR
          // 2,2 → 2 SP 0 CR
          // 2,3 → 3 SP 0 CR
          // 3,0 → 2 SP 1 CR
          // 3,1 → 2 SP 1 CR
          // 3,2 → 2 SP 1 CR
          // 3,3 → 3 SP 1 CR
          // 4,0 → 2 SP 2 CR
          // 4,1 → 2 SP 2 CR
          // 4,2 → 2 SP 2 CR
          // 4,3 → 3 SP 2 CR
          print('  Remaining Side Delts: ${remaining['sidedelts']}');
          print('  Remaining Front Delts: ${remaining['frontdelts']}');
          final sidedelts = remaining.keys
                  .where((k) => _normSpier(k) == 'sidedelts')
                  .map((k) => remaining[k] ?? 0)
                  .firstOrNull ??
              0;
          final frontdelts = remaining.keys
                  .where((k) => _normSpier(k) == 'frontdelts')
                  .map((k) => remaining[k] ?? 0)
                  .firstOrNull ??
              0;
          final (shoulderpressSets, cableLateralSets) = _shoulderPressAndCableLateralSets(sidedelts, frontdelts);

          // Maximale aantal kiezen
          totaalSets = shoulderpressSets + cableLateralSets;
        } else if (spiergroep == 'Upper Back') {
          // Alle sets optellen - MIN(reardelts, midtraps)
          final reardelts = remaining.keys
                  .where((k) => _normSpier(k) == 'reardelts')
                  .map((k) => remaining[k] ?? 0)
                  .firstOrNull ??
              0;
          final midtraps = remaining.keys
                  .where((k) => _normSpier(k) == 'midtraps')
                  .map((k) => remaining[k] ?? 0)
                  .firstOrNull ??
              0;
          final sumAll = remaining.values.fold<int>(0, (a, b) => a + b);
          totaalSets = sumAll - (reardelts < midtraps ? reardelts : midtraps);
        } else if (spiergroep == 'Quadriceps & Glutes') {
          // RF=Rectus Femoris; GM=Gluteus Maximus; V=Vastus
          // ALS RF+GM <= V → Alle sets optellen - (RF+GM)
          // ALS RF+GM > V → Alle sets optellen - V
          final rf = remaining.keys
                  .where((k) => _normSpier(k) == 'rectusfemoris')
                  .map((k) => remaining[k] ?? 0)
                  .firstOrNull ??
              0;
          final gm = remaining.keys
                  .where((k) => _normSpier(k) == 'gluteusmaximus')
                  .map((k) => remaining[k] ?? 0)
                  .firstOrNull ??
              0;
          final v = remaining.keys
                  .where((k) => _normSpier(k) == 'vastusmuscles')
                  .map((k) => remaining[k] ?? 0)
                  .firstOrNull ??
              0;
          final sumAll = remaining.values.fold<int>(0, (a, b) => a + b);
          if (rf + gm <= v) {
            totaalSets = sumAll - (rf + gm);
          } else {
            totaalSets = sumAll - v;
          }
        }
      } else {
        for (final exEntry in exerciseList) {
        final exMap = exEntry as Map<String, dynamic>;
        final exercises = exMap['exercises'] as List<dynamic>? ?? [];

        for (final ex in exercises) {
          final exData = ex as Map<String, dynamic>;
          final exName = exData['name'] as String? ?? '';
          if (exName.isEmpty || processedExercises.contains(exName)) continue;

          final trained = (exData['trainedMuscles'] as List<dynamic>?)
                  ?.map((m) => (m as String).trim())
                  .toList() ??
              [];

          // Welke subspieren uit deze spiergroep traint deze oefening?
          final relevanteSubspieren = subspieren.where((sub) =>
              trained.any((t) => _normSpier(t) == _normSpier(sub))).toList();

          if (relevanteSubspieren.isEmpty) continue;

          // Hoeveel sets moeten we voor deze oefening nog doen?
          var x = 0;
          for (final sub in relevanteSubspieren) {
            final r = remaining[sub] ?? 0;
            if (r > x) x = r;
          }

          if (x == 0) {
            // oefening traint wel relevante spieren, maar er is niets meer nodig
            processedExercises.add(exName);
            continue;
          }

          processedExercises.add(exName);
          totaalSets += x;

          // Boek sets af bij alle spieren die deze oefening traint
          for (final sub in relevanteSubspieren) {
            final r = remaining[sub] ?? 0;
            remaining[sub] = (r - x) < 0 ? 0 : (r - x);
          }
        }
      }
      }

      setsPerSession.add(totaalSets);
    }


    debugPrint('  [$spiergroep] ${spierSpecs.length} subspieren → Freq=$maxFreq Sets=${setsPerSession.join(",")}');
    result[spiergroep] = {
      'freq': maxFreq,
      'setsPerSession': setsPerSession,
    };
  }

  debugPrint('\nOutput stap 3 (per spiergroep Freq + Sets):');
  for (final e in result.entries) {
    final freq = e.value['freq'] as int;
    final sets = e.value['setsPerSession'] as List<int>;
    debugPrint('  ${e.key}: Freq=$freq Sets=${sets.join(", ")}');
  }
  return result;
}









// Stap 4 — Sets per week bepalen
// Volgens googledoc.md: Sets per week = Alle sets van stap 3 optellen.
// Per spiergroep: som van setsPerSession (bv. 3+3+3 = 9 sets per week).
// Totaal: som van alle sets per week.
// Output: setsPerWeekPerMuscleGroup + totalSetsPerWeek.
void workouts_stap_4(Map<String, Map<String, dynamic>> stap3Result) {
  // debugPrint('Input stap 4: resultaat uit stap 3');

  final setsPerWeekPerMuscleGroup = <String, int>{};
  var totalSetsPerWeek = 0;

  for (final entry in stap3Result.entries) {
    final spiergroep = entry.key;
    final setsPerSession =
        (entry.value['setsPerSession'] as List<dynamic>?)?.cast<int>() ?? [];
    final setsPerWeek = setsPerSession.fold<int>(0, (a, b) => a + b);
    setsPerWeekPerMuscleGroup[spiergroep] = setsPerWeek;
    totalSetsPerWeek += setsPerWeek;
  }

  // debugPrint('\nOutput stap 4 (sets per week per spiergroep):');
  // for (final e in setsPerWeekPerMuscleGroup.entries) {
  //   debugPrint('  ${e.key}: ${e.value}');
  // }
  debugPrint('\nTotaal sets per week: $totalSetsPerWeek');
}









// Stap 5 — Spiervolgorde bepalen
// Leest de survey-ranking (prioriteit) van spiergroepen en slaat een gesorteerde volgorde op.
// Spiergroepen bovenaan hebben de meeste prioriteit; deze volgorde wordt later gebruikt
// bij het verdelen over workouts.
// Output: List<muscleGroupId> in prioriteitsvolgorde.
void workouts_stap_5(Map<String, dynamic> muscles, List<String>? muscleOrder) {
  debugPrint('\nWorkouts stap 5 – Spiervolgorde:');
  debugPrint('  Muscles: $muscles');
  debugPrint('  Muscle order: $muscleOrder');

  if (muscleOrder == null || muscleOrder.isEmpty) {
    debugPrint('  [Stap 5] Geen muscleOrder ontvangen → geen sortering uitgevoerd.');
    return;
  }

  /// Hulpfunctie: haal groeilevel (0–6) op voor een individuele spier uit
  /// de [muscles]-map (survey-resultaat).
  int _groeiNiveauVoorSpier(String naam) {
    final info = muscles[naam];
    if (info == null) return 0;
    final map = Map<String, dynamic>.from(info as Map);
    return (map['level'] as int?) ?? 0;
  }

  /// Hulpfunctie: bepaal groeilevel voor een spiergroep uit de volgorde-lijst.
  /// Eerst op basis van groeilevel(s); bij meerdere subspieren nemen we het maximum.
  int _groeiNiveauVoorGroep(String groep) {
    List<String> relevanteSpieren;
    switch (groep) {
      case 'Chest':
        relevanteSpieren = ['Mid chest', 'Upper chest'];
        break;
      case 'Shoulders':
        relevanteSpieren = ['Side delts', 'Front delts'];
        break;
      case 'Upper Back':
        relevanteSpieren = ['Rear delts', 'Mid traps', 'Upper traps'];
        break;
      case 'Quadriceps & Glutes':
        relevanteSpieren = [
          'Vastus Muscles',
          'Rectus Femoris',
          'Gluteus Maximus',
          'Upper Glutes',
        ];
        break;
      default:
        relevanteSpieren = [groep];
        break;
    }

    var maxLevel = 0;
    for (final spier in relevanteSpieren) {
      final level = _groeiNiveauVoorSpier(spier);
      if (level > maxLevel) {
        maxLevel = level;
      }
    }
    return maxLevel;
  }

  // Onthoud de oorspronkelijke ranking uit de survey (vraag 4) zodat we
  // deze kunnen gebruiken als tie-breaker bij gelijke groeilevels.
  final originalIndex = <String, int>{
    for (var i = 0; i < muscleOrder.length; i++) muscleOrder[i]: i,
  };

  muscleOrder.sort((a, b) {
    final groeiA = _groeiNiveauVoorGroep(a);
    final groeiB = _groeiNiveauVoorGroep(b);

    // 1) Eerst sorteren op groeilevel (hoog naar laag)
    if (groeiA != groeiB) {
      return groeiB.compareTo(groeiA);
    }

    // 2) Bij gelijke groeilevels wint de spier met de hoogste ranking
    //    in de volgorde-lijst uit de survey (kleinste index eerst).
    final indexA = originalIndex[a] ?? 999;
    final indexB = originalIndex[b] ?? 999;
    return indexA.compareTo(indexB);
  });

  debugPrint('  [Stap 5] Gesorteerde volgorde (eerst groei, dan ranking): $muscleOrder');
}

/// Directe stap‑6 lookup: gebruik alleen (days, givenSets, givenFreq) en de alle_opties‑tabel.
(
  int,
  int,
  String,
  WorkoutSplitPattern,
) workouts_stap_6_directLookup(
  List<String> availableDays,
  String givenSets,
  String givenFreq,
) {
  debugPrint('\nWorkouts stap 6 (direct lookup) – Trainingsdagen / split bepalen:');
  debugPrint('  Beschikbare dagen: $availableDays');
  debugPrint('  givenSets: $givenSets, givenFreq: $givenFreq');

  final totalSetsRep = _approxTotalSetsFromGivenSets(givenSets);
  final match = step6LookupTable.where((e) =>
      listEquals(e.days, availableDays) &&
      e.givenFreq == givenFreq &&
      _isTotalSetsInGivenSetsRange(totalSetsRep, e.givenSets)).firstOrNull;

  final String pattern;
  final List<WorkoutDayDefinition> days;
  if (match != null) {
    debugPrint('  [Stap 6 direct lookup] pattern: ${match.expectedPattern}');
    debugPrint('  [Stap 6 direct lookup] patternDays: ${match.expectedPatternDays}');
    pattern = match.expectedPattern;
    final patternDays = match.expectedPatternDays;
    days = [
      for (var i = 0; i < pattern.length && i < patternDays.length; i++)
        WorkoutDayDefinition(
          weekday: patternDays[i],
          type: _patternCharToType(pattern[i]),
        ),
    ];
  } else {
    debugPrint(
      '  [Stap 6 direct lookup] Geen match voor days=$availableDays, givenSets=$givenSets, givenFreq=$givenFreq',
    );
    pattern = '';
    days = [];
  }

  final totalSetsPerWeek = match != null
      ? _approxTotalSetsFromGivenSets(match.givenSets)
      : _approxTotalSetsFromGivenSets(givenSets);
  final highestFreq = int.tryParse(givenFreq) ?? 0;
  final resolvedSets = match?.givenSets ?? givenSets;
  final caseInfo =
      'Direct lookup: days=$availableDays, givenSets=$resolvedSets, givenFreq=$givenFreq';

  return (
    totalSetsPerWeek,
    highestFreq,
    caseInfo,
    WorkoutSplitPattern(pattern: pattern, days: days),
  );
}

/// Zet een pattern-letter ('A','B','C') om naar WorkoutDayType.
WorkoutDayType _patternCharToType(String char) {
  switch (char.toUpperCase()) {
    case 'B':
      return WorkoutDayType.b;
    case 'C':
      return WorkoutDayType.c;
    default:
      return WorkoutDayType.a;
  }
}

// Stap 6 — Trainingsdagen / split bepalen
// Alleen lookup in alle_opties: (dagen, totalSets-range, frequentie) → pattern, patternDays.
// Output: (totalSetsPerWeek, highestFreq, caseInfo, WorkoutSplitPattern) + optioneel expected voor vergelijking.
(
  int,
  int,
  String,
  WorkoutSplitPattern, {
  String? expectedPattern,
  List<String>? expectedPatternDays,
}) workouts_stap_6(
  List<String> availableDays,
  Map<String, Map<String, dynamic>> stap3Result,
  List<String>? muscleOrder, {
  String? expectedPattern,
  List<String>? expectedPatternDays,
  bool? setsBerekenen,
  int? setsoverride,
}) {
  debugPrint('\nWorkouts stap 6 – Trainingsdagen / split bepalen:');
  debugPrint('  Beschikbare dagen: $availableDays');
  debugPrint('  Muscle order (prioriteit): $muscleOrder');

  var totalSetsPerWeek = 0;
  var highestFreq = 0;
  for (final entry in stap3Result.entries) {
    final map = entry.value;
    final freq = (map['freq'] as int?) ?? 0;
    final setsPerSession =
        (map['setsPerSession'] as List<dynamic>?)?.cast<int>() ?? <int>[];
    final setsPerWeek = setsPerSession.fold<int>(0, (previous, element) => previous + (element as int));
    totalSetsPerWeek += setsPerWeek;
    if (freq > highestFreq) highestFreq = freq;
  }
  totalSetsPerWeek = setsoverride ?? totalSetsPerWeek;

  debugPrint('  Totaal sets per week: $totalSetsPerWeek');
  debugPrint('  Hoogste spier-frequentie: $highestFreq');

  final givenFreq = highestFreq.clamp(1, 3).toString();
  final match = step6LookupTable.where((e) =>
      listEquals(e.days, availableDays) &&
      _isTotalSetsInGivenSetsRange(totalSetsPerWeek, e.givenSets) &&
      e.givenFreq == givenFreq).firstOrNull;

  final resolvedGivenSets = match?.givenSets ?? '?';
  debugPrint('  givenSets: $resolvedGivenSets (totalSetsPerWeek=$totalSetsPerWeek), givenFreq: $givenFreq');

  final String pattern;
  final List<WorkoutDayDefinition> days;
  if (match != null) {
    debugPrint('  [Stap 6 lookup] expectedPattern: ${match.expectedPattern}');
    debugPrint('  [Stap 6 lookup] expectedPatternDays: ${match.expectedPatternDays}');
    pattern = match.expectedPattern;
    final patternDays = match.expectedPatternDays;
    days = [
      for (var i = 0; i < pattern.length && i < patternDays.length; i++)
        WorkoutDayDefinition(
          weekday: patternDays[i],
          type: _patternCharToType(pattern[i]),
        ),
    ];
  } else {
    debugPrint('  [Stap 6 lookup] Geen match voor days=$availableDays, totalSetsPerWeek=$totalSetsPerWeek, givenFreq=$givenFreq');
    pattern = '';
    days = [];
  }

  final caseInfo = 'Lookup: days=$availableDays, givenSets=$resolvedGivenSets, givenFreq=$givenFreq';

  return (
    totalSetsPerWeek,
    highestFreq,
    caseInfo,
    WorkoutSplitPattern(pattern: pattern, days: days),
    expectedPattern: expectedPattern,
    expectedPatternDays: expectedPatternDays,
  );
}

/// Resultaat van stap 7: spiergroepen per dag + per groep welk "sets-slot" (1e, 2e, 3e sessie) is toegewezen.
///
/// [perDayGroupSessionIndex]: per dag, voor elke spiergroep op die dag de sessie-index (0 = eerste
/// aantal sets, 1 = tweede, 2 = derde). Bijv. Chest Freq=3 Sets=[4,3,3]: als op dag 0 de 4 sets
/// zitten, dan sessionIndex=0; op de andere twee dagen 3 sets elk met sessionIndex 1 en 2.
typedef Stap7Result = ({
  List<List<String>> perDayGroups,
  List<List<int>> perDayGroupSessionIndex,
  String infoText,
});

/// Eén spier/subspier met aantal sets voor stap 8.
typedef Stap8MuscleSetsEntry = ({String name, int sets});

/// Resultaat van stap 8: per dag een lijst van (spier/subspiernaam, aantal sets).
typedef Stap8Result = ({
  List<List<Stap8MuscleSetsEntry>> perDayMuscleSets,
});

/// Eén oefening met aantal sets (stap 10).
/// [rir] en [restSeconds] worden gebruikt in het edit-workout-scherm en opgeslagen.
typedef Stap10ExerciseEntry = ({
  String name,
  int sets,
  String reps,
  String restTime,
  String rir,
  int restSeconds,
});

/// Resultaat van stap 10: per dag een lijst van (oefeningnaam, aantal sets).
typedef Stap10Result = ({
  List<List<Stap10ExerciseEntry>> perDayExercises,
});

/// Spiergroepen die in stap 8 worden vervangen door hun subspieren (met sets uit stap 2 per slot).
const Set<String> _stap8GroupsWithSubspieren = {
  'Chest',
  'Shoulders',
  'Upper Back',
  'Quadriceps & Glutes',
};

/// Survey/muscleOrder gebruikt soms andere namen dan spiergroepen.json. Voor lookup in stap3Result.
const Map<String, String> _surveyGroupToStap3Key = {
  'Biceps': 'Elbow Flexers',
};

/// Stap3/spiergroepen.json groepsnaam → naam zoals in stap 8 output en oefeninglijst (voor oefeninglookup).
const Map<String, String> _stap3KeyToStep8Name = {
  'Elbow Flexers': 'Biceps',
};

/// Resultaat van dagkeuze in stap 7: welke dagen + in welke volgorde de sessies (0e, 1e, 2e) over die dagen gaan.
typedef Stap7Choice = ({List<int> dayIndices, List<int> sessionOrder});

// Input:
// - workoutSplit: List<String> = ['A', 'B', 'C']
// - muscleOrder: List<String> = ['Chest', 'Shoulders', 'Back']
// - stap3Result: Map<String, Map<String, dynamic>> = { 'Chest': {'freq': 3, 'setsPerSession': [3, 3, 3]}, ... }
// Output: perDayGroups + perDayGroupSessionIndex + infoText.
// perDayGroupSessionIndex[dayIndex][k] = welk sets-slot (0, 1 of 2) hoort bij de spiergroep perDayGroups[dayIndex][k].
Stap7Result workouts_stap_7(
  List<String> workoutSplit,
  List<String> muscleOrder,
  Map<String, Map<String, dynamic>> stap3Result,
) {
  return _workoutsStap7Impl(workoutSplit, muscleOrder, stap3Result);
}

/// Nieuwe implementatie van stap 7 volgens `AAA_Documentatie.md` (regels 939‑997).
///
/// Input:
/// - [workoutSplit]: pattern uit stap 6, bijv. ['A','B','C','B'].
/// - [muscleOrder]: prioriteitsvolgorde uit stap 5.
/// - [stap3Result]: per spiergroep { 'freq': int, 'setsPerSession': List<int> } uit stap 3.
///
/// Output:
/// - Record met:
///   - [perDayGroups]: per workout‑dag de spiergroepen.
///   - [perDayGroupSessionIndex]: per dag, per spiergroep de sessie-index (0=eerste sets, 1=tweede, 2=derde).
///   - [infoText]: leesbare tekst met verdeling en sets.
Stap7Result _workoutsStap7Impl(
  List<String> workoutSplit,
  List<String> muscleOrder,
  Map<String, Map<String, dynamic>> stap3Result,
) {
  final List<List<String>> splitLists =
      List.generate(workoutSplit.length, (_) => <String>[]);
  /// Per dag: voor elke spiergroep op die dag welk sets-slot (0, 1, 2) is toegewezen.
  final List<List<int>> splitListsSessionIndex =
      List.generate(workoutSplit.length, (_) => <int>[]);
  final List<int> dayTotalSets = List<int>.filled(workoutSplit.length, 0);
  final buffer = StringBuffer();

  final Map<String, List<int>> indicesByLetter = {
    'A': <int>[],
    'B': <int>[],
    'C': <int>[],
  };
  for (var i = 0; i < workoutSplit.length; i++) {
    final letter = workoutSplit[i].toUpperCase();
    if (indicesByLetter.containsKey(letter)) {
      indicesByLetter[letter]!.add(i);
    }
  }

  int _getDayIndex(String letter, int ordinal) {
    final list = indicesByLetter[letter] ?? const <int>[];
    if (ordinal <= 0 || ordinal > list.length) return -1;
    return list[ordinal - 1];
  }

  /// Genereert alle permutaties van [0, 1, ..., n-1].
  List<List<int>> _permutations(int n) {
    if (n <= 0) return [[]];
    if (n == 1) return [[0]];
    final result = <List<int>>[];
    void generate(List<int> prefix, Set<int> used) {
      if (prefix.length == n) {
        result.add(List.from(prefix));
        return;
      }
      for (var i = 0; i < n; i++) {
        if (used.contains(i)) continue;
        used.add(i);
        prefix.add(i);
        generate(prefix, used);
        prefix.removeLast();
        used.remove(i);
      }
    }
    generate([], {});
    return result;
  }

  /// Berekent totaalSetsVerschil (som van gekwadrateerde afwijkingen t.o.v. gemiddelde).
  /// [sessionOrder]: welke sessie-index (0,1,2) naar welke positie in de optie gaat.
  /// sessionSets[sessionOrder[i]] wordt toegevoegd aan day optionIndices[i].
  /// Als [sessionOrder] null is, wordt identity gebruikt (eerste sessie naar eerste dag, etc.).
  double _totaalSetsVerschilForOption(
    List<int> optionIndices,
    List<int> sessionSets, {
    List<int>? sessionOrder,
  }) {
    if (dayTotalSets.isEmpty) return 0.0;

    final order = sessionOrder ?? List.generate(sessionSets.length.clamp(0, optionIndices.length), (i) => i);
    final newTotals = List<int>.from(dayTotalSets);
    for (var i = 0; i < optionIndices.length && i < order.length; i++) {
      final idx = optionIndices[i];
      final sessionIdx = order[i];
      if (idx < 0 || idx >= newTotals.length) continue;
      if (sessionIdx >= sessionSets.length) continue;
      newTotals[idx] += sessionSets[sessionIdx];
    }

    final total = newTotals.fold<int>(0, (a, b) => a + b);
    if (total == 0) return 0.0;

    final avg = total / newTotals.length;
    var sumSq = 0.0;
    for (final v in newTotals) {
      final diff = v - avg;
      sumSq += diff * diff;
    }
    return sumSq;
  }

  /// Bepaalt voor een lijst opties (dag-indices) de beste optie én de beste permutatie van
  /// sessies over die dagen (zodat totaalSetsVerschil minimaal is).
  Stap7Choice _bestOptionAndPermutation(
    List<List<int>> options,
    List<int> sessionSets,
  ) {
    List<int>? bestOption;
    List<int>? bestOrder;
    double? bestScore;
    final perms = _permutations(sessionSets.length);
    for (final opt in options) {
      if (opt.length != sessionSets.length) continue;
      for (final perm in perms) {
        final score = _totaalSetsVerschilForOption(opt, sessionSets, sessionOrder: perm);
        if (bestScore == null || score < bestScore!) {
          bestScore = score;
          bestOption = opt;
          bestOrder = perm;
        }
      }
    }
    return (
      dayIndices: bestOption ?? options.firstOrNull ?? [],
      sessionOrder: bestOrder ?? List.generate(sessionSets.length, (i) => i),
    );
  }

  void _assignToDays(
    String groupName,
    List<int> indices,
    List<int> sessionSets,
    List<int> sessionOrder,
  ) {
    for (var i = 0; i < indices.length && i < sessionOrder.length; i++) {
      final idx = indices[i];
      final sessIdx = sessionOrder[i];
      if (idx < 0 || idx >= splitLists.length) continue;
      if (sessIdx >= sessionSets.length) continue;
      splitLists[idx].add(groupName);
      splitListsSessionIndex[idx].add(sessIdx); // welk sets-slot (0e, 1e, 2e)
      dayTotalSets[idx] += sessionSets[sessIdx];
    }
  }

  int? _minLoadIndex(Iterable<int> indices) {
    int? best;
    for (final idx in indices) {
      if (idx < 0 || idx >= dayTotalSets.length) continue;
      if (best == null || dayTotalSets[idx] < dayTotalSets[best]) {
        best = idx;
      }
    }
    return best;
  }

  double _currentBPercentage() {
    var bSets = 0;
    var total = 0;
    for (var i = 0; i < workoutSplit.length; i++) {
      final letter = workoutSplit[i].toUpperCase();
      final sets = dayTotalSets[i];
      total += sets;
      if (letter == 'B') bSets += sets;
    }
    if (total == 0) return 0.0;
    return bSets / total;
  }

  /// Aandeel van het totaal aantal sets dat op de gegeven dag-indices zit (0.0–1.0).
  double _setsShareForDays(List<int> dayIndices) {
    final total = dayTotalSets.fold<int>(0, (a, b) => a + b);
    if (total == 0) return 0.0;
    var sum = 0;
    for (final idx in dayIndices) {
      if (idx >= 0 && idx < dayTotalSets.length) sum += dayTotalSets[idx];
    }
    return sum / total;
  }

  final pattern = workoutSplit.map((c) => c.toUpperCase()).join();

  for (final group in muscleOrder) {
    final stap3Key = _surveyGroupToStap3Key[group] ?? group;
    final info = stap3Result[stap3Key];
    if (info == null) continue;

    final freq = (info['freq'] as int?) ?? 0;
    if (freq <= 0) continue;

    final setsPerSessionDynamic =
        (info['setsPerSession'] as List<dynamic>?)?.cast<int>() ?? <int>[];
    if (setsPerSessionDynamic.isEmpty) continue;

    final sessionSets = setsPerSessionDynamic.take(freq.clamp(1, 3)).toList();

    // sort the pattern alphabetically
    final sortedPattern = (pattern.split('')..sort()).join();
    // print('original pattern: $pattern');
    // print('sorted pattern: $sortedPattern');

    Stap7Choice _chooseDaysForGroup() {
      switch (sortedPattern) {
        case 'A':
          final a1 = _getDayIndex('A', 1);
          return (dayIndices: [a1], sessionOrder: [0]);

        case 'ABC':
          if (freq == 1) {
            final a1 = _getDayIndex('A', 1);
            final b1 = _getDayIndex('B', 1);
            final c1 = _getDayIndex('C', 1);
            final idx = _minLoadIndex([a1, b1, c1]);
            return (dayIndices: [idx ?? a1], sessionOrder: [0]);
          } else if (freq == 2) {
            final a1 = _getDayIndex('A', 1);
            final b1 = _getDayIndex('B', 1);
            final c1 = _getDayIndex('C', 1);
            return _bestOptionAndPermutation([[a1, b1], [a1, c1]], sessionSets);
          }
          break;

        case 'ABBC': /// ABCB in elke volgorde
          if (freq == 1) {
            final a1 = _getDayIndex('A', 1);
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final c1 = _getDayIndex('C', 1);
            final idx = _minLoadIndex([c1, b2, a1, b1]);
            return (dayIndices: [idx ?? a1], sessionOrder: [0]);
          } else if (freq == 2) {
            final a1 = _getDayIndex('A', 1);
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final c1 = _getDayIndex('C', 1);
            final options = <List<int>>[
              [b1, b2],
              [a1, b1],
              [a1, c1],
              [a1, b2],
            ];
            return _bestOptionAndPermutation(options, sessionSets);
          } else if (freq == 3) {
            final a1 = _getDayIndex('A', 1);
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final c1 = _getDayIndex('C', 1);
            final shareA_B1_B2 = _setsShareForDays([a1, b1, b2]);
            if (shareA_B1_B2 > 0.75) {
              // Frequentie verlagen naar 2, beste optie voor freq==2 toepassen
              info['freq'] = 2;
              info['setsPerSession'] =
                  List<int>.from(setsPerSessionDynamic.take(2));
              final options = <List<int>>[
                [b1, b2],
                [a1, b1],
                [a1, c1],
                [a1, b2],
              ];
              final reducedSessionSets =
                  List<int>.from(setsPerSessionDynamic.take(2));
              return _bestOptionAndPermutation(options, reducedSessionSets);
            } else {
              return _bestOptionAndPermutation([[a1, b1, b2]], sessionSets);
            }
          }
          break;

        case 'ABBCC': /// ABCBC in elke volgorde
          if (freq == 1) {
            final a1 = _getDayIndex('A', 1);
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            final idx = _minLoadIndex([b1, c1, b2, c2, a1]);
            return (dayIndices: [idx ?? a1], sessionOrder: [0]);
          } else if (freq == 2) {
            final a1 = _getDayIndex('A', 1);
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            final options = <List<int>>[
              [b1, b2],
              [c1, c2],
              [a1, b1],
              [a1, c1],
              [a1, b2],
              [a1, c2],
            ];
            return _bestOptionAndPermutation(options, sessionSets);
          } else if (freq == 3) {
            final a1 = _getDayIndex('A', 1);
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            return _bestOptionAndPermutation([[a1, b1, b2], [a1, c1, c2]], sessionSets);
          }
          break;

        case 'AA':
          if (freq == 1) {
            final a1 = _getDayIndex('A', 1);
            final a2 = _getDayIndex('A', 2);
            final idx = _minLoadIndex([a1, a2]);
            return (dayIndices: [idx ?? a1], sessionOrder: [0]);
          } else if (freq >= 2) {
            final a1 = _getDayIndex('A', 1);
            final a2 = _getDayIndex('A', 2);
            return (dayIndices: [a1, a2], sessionOrder: [0, 1]);
          }
          break;

        case 'AABC': /// BCAA in elke volgorde
          if (freq == 1) {
            final a1 = _getDayIndex('A', 1);
            final a2 = _getDayIndex('A', 2);
            final b1 = _getDayIndex('B', 1);
            final c1 = _getDayIndex('C', 1);
            final idx = _minLoadIndex([a1, a2, b1, c1]);
            return (dayIndices: [idx ?? a1], sessionOrder: [0]);
          } else if (freq == 2) {
            final a1 = _getDayIndex('A', 1);
            final a2 = _getDayIndex('A', 2);
            final b1 = _getDayIndex('B', 1);
            final c1 = _getDayIndex('C', 1);
            final options = <List<int>>[
              [a1, b1],
              [a2, b1],
              [a1, c1],
              [a2, c1],
              [a1, a2],
            ];
            return _bestOptionAndPermutation(options, sessionSets);
          } else if (freq == 3) {
            final a1 = _getDayIndex('A', 1);
            final a2 = _getDayIndex('A', 2);
            final b1 = _getDayIndex('B', 1);
            final c1 = _getDayIndex('C', 1);
            return _bestOptionAndPermutation([[a1, a2, b1], [a1, a2, c1]], sessionSets);
          }
          break;

        case 'AAA':
          if (freq == 1) {
            final a1 = _getDayIndex('A', 1);
            final a2 = _getDayIndex('A', 2);
            final a3 = _getDayIndex('A', 3);
            final idx = _minLoadIndex([a1, a2, a3]);
            return (dayIndices: [idx ?? a1], sessionOrder: [0]);
          } else if (freq == 2) {
            final a1 = _getDayIndex('A', 1);
            final a2 = _getDayIndex('A', 2);
            final a3 = _getDayIndex('A', 3);
            final options = <List<int>>[
              [a1, a2],
              [a1, a3],
              [a2, a3],
            ];
            return _bestOptionAndPermutation(options, sessionSets);
          } else if (freq >= 3) {
            final a1 = _getDayIndex('A', 1);
            final a2 = _getDayIndex('A', 2);
            final a3 = _getDayIndex('A', 3);
            return (dayIndices: [a1, a2, a3], sessionOrder: [0, 1, 2]);
          }
          break;

        case 'BC':
          if (freq >= 1) {
            final b1 = _getDayIndex('B', 1);
            final c1 = _getDayIndex('C', 1);
            final idx = _minLoadIndex([b1, c1]);
            return (dayIndices: [idx ?? b1], sessionOrder: [0]);
          }
          break;

        case 'BBC': /// BCB in elke volgorde
          if (freq == 1) {
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final c1 = _getDayIndex('C', 1);
            final idx = _minLoadIndex([c1, b1, b2]);
            return (dayIndices: [idx ?? b1], sessionOrder: [0]);
          } else if (freq == 2) {
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final c1 = _getDayIndex('C', 1);
            final bShare = _currentBPercentage();
            if (bShare >= 0.67) {
              // Frequentie verlagen naar 1: laatste sets weg, gedragen als freq=1
              info['freq'] = 1;
              info['setsPerSession'] =
                  List<int>.from(setsPerSessionDynamic.take(1));
              final idx = _minLoadIndex([b1, b2, c1]);
              return (dayIndices: [idx ?? b1], sessionOrder: [0]);
            } else {
              return _bestOptionAndPermutation([[b1, b2]], sessionSets);
            }
          }
          break;

        case 'BBCC': /// BCBC in elke volgorde
          if (freq == 1) {
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            final idx = _minLoadIndex([b1, c1, b2, c2]);
            return (dayIndices: [idx ?? b1], sessionOrder: [0]);
          } else if (freq == 2) {
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            return _bestOptionAndPermutation([[b1, b2], [c1, c2]], sessionSets);
          }
          break;

        case 'BBBCC': /// BCBCB in elke volgorde
          if (freq == 1) {
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final b3 = _getDayIndex('B', 3);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            final idx = _minLoadIndex([b1, c1, b2, c2, b3]);
            return (dayIndices: [idx ?? b1], sessionOrder: [0]);
          } else if (freq == 2) {
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final b3 = _getDayIndex('B', 3);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            final options = <List<int>>[
              [c1, c2],
              [b1, b2],
              [b1, b3],
              [b2, b3],
            ];
            return _bestOptionAndPermutation(options, sessionSets);
          } else if (freq == 3) {
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final b3 = _getDayIndex('B', 3);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            final shareB1_B2_B3 = _setsShareForDays([b1, b2, b3]);
            if (shareB1_B2_B3 > 0.60) {
              // Frequentie verlagen naar 2, beste optie voor freq==2 toepassen
              info['freq'] = 2;
              info['setsPerSession'] =
                  List<int>.from(setsPerSessionDynamic.take(2));
              final options = <List<int>>[
                [c1, c2],
                [b1, b2],
                [b1, b3],
                [b2, b3],
              ];
              final reducedSessionSets =
                  List<int>.from(setsPerSessionDynamic.take(2));
              return _bestOptionAndPermutation(options, reducedSessionSets);
            } else {
              return _bestOptionAndPermutation([[b1, b2, b3]], sessionSets);
            }
          }
          break;

        case 'BBBCCC': /// BCBCBC in elke volgorde
          if (freq == 1) {
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final b3 = _getDayIndex('B', 3);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            final c3 = _getDayIndex('C', 3);
            final idx = _minLoadIndex([b1, c1, b2, c2, b3, c3]);
            return (dayIndices: [idx ?? b1], sessionOrder: [0]);
          } else if (freq == 2) {
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final b3 = _getDayIndex('B', 3);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            final c3 = _getDayIndex('C', 3);
            final options = <List<int>>[
              [b1, b2],
              [b1, b3],
              [b2, b3],
              [c1, c2],
              [c1, c3],
              [c2, c3],
            ];
            return _bestOptionAndPermutation(options, sessionSets);
          } else if (freq == 3) {
            final b1 = _getDayIndex('B', 1);
            final b2 = _getDayIndex('B', 2);
            final b3 = _getDayIndex('B', 3);
            final c1 = _getDayIndex('C', 1);
            final c2 = _getDayIndex('C', 2);
            final c3 = _getDayIndex('C', 3);
            return _bestOptionAndPermutation([[b1, b2, b3], [c1, c2, c3]], sessionSets);
          }
          break;
      }

      // Fallback: verdeel sessies greedy over de lichtste dagen (behoud B/C‑regel).
      // Elke sessie komt op een andere dag (geen dubbele toevoeging van dezelfde spiergroep op één dag).
      final result = <int>[];
      for (var i = 0; i < sessionSets.length; i++) {
        int? best;
        for (var d = 0; d < workoutSplit.length; d++) {
          // if (result.contains(d)) continue; // dag al gekozen voor een eerdere sessie
          final letter = workoutSplit[d].toUpperCase();
          final alreadyHasB = result
              .any((idx) => workoutSplit[idx].toUpperCase() == 'B');
          final alreadyHasC = result
              .any((idx) => workoutSplit[idx].toUpperCase() == 'C');
          if ((letter == 'B' && alreadyHasC) ||
              (letter == 'C' && alreadyHasB)) {
            continue;
          }
          if (best == null || dayTotalSets[d] < dayTotalSets[best]) {
            best = d;
          }
        }
        result.add(best ?? 0);
      }
      return (
        dayIndices: result,
        sessionOrder: List.generate(sessionSets.length, (i) => i),
      );
    }

    final chosen = _chooseDaysForGroup();
    _assignToDays(stap3Key, chosen.dayIndices, sessionSets, chosen.sessionOrder);
  }

  debugPrint('Workouts stap 7 – verdeling spiergroepen per dag:');
  for (var i = 0; i < splitLists.length; i++) {
    final line =
        'Dag ${i + 1} (${workoutSplit[i]}): ${splitLists[i]} (sets=${dayTotalSets[i]})';
    debugPrint('  $line');
    buffer.writeln(line);
  }

  return (
    perDayGroups: splitLists,
    perDayGroupSessionIndex: splitListsSessionIndex,
    infoText: buffer.toString().trimRight(),
  );
}

/// Laadt uit spiergroepen.json de mapping: groep (naam) -> lijst subspier-namen (survey).
/// Alleen voor de 4 groepen in [_stap8GroupsWithSubspieren].
Future<Map<String, List<String>>> _loadStap8GroupToSubspieren() async {
  final spiergroepenJson = await rootBundle.loadString(
    'lib/workouts_info/spiergroepen.json',
  );
  final spiergroepenData = jsonDecode(spiergroepenJson) as Map<String, dynamic>;
  final spiergroepenList = spiergroepenData['spiergroepen'] as List<dynamic>;
  final result = <String, List<String>>{};
  for (final entry in spiergroepenList) {
    final map = entry as Map<String, dynamic>;
    final spiergroep = map['naam'] as String? ?? '';
    if (!_stap8GroupsWithSubspieren.contains(spiergroep)) continue;
    final spierenRaw = map['spieren'] as List<dynamic>? ?? [];
    final subspieren = spierenRaw
        .map((s) {
          final naam = (s as Map<String, dynamic>)['naam'] as String? ?? '';
          return _spiergroepJsonNaamToSurvey[naam] ?? naam;
        })
        .toSet()
        .toList();
    result[spiergroep] = subspieren;
  }
  return result;
}

/// Zoekt de key in [spierFreqSets] die overeenkomt met [surveyNaam] (genormaliseerd).
String? _findSpierKeyInStap2(
  Map<String, Map<String, int>> spierFreqSets,
  String surveyNaam,
) {
  final norm = _normSpier(surveyNaam);
  for (final k in spierFreqSets.keys) {
    if (_normSpier(k) == norm) return k;
  }
  return null;
}

/// Stap 8 — Van spiergroepen per dag naar subspieren (of spier) met aantal sets per dag.
///
/// Voor de 4 groepen (Chest, Shoulders, Upper Back, Quadriceps & Glutes): vervang door
/// subspieren; per subspier alleen toevoegen als die op het toegewezen slot (eerste/tweede/derde)
/// sets heeft, met het aantal sets uit stap 2 voor dat slot.
/// Voor overige groepen: gebruik het aantal sets uit stap 3 voor het toegewezen slot.
Future<Stap8Result> workouts_stap_8(
  Stap7Result stap7Result,
  Map<String, Map<String, int>> stap2Result,
  Map<String, Map<String, dynamic>> stap3Result,
  List<String> workoutSplit, {
  List<WorkoutDayDefinition>? stap6Days,
}) async {
  debugPrint('\nWorkouts stap 8 – spiergroepen → subspieren met sets:');
  final groupToSubspieren = await _loadStap8GroupToSubspieren();
  final perDayGroups = stap7Result.perDayGroups;
  final perDayGroupSessionIndex = stap7Result.perDayGroupSessionIndex;
  final perDayMuscleSets = <List<Stap8MuscleSetsEntry>>[];

  for (var d = 0; d < perDayGroups.length; d++) {
    final letter = d < workoutSplit.length ? workoutSplit[d] : '?';
    final weekday = (stap6Days != null && d < stap6Days.length)
        ? stap6Days[d].weekday
        : 'Dag ${d + 1}';
    final groups = perDayGroups[d];
    final sessionIndices = d < perDayGroupSessionIndex.length
        ? perDayGroupSessionIndex[d]
        : <int>[];
    final dayEntries = <Stap8MuscleSetsEntry>[];

    for (var k = 0; k < groups.length; k++) {
      final groupName = groups[k];
      final sessionIndex = k < sessionIndices.length ? sessionIndices[k] : 0;

      if (_stap8GroupsWithSubspieren.contains(groupName)) {
        final subspieren = groupToSubspieren[groupName];
        if (subspieren != null) {
          for (final subName in subspieren) {
            final key = _findSpierKeyInStap2(stap2Result, subName);
            if (key == null) continue;
            final spec = stap2Result[key]!;
            final freq = spec['freq'] ?? 0;
            final sets = spec['sets'] ?? 0;
            if (freq > sessionIndex) {
              dayEntries.add((name: key, sets: sets));
            }
          }
        }
      } else {
        final info = stap3Result[groupName];
        if (info != null) {
          final setsPerSession =
              (info['setsPerSession'] as List<dynamic>?)?.cast<int>() ?? [];
          final sets = (sessionIndex < setsPerSession.length)
              ? setsPerSession[sessionIndex]
              : 0;
          if (sets > 0) {
            final entryName = _stap3KeyToStep8Name[groupName] ?? groupName;
            dayEntries.add((name: entryName, sets: sets));
          }
        }
      }
    }

    perDayMuscleSets.add(dayEntries);
    final parts = dayEntries.map((e) => '${e.name}: ${e.sets}').join(', ');
    debugPrint('  $weekday ($letter): $parts');
  }

  return (perDayMuscleSets: perDayMuscleSets);
}

/// Mapping: (sub)spiernaam (zoals in stap 8) → spiergroepnaam (voor spiervolgorde stap 5).
Future<Map<String, String>> _loadStap9MuscleNameToGroup() async {
  final groupToSub = await _loadStap8GroupToSubspieren();
  final result = <String, String>{};
  for (final entry in groupToSub.entries) {
    for (final subName in entry.value) {
      result[subName] = entry.key;
    }
  }
  return result;
}

/// Bepaalt de spiergroep (stap 5-naam) voor een entry uit stap 8.
/// Subspieren (Mid chest, etc.) → groep (Chest); overige namen → zichzelf.
String _stap9EntryToGroup(String entryName, Map<String, String> muscleNameToGroup) {
  return muscleNameToGroup[entryName] ?? entryName;
}

/// Spiervolgorde stap 9: per groep de vaste volgorde van subspieren (zoals in stap 8).
/// Alleen de 4 groepen met subspieren; overige groepen blijven als één item.
const Map<String, List<String>> _stap9GroupToSubspierenOrder = {
  'Chest': ['Mid chest', 'Upper chest'],
  'Shoulders': ['Side delts', 'Front delts'],
  'Upper Back': ['Rear delts', 'Mid traps', 'Upper traps'],
  'Quadriceps & Glutes': ['Rectus Femoris', 'Vastus Muscles', 'Gluteus Maximus', 'Upper Glutes'],
};

/// Zet spiervolgorde stap 5 (groepen) om naar volgorde met subspieren voor stap 9.
/// Chest → Mid chest, Upper chest; Shoulders → Side delts, Front delts; etc.
List<String> _stap9ExpandMuscleOrder(List<String> muscleOrder) {
  final result = <String>[];
  for (final group in muscleOrder) {
    final subs = _stap9GroupToSubspierenOrder[group];
    if (subs != null) {
      result.addAll(subs);
    } else {
      result.add(group);
    }
  }
  return result;
}

/// Laadt alle oefeningen uit oefeninglijst.json (plat: per oefening name + trainedMuscles).
Future<List<({String name, List<String> trainedMuscles})>> _loadStap9ExercisesFlat() async {
  final oefeninglijstJson = await rootBundle.loadString(
    'lib/workouts_info/oefeninglijst.json',
  );
  final oefeninglijst = jsonDecode(oefeninglijstJson) as Map<String, dynamic>;
  final exerciseList = oefeninglijst['exerciseList'] as List<dynamic>;
  final result = <({String name, List<String> trainedMuscles})>[];
  for (final exEntry in exerciseList) {
    final exMap = exEntry as Map<String, dynamic>;
    final exercises = exMap['exercises'] as List<dynamic>? ?? [];
    for (final ex in exercises) {
      final exData = ex as Map<String, dynamic>;
      final name = exData['name'] as String? ?? '';
      final trained = (exData['trainedMuscles'] as List<dynamic>?)
          ?.map((m) => (m as String).trim())
          .toList() ?? [];
      if (name.isNotEmpty) result.add((name: name, trainedMuscles: trained));
    }
  }
  return result;
}

/// Berekent het effectieve aantal sets voor een dag (overlapcorrectie zoals in stap 3).
/// Eén oefening die meerdere spieren traint telt maar één keer per set.
int _stap9EffectiveSetsForDay(
  List<Stap8MuscleSetsEntry> dayEntries,
  List<({String name, List<String> trainedMuscles})> exercisesFlat,
) {
  final remaining = <String, int>{
    for (final e in dayEntries) e.name: e.sets,
  };
  var totalEffective = 0;
  for (final ex in exercisesFlat) {
    final trained = ex.trainedMuscles;
    final relevantKeys = remaining.keys
        .where((k) =>
            trained.any((t) => _normSpier(t) == _normSpier(k)) && (remaining[k] ?? 0) > 0)
        .toList();
    if (relevantKeys.isEmpty) continue;
    var x = 0;
    for (final k in relevantKeys) {
      final r = remaining[k]!;
      if (r > x) x = r;
    }
    if (x == 0) continue;
    totalEffective += x;
    for (final k in relevantKeys) {
      remaining[k] = (remaining[k]! - x).clamp(0, 0x7fffffff);
    }
  }
  return totalEffective;
}

/// Stap 9 — Workouts inkorten tot maximaal 25 effectieve sets per dag.
///
/// Effectieve sets worden berekend met dezelfde logica als stap 10 (oefeningstoewijzing + overlap),
/// zodat het getal overeenkomt met het aantal sets dat stap 10 daadwerkelijk uitvoert.
/// Verwijdering in round-robin: per ronde maximaal 1 set per (sub)spier (van achter naar voren).
///
/// [stap8Result] wordt gemuteerd (perDayMuscleSets wordt aangepast).
Future<void> workouts_stap_9(
  Stap8Result stap8Result,
  List<String> muscleOrder,
  Map<String, dynamic> muscles,
) async {
  debugPrint('\nWorkouts stap 9 – inkorten tot max 25 effectieve sets per workout (zelfde telling als stap 10):');
  if (muscleOrder.isEmpty) {
    debugPrint(
      '  Waarschuwing: spiervolgorde (stap 5) is leeg – geen sets worden verwijderd.',
    );
  }
  final expandedOrder = _stap9ExpandMuscleOrder(muscleOrder);
  final stap10Data = await _loadStap10ExerciseData();
  const maxSetsPerWorkout = 25;
  final perDayMuscleSets = stap8Result.perDayMuscleSets;

  int effectiveSetsForDay(List<Stap8MuscleSetsEntry> dayEntries) =>
      _stap10CountEffectiveSetsForDay(
        dayEntries,
        stap10Data.muscleToExercises,
        stap10Data.exerciseToTrainedMuscles,
        muscles,
      );

  for (var d = 0; d < perDayMuscleSets.length; d++) {
    final dayEntries = perDayMuscleSets[d];
    var effectiveSets = effectiveSetsForDay(dayEntries);
    final rawSum = dayEntries.fold<int>(0, (sum, e) => sum + e.sets);

    debugPrint(
      '  Dag ${d + 1}: som van sets = $rawSum, effectieve sets (zoals stap 10) = $effectiveSets (max $maxSetsPerWorkout), volgorde = ${expandedOrder.length} (sub)spieren',
    );

    while (effectiveSets > maxSetsPerWorkout) {
      var anyRemovedInRound = false;
      // Eén ronde: van laatste naar eerste in uitgebreide volgorde (subspieren), per item max 1 set eraf
      for (var g = expandedOrder.length - 1; g >= 0; g--) {
        if (effectiveSets <= maxSetsPerWorkout) break; // doel bereikt, stop direct
        final orderName = expandedOrder[g];
        for (var i = 0; i < dayEntries.length; i++) {
          final entry = dayEntries[i];
          if (_normSpier(entry.name) != _normSpier(orderName)) continue;
          if (entry.sets <= 0) continue;

          debugPrint(
            '  Dag ${d + 1}: 1 set minder voor ${entry.name} (${entry.sets} → ${entry.sets - 1})',
          );
          if (entry.sets == 1) {
            dayEntries.removeAt(i);
          } else {
            dayEntries[i] = (name: entry.name, sets: entry.sets - 1);
          }
          anyRemovedInRound = true;
          effectiveSets = effectiveSetsForDay(dayEntries);
          break; // slechts 1 set van deze groep deze ronde
        }
      }
      if (!anyRemovedInRound) {
        debugPrint(
          '  Dag ${d + 1}: geen set meer te verwijderen; stop bij $effectiveSets effectieve sets.',
        );
        break;
      }
    }

    final afterEffective = effectiveSetsForDay(dayEntries);
    final afterRaw = dayEntries.fold<int>(0, (sum, e) => sum + e.sets);
    debugPrint(
      '  Dag ${d + 1}: ${dayEntries.length} spieren, som sets=$afterRaw, effectieve sets=$afterEffective',
    );
  }
}

/// Bepaalt het volumeniveau (1–4) voor een (sub)spier; gebruikt [spiergroepToVolumeNiveau] met genormaliseerde naam.
int _stap10GetVolumeNiveauForSpier(String spierName) {
  final norm = _normSpier(spierName);
  for (final e in spiergroepToVolumeNiveau.entries) {
    if (_normSpier(e.key) == norm) return e.value;
  }
  return 2;
}

/// Weekdagnaam → dagnummer in de week (Maandag=1 … Zondag=7), voor berekening kalenderdagen.
const Map<String, int> _weekdayToDayNumber = {
  'Maandag': 1,
  'Dinsdag': 2,
  'Woensdag': 3,
  'Donderdag': 4,
  'Vrijdag': 5,
  'Zaterdag': 6,
  'Zondag': 7,
};

/// Stap 10 kan op 2 manieren gebruikt worden, op basis van setsBerekenen true/false
/// Als setsBerekenen true, dan wordt de stap 10 gebruikt om het totaal aantal sets per week te berekenen en wordt deze waarde gereturned
/// Als setsBerekenen false, dan wordt de stap 10 gebruikt om het complete workoutschema te maken
/// De output van stap 10 moet dus soms een integer zijn en soms een lijst van workouts
/// Stap 10 — Sets toevoegen aan subspieren op basis van condities (eerstvolgende training, sets, ranking, volume).
///
/// Input: de lijst van workouts na stap 9 (per dag: lijst van subspier + sets).
/// [weekdaysPerDay]: per dag de weekdagnaam (Maandag, …) voor berekening kalenderdagen tot volgende training.
/// Volgorde: omgekeerde subspiervolgorde t.o.v. stap 9 (dus gelijk aan survey).
/// Stopt als een workout 25 effectieve sets heeft of geen enkele subspier meer een set mag krijgen.
/// [stap8Result] wordt gemuteerd.
Future<int?> workouts_stap_10(
  Stap8Result stap8Result,
  List<String> muscleOrder,
  Map<String, dynamic> muscles, {
  List<String>? weekdaysPerDay,
  required bool setsBerekenen,
}) async {
  final maxSetsPerWorkout = setsBerekenen ? 0x7fffffff : 25;
  debugPrint(
    '\nWorkouts stap 10 – sets toevoegen (max effectieve sets per workout: $maxSetsPerWorkout) (condities):',
  );
  if (muscleOrder.isEmpty) {
    debugPrint('  Waarschuwing: spiervolgorde leeg – geen sets toegevoegd.');
    return null;
  }
  final expandedOrder = _stap9ExpandMuscleOrder(muscleOrder);
  final reversedOrder = expandedOrder.reversed.toList();
  final stap10Data = await _loadStap10ExerciseData();
  final perDayMuscleSets = stap8Result.perDayMuscleSets;
  final numDays = perDayMuscleSets.length;
  final beschikbareFrequentie = numDays;
  final weekdays = (weekdaysPerDay != null && weekdaysPerDay.length >= numDays)
      ? weekdaysPerDay
      : null;

  int effectiveSetsForDay(List<Stap8MuscleSetsEntry> dayEntries) =>
      _stap10CountEffectiveSetsForDay(
        dayEntries,
        stap10Data.muscleToExercises,
        stap10Data.exerciseToTrainedMuscles,
        muscles,
      );

  /// Aantal kalenderdagen tot de volgende keer dat deze subspier getraind wordt (zelfde week of volgende week).
  /// Maandag → Donderdag = 3, Donderdag → Maandag = 4. Als alleen op deze dag: 7.
  int daysUntilNextTraining(int currentDayIndex, String subspierKey) {
    final norm = _normSpier(subspierKey);
    var nextDayIndex = -1;
    for (var next = currentDayIndex + 1; next < numDays; next++) {
      final dayEntries = perDayMuscleSets[next];
      if (dayEntries.any((e) => _normSpier(e.name) == norm)) {
        nextDayIndex = next;
        break;
      }
    }
    if (nextDayIndex < 0) {
      for (var next = 0; next < currentDayIndex; next++) {
        final dayEntries = perDayMuscleSets[next];
        if (dayEntries.any((e) => _normSpier(e.name) == norm)) {
          nextDayIndex = next;
          break;
        }
      }
    }
    if (nextDayIndex < 0) return 7; // alleen op deze dag

    int fallbackDays() =>
        nextDayIndex > currentDayIndex
            ? nextDayIndex - currentDayIndex
            : (nextDayIndex - currentDayIndex + numDays) % numDays;

    if (weekdays == null) return fallbackDays();

    final currentKey = weekdays[currentDayIndex].toString().trim();
    final nextKey = weekdays[nextDayIndex].toString().trim();
    final currentNum = _weekdayToDayNumber[currentKey];
    final nextNum = _weekdayToDayNumber[nextKey];
    if (currentNum == null || nextNum == null) return fallbackDays();

    if (nextDayIndex > currentDayIndex) {
      return nextNum - currentNum; //zelfde week
    }
    return 7 - currentNum + nextNum; // volgende week
  }

  int currentSetsForSubspier(List<Stap8MuscleSetsEntry> dayEntries, String subspierKey) {
    final norm = _normSpier(subspierKey);
    for (final e in dayEntries) {
      if (_normSpier(e.name) == norm) return e.sets;
    }
    return 0;
  }

  void addOneSetToSubspier(List<Stap8MuscleSetsEntry> dayEntries, String subspierKey) {
    final norm = _normSpier(subspierKey);
    for (var i = 0; i < dayEntries.length; i++) {
      if (_normSpier(dayEntries[i].name) != norm) continue;
      dayEntries[i] = (name: dayEntries[i].name, sets: dayEntries[i].sets + 1);
      return;
    }
    dayEntries.add((name: subspierKey, sets: 1));
  }

  void _stap10RemoveOneSetFromSubspier(List<Stap8MuscleSetsEntry> dayEntries, String subspierKey) {
    final norm = _normSpier(subspierKey);
    for (var i = 0; i < dayEntries.length; i++) {
      if (_normSpier(dayEntries[i].name) != norm) continue;
      if (dayEntries[i].sets <= 1) {
        dayEntries.removeAt(i);
      } else {
        dayEntries[i] = (name: dayEntries[i].name, sets: dayEntries[i].sets - 1);
      }
      return;
    }
  }

  for (var d = 0; d < numDays; d++) {
    final dayEntries = perDayMuscleSets[d];
    var effectiveSets = effectiveSetsForDay(dayEntries);
    debugPrint('  Dag ${d + 1}: start effectieve sets = $effectiveSets');

    while (effectiveSets < maxSetsPerWorkout) {
      var addedAny = false;
      for (final orderName in reversedOrder) {
        if (effectiveSets >= maxSetsPerWorkout) break;
        final currentSets = currentSetsForSubspier(dayEntries, orderName);
        if (currentSets <= 0) continue;
        // if (currentSets >= 3) continue;

        final daysUntilNext = daysUntilNextTraining(d, orderName);
        final ranking = _stap10GetRankingForSpier(muscles, orderName);
        final actualFreq = _stap10GetActualFrequencyForSpier(muscles, beschikbareFrequentie, orderName);
        final is2xPerWeek = actualFreq == 2;
        final volumeNiveau = _stap10GetVolumeNiveauForSpier(orderName);

        if (!_stap10AddSetsCanAddOne(daysUntilNext, currentSets, ranking, is2xPerWeek, volumeNiveau)) {
          continue;
        }

        addOneSetToSubspier(dayEntries, orderName);
        final newEffective = effectiveSetsForDay(dayEntries);
        if (newEffective > maxSetsPerWorkout) {
          // Ongedaan maken: nooit meer dan 25 effectieve sets
          _stap10RemoveOneSetFromSubspier(dayEntries, orderName);
          continue;
        }
        effectiveSets = newEffective;
        addedAny = true;
        debugPrint(
          '  Dag ${d + 1}: +1 set voor $orderName (nu $currentSets→${currentSets + 1}), effectief=$effectiveSets',
        );
      }
      if (!addedAny) break;
    }

    final afterEffective = effectiveSetsForDay(dayEntries);
    debugPrint('  Dag ${d + 1}: na stap 10 effectieve sets = $afterEffective');
  }

  if (!setsBerekenen) return null;

  // Totaal sets per week = som van alle sets over alle dagen (raw sets, niet "effectief").
  // Dit is de waarde die we mappen naar givenSets-range voor stap 6 in pass 2.
  var totaalSetsPerWeek = 0;
  for (final dayEntries in perDayMuscleSets) {
    totaalSetsPerWeek += dayEntries.fold<int>(0, (sum, e) => sum + e.sets);
  }
  var totalEffective = 0;
  for (final dayEntries in perDayMuscleSets) {
    totalEffective += effectiveSetsForDay(dayEntries);
  }
  debugPrint('  [SetsBerekenen] Totaal sets per week (na stap 10) = $totaalSetsPerWeek, effectief=$totalEffective');
  return totalEffective;
}

/// Resultaat van het laden van de oefeninglijst voor stap 10.
typedef Stap10ExerciseListData = ({
  Map<String, List<String>> muscleToExercises,
  Map<String, List<String>> exerciseToTrainedMuscles,
  Map<String, ({String reps, String restTime})> exerciseMeta,
});

/// Laadt oefeninglijst: per spier de oefeningen in volgorde + per oefening de getrainde spieren en meta (reps, rest).
Future<Stap10ExerciseListData> _loadStap10ExerciseData() async {
  final json = await rootBundle.loadString('lib/workouts_info/oefeninglijst.json');
  final data = jsonDecode(json) as Map<String, dynamic>;
  final list = data['exerciseList'] as List<dynamic>;
  final muscleToExercises = <String, List<String>>{};
  final exerciseToTrainedMuscles = <String, List<String>>{};
  final exerciseMeta = <String, ({String reps, String restTime})>{};
  for (final entry in list) {
    final map = entry as Map<String, dynamic>;
    final muscleGroup = (map['muscleGroup'] as String? ?? '').trim();
    final exercises = map['exercises'] as List<dynamic>? ?? [];
    final names = <String>[];
    for (final e in exercises) {
      final exMap = e as Map<String, dynamic>;
      final name = exMap['name'] as String? ?? '';
      final trained = (exMap['trainedMuscles'] as List<dynamic>?)
          ?.map((m) => (m as String).trim())
          .toList() ?? [];
      if (name.isNotEmpty) {
        names.add(name);
        exerciseToTrainedMuscles[name] = trained;
        final reps = (exMap['reps'] as String? ?? '5-7').trim();
        final restTime = (exMap['restTime'] as String? ?? '').trim();
        exerciseMeta[name] = (reps: reps, restTime: restTime);
      }
    }
    if (muscleGroup.isNotEmpty && names.isNotEmpty) {
      muscleToExercises[_normSpier(muscleGroup)] = names;
    }
  }
  return (
    muscleToExercises: muscleToExercises,
    exerciseToTrainedMuscles: exerciseToTrainedMuscles,
    exerciseMeta: exerciseMeta,
  );
}

/// Trek [sets] af van remaining voor elke spier die [exerciseName] traint (overlapcorrectie).
void _stap10DeductTrained(
  Map<String, int> remaining,
  String exerciseName,
  int sets,
  Map<String, List<String>> exerciseToTrainedMuscles,
) {
  final trained = exerciseToTrainedMuscles[exerciseName];
  if (trained == null) return;
  for (final t in trained) {
    final key = _normSpier(t);
    final cur = remaining[key] ?? 0;
    remaining[key] = (cur - sets).clamp(0, 0x7fffffff);
  }
}

/// Haalt bias (0, 1 of 2) op voor een spier uit de survey-muscles map.
int _stap10GetBias(Map<String, dynamic> muscles, String muscleName) {
  for (final entry in muscles.entries) {
    if (_normSpier(entry.key) != _normSpier(muscleName)) continue;
    final info = entry.value;
    if (info is! Map) continue;
    final bias = (info['bias'] as num?)?.toInt();
    if (bias != null && bias >= 0 && bias <= 2) return bias;
    return 0;
  }
  return 0;
}

/// Verdeelt [totalSets] over eerste en tweede oefening volgens [bias] (0, 1 of 2).
/// Retourneert (setsEersteOefening, setsTweedeOefening).
(int, int) _stap10BiasSplit(int totalSets, int bias) {
  final b = bias.clamp(0, 2);
  if (totalSets <= 4) {
    const table = [
      [(0, 1), (0, 2), (1, 2), (1, 3)], // bias 0
      [(1, 0), (1, 1), (1, 2), (2, 2)], // bias 1
      [(1, 0), (2, 0), (2, 1), (3, 1)], // bias 2
    ];
    return table[b][totalSets - 1];
  }
  switch (b) {
    case 0:
      final first = (totalSets - 1) ~/ 2;
      return (first, totalSets - first);
    case 1:
      final first = totalSets ~/ 2;
      return (first, totalSets - first);
    case 2:
      final first = (totalSets + 1) ~/ 2;
      return (first, totalSets - first);
    default:
      return (totalSets ~/ 2, totalSets - (totalSets ~/ 2));
  }
}

/// Gegeven gewenste sets Side Delts (SD) en Front Delts (FD), bepaal aantal sets
/// Shoulder Press (SP) en Cable Lateral Raises (CR) volgens vaste tabel.
/// SD,FD → SP,CR: 0,0→0,0 0,1→1,0 0,2→2,0 0,3→3,0 |
/// 1,0→1,0 1,1→1,0 1,2→2,0 1,3→3,0 | 2,0→2,0 2,1→2,0 2,2→2,0 2,3→3,0 |
/// 3,0→2,1 3,1→2,1 3,2→2,1 3,3→3,1 | 4,0→2,2 4,1→2,2 4,2→2,2 4,3→3,2
(int, int) _shoulderPressAndCableLateralSets(int setsSide, int setsFront) {
  final sd = setsSide.clamp(0, 4);
  final fd = setsFront.clamp(0, 3);
  final cr = sd <= 2 ? 0 : (sd == 3 ? 1 : 2);
  final sp = fd == 3
      ? 3
      : (fd == 2 ? 2 : (fd == 1 ? (sd == 0 ? 1 : (sd <= 2 ? sd : 2)) : (sd <= 2 ? sd : 2)));
  return (sp, cr);
}

/// Oorspronkelijke ranking (1–10) voor een (sub)spier uit groeiNiveau via groeiNiveauToBesteTrainingRanking.
/// Geen downgrade op volume/frequentie; alleen de survey-ranking telt voor stap 10 (sets toevoegen).
int _stap10GetRankingForSpier(
  Map<String, dynamic> muscles,
  String spierName,
) {
  String? matchKey;
  for (final k in muscles.keys) {
    if (_normSpier(k) == _normSpier(spierName)) {
      matchKey = k;
      break;
    }
  }
  if (matchKey == null) return 10;
  final infoMap = muscles[matchKey];
  if (infoMap is! Map) return 10;
  final groeiNiveau = (infoMap['level'] as int?) ?? 0;
  return groeiNiveauToBesteTrainingRanking[groeiNiveau] ?? 10;
}

/// Daadwerkelijke trainingsfrequentie (0–3) voor een (sub)spier: gedowngradede ranking zoals in stap 2.
/// Gebruikt voor o.a. "2× per week" in de conditietabel van stap 10 (sets toevoegen).
int _stap10GetActualFrequencyForSpier(
  Map<String, dynamic> muscles,
  int beschikbareFrequentie,
  String spierName,
) {
  String? matchKey;
  for (final k in muscles.keys) {
    if (_normSpier(k) == _normSpier(spierName)) {
      matchKey = k;
      break;
    }
  }
  if (matchKey == null) return 0;
  final infoMap = muscles[matchKey];
  if (infoMap is! Map) return 0;
  final groeiNiveau = (infoMap['level'] as int?) ?? 0;
  final volumeNiveau = spiergroepToVolumeNiveau[matchKey] ?? 2;
  var ranking = groeiNiveauToBesteTrainingRanking[groeiNiveau] ?? 10;
  var spec = rankingToTrainingSpec[ranking] ?? const TrainingSpec(frequency: 0, volume: 0);
  while (ranking < 10) {
    final allowedVolumes = rankingToAllowedVolumeNiveaus[ranking];
    final volumeNiveauOk = allowedVolumes != null && allowedVolumes.contains(volumeNiveau);
    final freqTeHoog = spec.frequency > beschikbareFrequentie;
    if (volumeNiveauOk && !freqTeHoog) break;
    ranking++;
    spec = rankingToTrainingSpec[ranking] ?? spec;
  }
  return spec.frequency;
}

/// Bepaalt of er volgens de regels van stap 10 (sets toevoegen) één extra set aan een
/// subspier mag worden toegevoegd.
/// [daysUntilNext]: eerstvolgende keer getraind over X dagen (1, 2, 3, 4, 5 of 7).
/// [currentSets]: huidige aantal sets van die spier op deze dag (1, 2 of 3).
/// Alleen 2, 3, 4, 5 en 7 hebben regels; voor 1 of 6 retourneert dit false.
bool _stap10AddSetsCanAddOne(
  int daysUntilNext,
  int currentSets,
  int ranking,
  bool is2xPerWeek,
  int volumeNiveau,
) {
  // if (currentSets >= 3) return false;
  if (currentSets <= 0) return false;

  // print('daysUntilNext: $daysUntilNext, currentSets: $currentSets, ranking: $ranking, is2xPerWeek: $is2xPerWeek, volumeNiveau: $volumeNiveau');

  // Condities: "oorspronkelijke ranking van x OF HOGER" = ranking <= x (lagere waarde = betere prioriteit).
  switch (daysUntilNext) {
    case 2:
      if (currentSets == 1) {
        return ranking <= 4 && is2xPerWeek && (volumeNiveau == 2 || volumeNiveau == 3 || volumeNiveau == 4);
      }
      if (currentSets == 2) {
        return ranking <= 2 && is2xPerWeek && volumeNiveau == 4;
      }
      return false;
    /// Het lijkt hier alsof cases 3 en 4 niet geïmplementeerd zijn, maar zonder break statement gaan ze door naar case 5.
    case 3:
    case 4:
    case 5:
      if (currentSets == 1) {
        return ranking <= 4 && is2xPerWeek; // Volume 1,2,3,4
      }
      if (currentSets == 2) {
        return ranking <= 2 && is2xPerWeek && (volumeNiveau == 2 || volumeNiveau == 3 || volumeNiveau == 4);
      }
      if (currentSets == 3) {
        return ranking <= 1 && is2xPerWeek && volumeNiveau == 4;
      }
      return false;
    case 7:
      if (currentSets == 1) {
        return ranking <= 6; // Ranking 6 of hoger, Volume 1,2,3 of 4 (geen 2x/week vereist)
      }
      if (currentSets == 2) {
        return ranking <= 5 &&
            (volumeNiveau == 2 || volumeNiveau == 3 || volumeNiveau == 4);
      }
      if (currentSets == 3) {
        return ranking <= 3 &&
            (volumeNiveau == 3 || volumeNiveau == 4);
      }
      return false;
    default:
      return false;
  }
}

/// Berekent het aantal effectieve sets voor een dag volgens dezelfde toewijzingslogica als stap 10.
/// Zo blijft de telling in stap 9 gelijk aan het totaal dat stap 10 daadwerkelijk uitvoert.
int _stap10CountEffectiveSetsForDay(
  List<Stap8MuscleSetsEntry> dayMuscles,
  Map<String, List<String>> muscleToExercises,
  Map<String, List<String>> exerciseToTrainedMuscles,
  Map<String, dynamic> muscles,
) {
  final remaining = <String, int>{
    for (final e in dayMuscles) _normSpier(e.name): e.sets,
  };
  var total = 0;
  final hasSideDeltsEntry =
      dayMuscles.any((e) => _normSpier(e.name) == _normSpier('Side Delts'));
  final hasFrontDeltsEntry =
      dayMuscles.any((e) => _normSpier(e.name) == _normSpier('Front Delts'));

  for (final entry in dayMuscles) {
    final muscleName = entry.name;
    final key = _normSpier(muscleName);
    var sets = remaining[key] ?? 0;
    if (sets <= 0) continue;

    final exerciseNames = muscleToExercises[key];
    if (exerciseNames == null || exerciseNames.isEmpty) continue;

    // Speciale koppeling Side Delts ↔ Front Delts: Shoulder Press (SP) + Cable Lateral Raises (CR)
    // volgens vaste tabel op basis van sets Side Delts (SD) en sets Front Delts (FD).
    if (key == _normSpier('Side Delts')) {
      final sideKey = _normSpier('Side Delts');
      final frontKey = _normSpier('Front Delts');
      final setsSide = remaining[sideKey] ?? 0;
      final setsFront = remaining[frontKey] ?? 0;

      if (setsSide <= 0 && setsFront <= 0) continue;

      final (shoulderSets, cableLateralSets) =
          _shoulderPressAndCableLateralSets(setsSide, setsFront);
      if (shoulderSets > 0 && exerciseNames.isNotEmpty) {
        total += shoulderSets;
        _stap10DeductTrained(
          remaining,
          exerciseNames[0],
          shoulderSets,
          exerciseToTrainedMuscles,
        );
      }
      if (cableLateralSets > 0 && exerciseNames.length > 1) {
        total += cableLateralSets;
        _stap10DeductTrained(
          remaining,
          exerciseNames[1],
          cableLateralSets,
          exerciseToTrainedMuscles,
        );
      }

      // print('  [EffSets] Side/Front delts (norm="$key") add: $shoulderSets');
      // print('  [EffSets] $muscleName (norm="$key") add: $cableLateralSets');

      continue;
    }

    if (key == _normSpier('Front Delts')) {
      if (hasSideDeltsEntry) continue;

      final sideKey = _normSpier('Side Delts');
      final frontKey = _normSpier('Front Delts');
      final setsSide = remaining[sideKey] ?? 0;
      final setsFront = remaining[frontKey] ?? 0;
      if (setsSide <= 0 && setsFront <= 0) continue;

      final (shoulderSets, cableLateralSets) =
          _shoulderPressAndCableLateralSets(setsSide, setsFront);
      if (shoulderSets > 0 && exerciseNames.isNotEmpty) {
        total += shoulderSets;
        _stap10DeductTrained(
          remaining,
          exerciseNames[0],
          shoulderSets,
          exerciseToTrainedMuscles,
        );
      }
      // print('  [EffSets] $muscleName (norm="$key") add: $shoulderSets');
      continue;
    }

    // if (exerciseNames.length >= 2 &&
    //     (key == _normSpier('Biceps') || key == _normSpier('Triceps') || key == _normSpier('Lats'))) {
    //   final bias = _stap10GetBias(muscles, muscleName);
    //   final (setsFirst, setsSecond) = _stap10BiasSplit(sets, bias);
    //   if (setsFirst > 0) {
    //     total += setsFirst;
    //     _stap10DeductTrained(remaining, exerciseNames[0], setsFirst, exerciseToTrainedMuscles);
    //   }
    //   if (setsSecond > 0) {
    //     total += setsSecond;
    //     _stap10DeductTrained(remaining, exerciseNames[1], setsSecond, exerciseToTrainedMuscles);
    //   }
    //   continue;
    // }

    total += sets;
    // print('  [EffSets] $muscleName (norm="$key") add: $sets');
    _stap10DeductTrained(remaining, exerciseNames[0], sets, exerciseToTrainedMuscles);
  }
  return total;
}

/// Stap 10 — Kies oefeningen per (sub)spier; output per dag een lijst (oefeningnaam, sets).
///
/// Houdt rekening met overlap: een oefening die meerdere spieren traint (bv. Shoulder Press voor
/// Side + Front delts) wordt maar één keer toegevoegd; de sets worden afgetrokken van alle
/// getrainde spieren zodat ze niet dubbel tellen.
///
/// - Eén oefening per spier: Mid Chest, Upper Chest, Front Delts, Rear Delts, Mid Traps, Upper Traps,
///   Rectus Femoris, Vastus Muscles, Gluteus Maximus, Upper Glutes, Spinal Erectors, Abs, Hamstrings, Adductors,
///   plus Obliques, Forearms, Calves.
/// - Biceps, Triceps, Lats: bias uit survey (0,1,2). Hier is wat er mee gedaan moet worden:
/// Voor bias=0: 1 sets -> 0 sets eerste oefening, 1 set tweede oefening
/// Voor bias=0, 2 sets -> 0 set eerste oefening, 2 set tweede oefening
/// Voor bias=0: 3 sets -> 1 set eerste oefening, 2 sets tweede oefening
/// Voor bias=0: 4 sets -> 1 set eerste oefening, 3 sets tweede oefening
/// Voor bias=1: 1 sets -> 1 set eerste oefening
/// Voor bias=1, 2 sets -> 1 set eerste oefening, 1 set tweede oefening
/// Voor bias=1: 3 sets -> 1 set eerste oefening, 2 sets tweede oefening
/// Voor bias=1: 4 sets -> 2 sets eerste oefening, 2 sets tweede oefening
/// Voor bias=2: 1 sets -> 1 set eerste oefening
/// Voor bias=2, 2 sets -> 2 set eerste oefening, 1 set tweede oefening
/// Voor bias=2: 3 sets -> 2 set eerste oefening, 1 set tweede oefening
/// Voor bias=2: 4 sets -> 3 sets eerste oefening, 1 sets tweede oefening
// Side Delts & Front Delts, Shoulder Press & Cable Lateral Raises
// SD, FD, SP, CR
// 0,0 → 0 SP 0 CR
// 0,1 → 1 SP 0 CR
// 0,2 → 2 SP 0 CR
// 0,3 → 3 SP 0 CR
// 1,0 → 1 SP 0 CR
// 1,1 → 1 SP 0 CR
// 1,2 → 2 SP 0 CR
// 1,3 → 3 SP 0 CR
// 2,0 → 2 SP 0 CR
// 2,1 → 2 SP 0 CR
// 2,2 → 2 SP 0 CR
// 2,3 → 3 SP 0 CR
// 3,0 → 2 SP 1 CR
// 3,1 → 2 SP 1 CR
// 3,2 → 2 SP 1 CR
// 3,3 → 3 SP 1 CR
// 4,0 → 2 SP 2 CR
// 4,1 → 2 SP 2 CR
// 4,2 → 2 SP 2 CR
// 4,3 → 3 SP 2 CR

Future<Stap10Result> workouts_stap_11(
  Stap8Result stap8Result,
  Map<String, dynamic> muscles,
) async {
  debugPrint('\nWorkouts stap 11 – oefeningen toewijzen (met overlapcorrectie):');
  final data = await _loadStap10ExerciseData();
  final muscleToExercises = data.muscleToExercises;
  final exerciseToTrainedMuscles = data.exerciseToTrainedMuscles;
  final exerciseMeta = data.exerciseMeta;
  final perDayExercises = <List<Stap10ExerciseEntry>>[];

  for (var d = 0; d < stap8Result.perDayMuscleSets.length; d++) {
    final dayMuscles = stap8Result.perDayMuscleSets[d];
    final dayExercises = <Stap10ExerciseEntry>[];
    final remaining = <String, int>{
      for (final e in dayMuscles) _normSpier(e.name): e.sets,
    };
    final hasSideDeltsEntry =
        dayMuscles.any((e) => _normSpier(e.name) == _normSpier('Side Delts'));

    for (final entry in dayMuscles) {
      final muscleName = entry.name;
      final key = _normSpier(muscleName);
      var sets = remaining[key] ?? 0;
      if (sets <= 0) continue;

      final exerciseNames = muscleToExercises[key];
      if (exerciseNames == null || exerciseNames.isEmpty) continue;

      // Speciale koppeling Side Delts ↔ Front Delts: Shoulder Press (SP) + Cable Lateral Raises (CR)
      // volgens vaste tabel op basis van sets Side Delts (SD) en sets Front Delts (FD).
      if (key == _normSpier('Side Delts')) {
        final sideKey = _normSpier('Side Delts');
        final frontKey = _normSpier('Front Delts');
        final setsSide = remaining[sideKey] ?? 0;
        final setsFront = remaining[frontKey] ?? 0;

        if (setsSide <= 0 && setsFront <= 0) {
          debugPrint('  [Stap 11] Side/Front delts: geen remaining sets, overslaan.');
          continue;
        }

        final (shoulderSets, cableLateralSets) =
            _shoulderPressAndCableLateralSets(setsSide, setsFront);
        if (shoulderSets > 0 && exerciseNames.isNotEmpty) {
          final meta = exerciseMeta[exerciseNames[0]];
          dayExercises.add((
            name: exerciseNames[0],
            sets: shoulderSets,
            reps: meta?.reps ?? '5-7',
            restTime: meta?.restTime ?? '',
            rir: '',
            restSeconds: 0,
          ));
          _stap10DeductTrained(
            remaining,
            exerciseNames[0],
            shoulderSets,
            exerciseToTrainedMuscles,
          );
        }
        if (cableLateralSets > 0 && exerciseNames.length > 1) {
          final meta = exerciseMeta[exerciseNames[1]];
          dayExercises.add((
            name: exerciseNames[1],
            sets: cableLateralSets,
            reps: meta?.reps ?? '5-7',
            restTime: meta?.restTime ?? '',
            rir: '',
            restSeconds: 0,
          ));
          _stap10DeductTrained(
            remaining,
            exerciseNames[1],
            cableLateralSets,
            exerciseToTrainedMuscles,
          );
        }

        continue;
      }

      // Front Delts zonder Side‑Delts‑entry: Shoulder Press (en evt. CR) via dezelfde tabel.
      if (key == _normSpier('Front Delts')) {
        if (hasSideDeltsEntry) {
          debugPrint(
            '  [Stap 11] Front Delts: geen aparte oefening toegevoegd (volume via Shoulder Press bij Side Delts).',
          );
          continue;
        }

        final sideKey = _normSpier('Side Delts');
        final frontKey = _normSpier('Front Delts');
        final setsSide = remaining[sideKey] ?? 0;
        final setsFront = remaining[frontKey] ?? 0;
        if (setsSide <= 0 && setsFront <= 0) continue;

        final (shoulderSets, cableLateralSets) =
            _shoulderPressAndCableLateralSets(setsSide, setsFront);
        if (shoulderSets > 0 && exerciseNames.isNotEmpty) {
          final meta = exerciseMeta[exerciseNames[0]];
          dayExercises.add((
            name: exerciseNames[0],
            sets: shoulderSets,
            reps: meta?.reps ?? '5-7',
            restTime: meta?.restTime ?? '',
            rir: '',
            restSeconds: 0,
          ));
          _stap10DeductTrained(
            remaining,
            exerciseNames[0],
            shoulderSets,
            exerciseToTrainedMuscles,
          );
        }

        continue;
      }

      if (exerciseNames.length >= 2 &&
          (key == _normSpier('Biceps') || key == _normSpier('Triceps') || key == _normSpier('Lats'))) {
        final bias = _stap10GetBias(muscles, muscleName);
        final (setsFirst, setsSecond) = _stap10BiasSplit(sets, bias);
        if (setsFirst > 0) {
          final metaFirst = exerciseMeta[exerciseNames[0]];
          dayExercises.add((
            name: exerciseNames[0],
            sets: setsFirst,
            reps: metaFirst?.reps ?? '5-7',
            restTime: metaFirst?.restTime ?? '',
            rir: '',
            restSeconds: 0,
          ));
          _stap10DeductTrained(remaining, exerciseNames[0], setsFirst, exerciseToTrainedMuscles);
        }
        if (setsSecond > 0) {
          final metaSecond = exerciseMeta[exerciseNames[1]];
          dayExercises.add((
            name: exerciseNames[1],
            sets: setsSecond,
            reps: metaSecond?.reps ?? '5-7',
            restTime: metaSecond?.restTime ?? '',
            rir: '',
            restSeconds: 0,
          ));
          _stap10DeductTrained(remaining, exerciseNames[1], setsSecond, exerciseToTrainedMuscles);
        }
        continue;
      }

      final meta = exerciseMeta[exerciseNames[0]];
      dayExercises.add((
        name: exerciseNames[0],
        sets: sets,
        reps: meta?.reps ?? '5-7',
        restTime: meta?.restTime ?? '',
        rir: '',
        restSeconds: 0,
      ));
      _stap10DeductTrained(remaining, exerciseNames[0], sets, exerciseToTrainedMuscles);
    }

    perDayExercises.add(dayExercises);
    final parts = dayExercises.map((e) => '${e.name}: ${e.sets}').join(', ');
    debugPrint('  Dag ${d + 1}: $parts');
    debugPrint('  Totaal sets: ${dayExercises.fold<int>(0, (sum, e) => sum + e.sets)}');
  }

  return (perDayExercises: perDayExercises);
}
