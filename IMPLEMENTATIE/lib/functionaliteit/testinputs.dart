/// LET OP: DIT BESTAND WORDT ALLEEN GEBRUIKT VOOR ALLE MOGELIJKE INPUTS VOOR DE WORKOUT-GENERATOR.


/// Test-inputs voor de workout-generator.
///
/// Elk testgeval bevat alle data die ook in de survey kan worden ingesteld:
/// - welke dagen beschikbaar zijn
/// - groeiniveau (0-6) per subspier (21 stuks)
/// - bias (0, 1, 2) voor Biceps, Triceps, Lats
/// - spiervolgorde (14 groepen)
/// - maxWorkoutMinutes
///
/// Het formaat is compatibel met [handleSurveyResult] in workout_generator.dart.

// Tabel voor groeiniveau naar startranking:
// 0 → 0
// 1 → 9
// 2 → 6
// 3 → 5
// 4 → 3
// 5 → 2
// 6 → 1

// Tabel voor startranking naar frequentie en sets:
// 1 → 3 → 3
// 2 → 3 → 2
// 3 → 2 → 3
// 4 → 3 → 1
// 5 → 2 → 2
// 6 → 2 → 1
// 7 → 1 → 3
// 8 → 1 → 2
// 9 → 1 → 1
// 10 → 0 → 0


/// Alle 21 subspieren (zoals in de survey, geen ouder-groepen).
const List<String> allSubspieren = [
  'Biceps',
  'Triceps',
  'Lats',
  'Mid chest',
  'Upper chest',
  'Side delts',
  'Front delts',
  'Gluteus Maximus',
  'Upper Glutes',
  'Rear delts',
  'Mid traps',
  'Upper traps',
  'Vastus Muscles',
  'Rectus Femoris',
  'Spinal Erectors',
  'Abs',
  'Obliques',
  'Forearms',
  'Hamstrings',
  'Adductors',
  'Calves',
];

/// Spieren met bias-optie (0, 1 of 2).
const List<String> biasSpieren = ['Triceps', 'Biceps', 'Lats'];

/// Bias-labels per spier (index 0, 1, 2).
const Map<String, List<String>> biasLabels = {
  'Triceps': ['Lateral & Medial head', 'the same', 'long head'],
  'Biceps': ['biceps', 'the same', 'Brachialis & Brachioradialis'],
  'Lats': ['lower lats', 'the same', 'upper lats'],
};

/// Labels voor groeiniveau 0-6.
const List<String> levelLabels = [
  'Not at all',
  'A little bit',
  'Normal',
  'Average',
  'Moderately',
  'A lot',
  'Maximal',
];

/// Standaard spiervolgorde (14 groepen).
const List<String> defaultMuscleOrder = [
  'Biceps',
  'Triceps',
  'Chest',
  'Shoulders',
  'Lats',
  'Upper Back',
  'Spinal Erectors',
  'Abs',
  'Obliques',
  'Forearms',
  'Quadriceps & Glutes',
  'Hamstrings',
  'Adductors',
  'Calves',
];

class Step6TestCase {
  /// Beschikbare trainingsdagen (bijv. ['Maandag', 'Woensdag']).
  final List<String> days;

  /// Groeiniveau (0-6) per subspier. Ontbrekende keys = default 3 (Normal).
  final Map<String, int> muscleLevels;

  /// Bias (0, 1, 2) voor Biceps, Triceps, Lats. Ontbrekende keys = default 1.
  final Map<String, int> muscleBias;

  /// Spiervolgorde (14 groepen). Ontbreekt = [defaultMuscleOrder].
  final List<String> muscleOrder;

  /// Maximale workout-duur in minuten.
  final int maxWorkoutMinutes;

  /// Gegeven sets range (bijv. "1-25", "26-42").
  final String givenSets;

  /// Gegeven frequentie (bijv. "1", "2", "3").
  final String givenFreq;

  /// Verwachte pattern (bijv. 'A', 'BC') – voor testverificatie.
  final String expectedPattern;

  /// Verwachte volgorde van dagen – voor testverificatie.
  final List<String> expectedPatternDays;

  const Step6TestCase({
    required this.days,
    required this.muscleLevels,
    this.muscleBias = const {},
    this.muscleOrder = defaultMuscleOrder,
    this.givenSets = "0",
    this.givenFreq = "0",
    this.maxWorkoutMinutes = 60,
    this.expectedPattern = '',
    this.expectedPatternDays = const [],
  });

  /// Korte weergave van dagen (Ma, Di, Woe, Do, Vr, Za, Zo).
  String get daysShortLabel =>
      days.map((d) => _dayToShort[d] ?? d).join(', ');

  static const Map<String, String> _dayToShort = {
    'Maandag': 'Ma',
    'Dinsdag': 'Di',
    'Woensdag': 'Woe',
    'Donderdag': 'Do',
    'Vrijdag': 'Vr',
    'Zaterdag': 'Za',
    'Zondag': 'Zo',
  };

  /// Bouwt de volledige survey-data voor [handleSurveyResult].
  Map<String, dynamic> toSurveyData() {
    final daysMap = <String, bool>{};
    for (final d in _allDays) {
      daysMap[d] = days.contains(d);
    }

    final muscles = <String, dynamic>{};
    for (final naam in allSubspieren) {
      final level = (muscleLevels[naam] ?? 3).clamp(0, 6);
      final entry = <String, dynamic>{
        'level': level,
        'label': levelLabels[level],
      };
      if (biasSpieren.contains(naam)) {
        final biasIdx = (muscleBias[naam] ?? 1).clamp(0, 2);
        entry['bias'] = biasIdx;
        entry['biasLabel'] = biasLabels[naam]![biasIdx];
      }
      muscles[naam] = entry;
    }

    return {
      'days': daysMap,
      'maxWorkoutMinutes': maxWorkoutMinutes,
      'muscles': muscles,
      'muscleOrder': List<String>.from(muscleOrder),
    };
  }
}

const List<String> _allDays = [
  'Maandag',
  'Dinsdag',
  'Woensdag',
  'Donderdag',
  'Vrijdag',
  'Zaterdag',
  'Zondag',
];

/// Alle testcases – vul muscleLevels en eventueel muscleBias per geval in.
const List<Step6TestCase> step6TestCases = [
  // 1 beschikbare dag
  Step6TestCase(
    days: ['Maandag'],
    muscleLevels: _muscleLevelsSets1to42Freq1,
    givenSets: "1-42",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  // 2 beschikbare dagen
  Step6TestCase(
    days: ['Maandag', 'Dinsdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag'],
    muscleLevels: _muscleLevelsSets26to42Freq1,
    givenSets: "26-42",
    givenFreq: "1",
    expectedPattern: 'BC',
    expectedPatternDays: ['Maandag', 'Dinsdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Donderdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Donderdag'],
    muscleLevels: _muscleLevelsSets1to126Freq2,
    givenSets: "1-126",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Donderdag'],
  ),
  // 3 beschikbare dagen
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Woensdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag'],
    muscleLevels: _muscleLevelsSets51to84Freq2,
    givenSets: "51-84",
    givenFreq: "2",
    expectedPattern: 'BCB',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets26to42Freq1,
    givenSets: "26-42",
    givenFreq: "1",
    expectedPattern: 'BC',
    expectedPatternDays: ['Maandag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets51to84Freq2,
    givenSets: "51-84",
    givenFreq: "2",
    expectedPattern: 'BCA',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Woensdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Woensdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Woensdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Woensdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets51to84Freq2,
    givenSets: "51-84",
    givenFreq: "2",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Woensdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to126Freq3,
    givenSets: "1-126",
    givenFreq: "3",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  // 4 beschikbare dagen
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Donderdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag'],
    muscleLevels: _muscleLevelsSets51to84Freq2,
    givenSets: "51-84",
    givenFreq: "2",
    expectedPattern: 'BCBC',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets51to75Freq2,
    givenSets: "51-75",
    givenFreq: "2",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets75to84Freq2,
    givenSets: "76-84",
    givenFreq: "2",
    expectedPattern: 'BCBC',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to75Freq3,
    givenSets: "1-75",
    givenFreq: "3",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets76to126Freq3,
    givenSets: "76-126",
    givenFreq: "3",
    expectedPattern: 'BCBB',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Donderdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Donderdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Donderdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Donderdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets51to84Freq2,
    givenSets: "51-84",
    givenFreq: "2",
    expectedPattern: 'BCBC',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Donderdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Donderdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets51to75Freq2,
    givenSets: "51-75",
    givenFreq: "2",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Donderdag', 'Zaterdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets75to84Freq2,
    givenSets: "76-84",
    givenFreq: "2",
    expectedPattern: 'BCAA',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Donderdag', 'Zaterdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to75Freq3,
    givenSets: "1-75",
    givenFreq: "3",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Donderdag', 'Zaterdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets76to126Freq3,
    givenSets: "76-126",
    givenFreq: "3",
    expectedPattern: 'BCAA',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Donderdag', 'Zaterdag'],
  ),
  // 5 beschikbare dagen
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Donderdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets51to75Freq2,
    givenSets: "51-75",
    givenFreq: "2",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets75to84Freq2,
    givenSets: "76-84",
    givenFreq: "2",
    expectedPattern: 'BCBCB',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets1to75Freq3,
    givenSets: "1-75",
    givenFreq: "3",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag'],
    muscleLevels: _muscleLevelsSets76to126Freq2,
    givenSets: "76-126",
    givenFreq: "2",
    expectedPattern: 'BCBCB',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Donderdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets51to75Freq2,
    givenSets: "51-75",
    givenFreq: "2",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Zaterdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets75to84Freq2,
    givenSets: "76-84",
    givenFreq: "2",
    expectedPattern: 'BCBCA',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Zaterdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to75Freq3,
    givenSets: "1-75",
    givenFreq: "3",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Zaterdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets76to126Freq3,
    givenSets: "76-126",
    givenFreq: "3",
    expectedPattern: 'BCBCA',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Zaterdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets51to75Freq2,
    givenSets: "51-75",
    givenFreq: "2",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets75to84Freq2,
    givenSets: "76-84",
    givenFreq: "2",
    expectedPattern: 'BCBCB',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag', 'Zaterdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to75Freq3,
    givenSets: "1-75",
    givenFreq: "3",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets76to126Freq3,
    givenSets: "76-126",
    givenFreq: "3",
    expectedPattern: 'BCBCB',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Vrijdag', 'Zaterdag'],
  ),
  // 6 beschikbare dagen
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Donderdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets51to75Freq2,
    givenSets: "51-75",
    givenFreq: "2",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets75to84Freq2,
    givenSets: "76-84",
    givenFreq: "2",
    expectedPattern: 'BCBCBC',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets1to75Freq3,
    givenSets: "1-75",
    givenFreq: "3",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag'],
    muscleLevels: _muscleLevelsSets76to126Freq3,
    givenSets: "76-126",
    givenFreq: "3",
    expectedPattern: 'BCBCBC',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag'],
  ),
  // 7 beschikbare dagen
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag', 'Zondag'],
    muscleLevels: _muscleLevelsSets1to25Freq1,
    givenSets: "1-25",
    givenFreq: "1",
    expectedPattern: 'A',
    expectedPatternDays: ['Maandag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag', 'Zondag'],
    muscleLevels: _muscleLevelsSets1to50Freq2,
    givenSets: "1-50",
    givenFreq: "2",
    expectedPattern: 'AA',
    expectedPatternDays: ['Maandag', 'Donderdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag', 'Zondag'],
    muscleLevels: _muscleLevelsSets51to75Freq2,
    givenSets: "51-75",
    givenFreq: "2",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag', 'Zondag'],
    muscleLevels: _muscleLevelsSets75to84Freq2,
    givenSets: "76-84",
    givenFreq: "2",
    expectedPattern: 'BCBCBC',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag', 'Zondag'],
    muscleLevels: _muscleLevelsSets1to75Freq3,
    givenSets: "1-75",
    givenFreq: "3",
    expectedPattern: 'AAA',
    expectedPatternDays: ['Maandag', 'Woensdag', 'Vrijdag'],
  ),
  Step6TestCase(
    days: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag', 'Zondag'],
    muscleLevels: _muscleLevelsSets76to126Freq3,
    givenSets: "76-126",
    givenFreq: "3",
    expectedPattern: 'BCBCBC',
    expectedPatternDays: ['Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag', 'Zondag'],
  ),
];





































// Alle mogelijke combinaties van sets en MinFrequenties:
// Falls under means if X is in 1-25, then X is also in 1-42, 1-126, 1-50.
// 1-25 , MinFreq = 1
// 1-42 , MinFreq = 1
// 1-42 , MinFreq = 2
// 1-42 , MinFreq = 3
// 26-42 , MinFreq = 1 **********Falls under 1-42 MinFreq = 1**********
// 1-126 , MinFreq = 2 **********Falls under 1-42 MinFreq = 2**********
// 1-126 , MinFreq = 3 **********Falls under 1-42 MinFreq = 3**********
// 1-50 , MinFreq = 2
// 1-50 , MinFreq = 3
// 51-126 , MinFreq = 3
// 51-75 , MinFreq = 2
// 75-84 , MinFreq = 2
// 51-84 , MinFreq = 2 **********Falls under 51-75 MinFreq = 2**********
// 76-126 , MinFreq = 2
// 76-126 , MinFreq = 3 **********Falls under 51-126 MinFreq = 3**********
// 1-75 , MinFreq = 3 **********Falls under 1-42 MinFreq = 3**********

// 1-25 sets/week, MinFreq = 1. SETS=~17 MINFREQ=1
// Everything 1 means everything freq1 sets1. 4 overlapping sets makes 21-4 = 17 sets per week.
const _muscleLevelsSets1to25Freq1 = {
  'Biceps': 1,
  'Triceps': 1,
  'Lats': 1,
  'Mid chest': 1,
  'Upper chest': 1,
  'Side delts': 1,
  'Front delts': 1,
  'Gluteus Maximus': 1,
  'Upper Glutes': 1,
  'Rear delts': 1,
  'Mid traps': 1,
  'Upper traps': 1,
  'Vastus Muscles': 1,
  'Rectus Femoris': 1,
  'Spinal Erectors': 1,
  'Abs': 1,
  'Obliques': 1,
  'Forearms': 1,
  'Hamstrings': 1,
  'Adductors': 1,
  'Calves': 1,
};

// 1-42 sets/week, MinFreq = 1; SETS=~17 MINFREQ=1
// Falls under _muscleLevelsSets1to42Freq1
const _muscleLevelsSets1to42Freq1 = {
  'Biceps': 1,
  'Triceps': 1,
  'Lats': 1,
  'Mid chest': 1,
  'Upper chest': 1,
  'Side delts': 1,
  'Front delts': 1,
  'Gluteus Maximus': 1,
  'Upper Glutes': 1,
  'Rear delts': 1,
  'Mid traps': 1,
  'Upper traps': 1,
  'Vastus Muscles': 1,
  'Rectus Femoris': 1,
  'Spinal Erectors': 1,
  'Abs': 1,
  'Obliques': 1,
  'Forearms': 1,
  'Hamstrings': 1,
  'Adductors': 1,
  'Calves': 1,
};

// 1-42 sets/week, MinFreq = 2; SETS=~20 MINFREQ=2
// Everything 1 means everything freq1 sets1. 4 overlapping sets makes 21-4 = 17 sets per week. Biceps 3 means freq2 sets2 so 3 extra sets compared to everything freq1 sets1
const _muscleLevelsSets1to42Freq2 = {
  'Biceps': 3,
  'Triceps': 1,
  'Lats': 1,
  'Mid chest': 1,
  'Upper chest': 1,
  'Side delts': 1,
  'Front delts': 1,
  'Gluteus Maximus': 1,
  'Upper Glutes': 1,
  'Rear delts': 1,
  'Mid traps': 1,
  'Upper traps': 1,
  'Vastus Muscles': 1,
  'Rectus Femoris': 1,
  'Spinal Erectors': 1,
  'Abs': 1,
  'Obliques': 1,
  'Forearms': 1,
  'Hamstrings': 1,
  'Adductors': 1,
  'Calves': 1,
};

// 1-42 sets/week, MinFreq = 3; SETS=~25 MINFREQ=3
// Everything 1 means everything freq1 sets1. 4 overlapping sets makes 21-4 = 17 sets per week. Biceps 6 means freq3 sets3 so 8 extra sets compared to everything freq1 sets1.
const _muscleLevelsSets1to42Freq3 = {
  'Biceps': 6,
  'Triceps': 1,
  'Lats': 1,
  'Mid chest': 1,
  'Upper chest': 1,
  'Side delts': 1,
  'Front delts': 1,
  'Gluteus Maximus': 1,
  'Upper Glutes': 1,
  'Rear delts': 1,
  'Mid traps': 1,
  'Upper traps': 1,
  'Vastus Muscles': 1,
  'Rectus Femoris': 1,
  'Spinal Erectors': 1,
  'Abs': 1,
  'Obliques': 1,
  'Forearms': 1,
  'Hamstrings': 1,
  'Adductors': 1,
  'Calves': 1,
};

const _muscleLevelsSets26to42Freq1 = {
  'Biceps': 6,
  'Triceps': 6,
  'Lats': 6,
  'Mid chest': 6,
  'Upper chest': 6,
  'Side delts': 6,
  'Front delts': 6,
  'Gluteus Maximus': 6,
  'Upper Glutes': 6,
  'Rear delts': 6,
  'Mid traps': 6,
  'Upper traps': 6,
  'Vastus Muscles': 1,
  'Rectus Femoris': 6,
  'Spinal Erectors': 6,
  'Abs': 6,
  'Obliques': 6,
  'Forearms': 6,
  'Hamstrings': 6,
  'Adductors': 6,
  'Calves': 6,
};

// Falls under _muscleLevelsSets1to42Freq2
const _muscleLevelsSets1to126Freq2 = _muscleLevelsSets1to42Freq2;

// Falls under _muscleLevelsSets1to42Freq3
const _muscleLevelsSets1to126Freq3 = _muscleLevelsSets1to42Freq3;

// 1-50 , MinFreq = 2; SETS=~20 MINFREQ=2
// Everything 1 means everything freq1 sets1. 4 overlapping sets makes 21-4 = 17 sets per week. Biceps 3 means freq2 sets2 so 3 extra sets compared to everything freq1 sets1.
const _muscleLevelsSets1to50Freq2 = {
  'Biceps': 2,
  'Triceps': 1,
  'Lats': 1,
  'Mid chest': 1,
  'Upper chest': 1,
  'Side delts': 1,
  'Front delts': 1,
  'Gluteus Maximus': 1,
  'Upper Glutes': 1,
  'Rear delts': 1,
  'Mid traps': 1,
  'Upper traps': 1,
  'Vastus Muscles': 1,
  'Rectus Femoris': 1,
  'Spinal Erectors': 1,
  'Abs': 1,
  'Obliques': 1,
  'Forearms': 1,
  'Hamstrings': 1,
  'Adductors': 1,
  'Calves': 1,
};

// 1-50 , MinFreq = 3; SETS=~25 MINFREQ=3
// Everything 1 means everything freq1 sets1. 4 overlapping sets makes 21-4 = 17 sets per week. Biceps 3 means freq3 sets3 so 8 extra sets compared to everything freq1 sets1.
const _muscleLevelsSets1to50Freq3 = {
  'Biceps': 6,
  'Triceps': 1,
  'Lats': 1,
  'Mid chest': 1,
  'Upper chest': 1,
  'Side delts': 1,
  'Front delts': 1,
  'Gluteus Maximus': 1,
  'Upper Glutes': 1,
  'Rear delts': 1,
  'Mid traps': 1,
  'Upper traps': 1,
  'Vastus Muscles': 1,
  'Rectus Femoris': 1,
  'Spinal Erectors': 1,
  'Abs': 1,
  'Obliques': 1,
  'Forearms': 1,
  'Hamstrings': 1,
  'Adductors': 1,
  'Calves': 1,
};

// 51-126 , MinFreq = 3; 
// Everything 6 means everything freq3 sets3. Maximum sets is 126 sets. 
const _muscleLevelsSets51to126Freq3 = {
  'Biceps': 6,
  'Triceps': 6,
  'Lats': 6,
  'Mid chest': 6,
  'Upper chest': 6,
  'Side delts': 6,
  'Front delts': 6,
  'Gluteus Maximus': 6,
  'Upper Glutes': 6,
  'Rear delts': 6,
  'Mid traps': 6,
  'Upper traps': 6,
  'Vastus Muscles': 6,
  'Rectus Femoris': 6,
  'Spinal Erectors': 6,
  'Abs': 6,
  'Obliques': 6,
  'Forearms': 6,
  'Hamstrings': 6,
  'Adductors': 6,
  'Calves': 6,
};

// 51-75 , MinFreq = 2
// 3 muscle groups get freq2 sets3 = 3*6 = 18 sets. 8 muscle groups get freq2 sets2 = 32 sets. the rest get freq1 sets1 = 3*1 = 3 sets. In total 53 sets.
const _muscleLevelsSets51to75Freq2 = {
  'Biceps': 4,
  'Triceps': 4,
  'Lats': 4,
  'Mid chest': 3,
  'Upper chest': 3,
  'Side delts': 1,
  'Front delts': 1,
  'Gluteus Maximus': 1,
  'Upper Glutes': 1,
  'Rear delts': 1,
  'Mid traps': 1,
  'Upper traps': 1,
  'Vastus Muscles': 1,
  'Rectus Femoris': 1,
  'Spinal Erectors': 1,
  'Abs': 3,
  'Obliques': 3,
  'Forearms': 3,
  'Hamstrings': 3,
  'Adductors': 3,
  'Calves': 3,
};

// 75-84 , MinFreq = 2
// Totaal 80 sets. Biceps & Triceps get freq2 sets3 = 4*6 = 24 sets. 
const _muscleLevelsSets75to84Freq2 = {
  'Biceps': 4,
  'Triceps': 4,
  'Lats': 4,
  'Mid chest': 4,
  'Upper chest': 3,
  'Side delts': 3,
  'Front delts': 3,
  'Gluteus Maximus': 3,
  'Upper Glutes': 3,
  'Rear delts': 3,
  'Mid traps': 3,
  'Upper traps': 3,
  'Vastus Muscles': 3,
  'Rectus Femoris': 3,
  'Spinal Erectors': 3,
  'Abs': 3,
  'Obliques': 3,
  'Forearms': 3,
  'Hamstrings': 3,
  'Adductors': 3,
  'Calves': 3,
};

// Falls under _muscleLevelsSets51to75Freq2
const _muscleLevelsSets51to84Freq2 = _muscleLevelsSets51to75Freq2;

// Totaal 80 sets. 
const _muscleLevelsSets76to126Freq2 = {
  'Biceps': 4,
  'Triceps': 4,
  'Lats': 4,
  'Mid chest': 4,
  'Upper chest': 3,
  'Side delts': 3,
  'Front delts': 3,
  'Gluteus Maximus': 3,
  'Upper Glutes': 3,
  'Rear delts': 3,
  'Mid traps': 3,
  'Upper traps': 3,
  'Vastus Muscles': 3,
  'Rectus Femoris': 3,
  'Spinal Erectors': 3,
  'Abs': 3,
  'Obliques': 3,
  'Forearms': 3,
  'Hamstrings': 3,
  'Adductors': 3,
  'Calves': 3,
};

// Falls under _muscleLevelsSets51to126Freq3
const _muscleLevelsSets76to126Freq3 = _muscleLevelsSets51to126Freq3;

// Falls under _muscleLevelsSets1to42Freq3
const _muscleLevelsSets1to75Freq3 = _muscleLevelsSets1to42Freq3;


// Tabel voor groeiniveau naar startranking:
// 0 → 0
// 1 → 9
// 2 → 6
// 3 → 5
// 4 → 3
// 5 → 2
// 6 → 1

// Tabel voor startranking naar frequentie en sets:
// 1 → 3 → 3
// 2 → 3 → 2
// 3 → 2 → 3
// 4 → 3 → 1
// 5 → 2 → 2
// 6 → 2 → 1
// 7 → 1 → 3
// 8 → 1 → 2
// 9 → 1 → 1
// 10 → 0 → 0






/// Spieren met hun volumeniveaus (1–3). Bepaalt welke rankings “Wel” mogen voor die spier; zie rankingToAllowedVolumeNiveaus.
// Biceps 		(3)
// Triceps 		(3)
// Mid chest 		(3)
// Upper chest 		(1)
// Front delts		(2)
// Side delts		(3)
// Lats			(3)
// Mid traps		(3)
// Upper traps		(2)
// Rear delts		(3)
// Spinal Erectors	(2)
// Abs			(2)
// Obliques		(2)
// Forearms		(2)
// Rectus Femoris	(2)
// Vastus Muscles	(3)
// Gluteus Maximus	(3)
// Upper glutes		(2)
// Hamstrings		(2)
// Adductors		(2)
// Calves		(2)