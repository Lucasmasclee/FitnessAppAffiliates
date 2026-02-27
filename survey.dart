import 'package:flutter/material.dart';

import '../functionaliteit/alle_opties_ingevuld_met_routines.dart';
import '../functionaliteit/workout_generator.dart';
import '../functionaliteit/workout_storage.dart';
import 'subscription_paywall.dart';
import 'workout.dart';

enum SpiergroepIntensiteit {
  notAtAll,
  aLittleBit,
  normal,
  average,
  moderately,
  aLot,
  maximal,
}

extension SpiergroepIntensiteitExtension on SpiergroepIntensiteit {
  String get label {
    switch (this) {
      case SpiergroepIntensiteit.notAtAll:
        return 'Not at all';
      case SpiergroepIntensiteit.aLittleBit:
        return 'A little bit';
      case SpiergroepIntensiteit.normal:
        return 'Normal';
      case SpiergroepIntensiteit.average:
        return 'Average';
      case SpiergroepIntensiteit.moderately:
        return 'Moderately';
      case SpiergroepIntensiteit.aLot:
        return 'A lot';
      case SpiergroepIntensiteit.maximal:
        return 'Maximal';
    }
  }

  int get value {
    return index;
  }

  static SpiergroepIntensiteit fromValue(int value) {
    return SpiergroepIntensiteit.values[value.clamp(0, 6)];
  }
}

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> _dagen = [
    'Maandag',
    'Dinsdag',
    'Woensdag',
    'Donderdag',
    'Vrijdag',
    'Zaterdag',
    'Zondag',
  ];
  final Map<String, bool> _trainingsdagen = {};

  int _maxWorkoutMinuten = 60;

  final List<String> _spiergroepen = [
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
    'Quadriceps',
    'Glutes',
    'Hamstrings',
    'Adductors',
    'Calves',
  ];

  /// Spiergroepen met geavanceerde opties (subgroepen)
  final Map<String, List<String>> _subSpiergroepen = {
    'Chest': ['Mid chest', 'Upper chest'],
    'Shoulders': ['Side delts', 'Front delts'],
    'Glutes': ['Gluteus Maximus', 'Upper Glutes'],
    'Upper Back': ['Rear delts', 'Mid traps', 'Upper traps'],
    'Quadriceps': ['Vastus Muscles', 'Rectus Femoris'],
  };

  /// Houdt bij of de 'advanced options' voor een spiergroep opengeklapt zijn
  final Map<String, bool> _advancedOpen = {
    'Chest': false,
    'Shoulders': false,
    'Glutes': false,
    'Upper Back': false,
    'Quadriceps': false,
  };

  /// Bias-opties voor Triceps, Biceps, Lats (3 waarden: 0, 1, 2)
  final Map<String, List<String>> _biasOptions = {
    'Triceps': ['Lateral & Medial head', 'the same', 'long head'],
    'Biceps': ['biceps', 'the same', 'Brachialis & Brachioradialis'],
    'Lats': ['lower lats', 'the same', 'upper lats'],
  };
  final Map<String, bool> _biasOpen = {
    'Triceps': false,
    'Biceps': false,
    'Lats': false,
  };
  final Map<String, int> _biasValue = {
    'Triceps': 1,
    'Biceps': 1,
    'Lats': 1,
  };

  final Map<String, SpiergroepIntensiteit> _spiergroepIntensiteit = {};

  /// Volgorde van spiergroepen (14 groepen) - herbruikbaar voor drag in vraag 4
  late List<String> _spiergroepVolgorde;
  bool _userHasCustomSpiergroepVolgorde = false;

  /// De 14 spiergroepen voor vraag 4 (volgorde kiezen)
  static const List<String> _spiergroepenVoorVolgorde = [
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

  // /// Optioneel geselecteerde testinput uit vraag 5 (vraag 5 uitgezet).
  // Step6LookupEntry? _selectedTestCase;

  @override
  void initState() {
    super.initState();
    for (final dag in _dagen) {
      _trainingsdagen[dag] = false;
    }
    for (final spiergroep in _spiergroepen) {
      _spiergroepIntensiteit[spiergroep] = SpiergroepIntensiteit.maximal;
    }
    // Initialiseert ook alle subspiergroepen met een standaardwaarde
    for (final entry in _subSpiergroepen.entries) {
      for (final sub in entry.value) {
        _spiergroepIntensiteit[sub] = SpiergroepIntensiteit.maximal;
      }
    }
    _spiergroepVolgorde = List.from(_spiergroepenVoorVolgorde);
    _initialiseerSpiergroepVolgordeOpGroeiNiveau();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _voltooien() async {
    // Vraag 5 (testinput) is uitgezet; altijd handmatig ingevulde antwoorden gebruiken.
    // if (_selectedTestCase != null) {
    //   data = _buildSurveyResultFromLookupEntry(_selectedTestCase!);
    // } else {
    final Map<String, dynamic> data = _buildSurveyResult();
    // }
    final summary = await handleSurveyResult(data);

    if (!mounted) return;

    final valid = isValidWorkoutSplit(summary);

    // Na het afronden van de survey altijd door naar de paywall.
    // De paywall zorgt er daarna voor dat bij een geldig schema
    // het workoutschema wordt opgeslagen en geopend.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SubscriptionPaywallScreen(
          summary: summary,
          isValidSplit: valid,
        ),
      ),
    );
  }

  Map<String, dynamic> _buildSurveyResult() {
    final days = <String, bool>{};
    for (final dag in _dagen) {
      days[dag] = _trainingsdagen[dag] ?? false;
    }

    final muscles = <String, dynamic>{};
    final parentGroepenMetSubs = _subSpiergroepen.keys.toSet();
    _spiergroepIntensiteit.forEach((naam, intensiteit) {
      // Ouder-spiergroepen met subgroepen niet apart meesturen; alleen de subgroepen.
      if (parentGroepenMetSubs.contains(naam)) return;
      final entry = <String, dynamic>{
        'level': intensiteit.value,
        'label': intensiteit.label,
      };
      if (_biasOptions.containsKey(naam)) {
        final biasIdx = _biasValue[naam] ?? 1;
        entry['bias'] = biasIdx;
        entry['biasLabel'] = _biasOptions[naam]![biasIdx];
      }
      muscles[naam] = entry;
    });

    return {
      'days': days,
      'maxWorkoutMinutes': _maxWorkoutMinuten,
      'muscles': muscles,
      'muscleOrder': List<String>.from(_spiergroepVolgorde),
    };
  }

  Map<String, dynamic> _buildSurveyResultFromLookupEntry(
      Step6TestCase entry) {
    final days = <String, bool>{};
    for (final dag in _dagen) {
      days[dag] = entry.days.contains(dag);
    }

    return {
      'days': days,
      // Specifieke velden voor directe stap‑6 lookup in workout_generator.dart.
      'lookupGivenSets': entry.givenSets,
      'lookupGivenFreq': entry.givenFreq,
    };
  }

  /// Of de 'Volgende'-knop klikbaar is (vraag 1: minstens 1 dag geselecteerd).
  bool _isVolgendeEnabled() {
    if (_currentPage == 0) {
      return _trainingsdagen.values.any((v) => v == true);
    }
    return true;
  }

  void _volgende() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    } else {
      // Na vraag 4 (laatste vraag) direct voltooien; vraag 5 is uitgezet
      _voltooien();
    }
  }

  /// Bepaal groeiniveau (0–6) voor een item in de volgorde-lijst.
  /// Voor 'Quadriceps & Glutes' nemen we het hoogste niveau van beide.
  SpiergroepIntensiteit _groeiNiveauVoorVolgordeItem(String item) {
    if (item == 'Quadriceps & Glutes') {
      final quad = _spiergroepIntensiteit['Quadriceps'] ?? SpiergroepIntensiteit.normal;
      final glutes = _spiergroepIntensiteit['Glutes'] ?? SpiergroepIntensiteit.normal;
      return quad.value >= glutes.value ? quad : glutes;
    }
    return _spiergroepIntensiteit[item] ?? SpiergroepIntensiteit.normal;
  }

  /// Initialiseert de beginvolgorde van vraag 4 op basis van de
  /// groeilevels uit vraag 3 (hoogste groeilevel eerst).
  /// Spiergroepen met groeiniveau 0 worden niet getoond in vraag 4.
  void _initialiseerSpiergroepVolgordeOpGroeiNiveau() {
    final metGroei = _spiergroepenVoorVolgorde
        .where((item) => _groeiNiveauVoorVolgordeItem(item).value != 0)
        .toList();

    if (_userHasCustomSpiergroepVolgorde) {
      // Behoud volgorde, maar verwijder groepen met groeiniveau 0
      _spiergroepVolgorde =
          _spiergroepVolgorde.where((item) => _groeiNiveauVoorVolgordeItem(item).value != 0).toList();
      return;
    }

    final indexed = metGroei.asMap().entries.toList();
    indexed.sort((a, b) {
      final levelA = _groeiNiveauVoorVolgordeItem(a.value).value;
      final levelB = _groeiNiveauVoorVolgordeItem(b.value).value;

      // Eerst sorteren op groeiniveau (hoog naar laag)
      if (levelA != levelB) {
        return levelB.compareTo(levelA);
      }

      // Bij gelijke groeilevels blijft de originele volgorde behouden
      return a.key.compareTo(b.key);
    });

    _spiergroepVolgorde = indexed.map((e) => e.value).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      _userHasCustomSpiergroepVolgorde = true;
      if (newIndex > oldIndex) newIndex--;
      final item = _spiergroepVolgorde.removeAt(oldIndex);
      _spiergroepVolgorde.insert(newIndex, item);
    });
  }

  void _vorige() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Survey'),
        centerTitle: true,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _vorige,
              )
            : null,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildVraag1(),
                _buildVraag3(),
                _buildVraag4(),
                // _buildVraag5(), // Vraag 5 (testinput) uitgezet; alleen eerste 4 vragen tonen
              ],
            ),
          ),
          _buildNavigatieButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == _currentPage ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index <= _currentPage
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVraag1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'On which days can you train?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the days you can train.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          ..._dagen.map((dag) => _buildDagTile(dag)),
        ],
      ),
    );
  }

  Widget _buildDagTile(String dag) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(_displayDay(dag)),
        subtitle: Text(
          _trainingsdagen[dag]! ? 'Available' : 'Not available',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        value: _trainingsdagen[dag]!,
        onChanged: (value) {
          setState(() => _trainingsdagen[dag] = value);
        },
      ),
    );
  }

  Widget _buildVraag3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How much do you want to train each muscle group?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Move the slider for each muscle group to the desired intensity: from "Not at all" to "Maximal".',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          ..._spiergroepen.map((spiergroep) => _buildSpiergroepTile(spiergroep)),
        ],
      ),
    );
  }

  String _daysShortLabel(List<String> days) {
    const Map<String, String> dayToShort = {
      'Maandag': 'Mo',
      'Dinsdag': 'Tu',
      'Woensdag': 'We',
      'Donderdag': 'Th',
      'Vrijdag': 'Fr',
      'Zaterdag': 'Sa',
      'Zondag': 'Su',
    };
    return days.map((d) => dayToShort[d] ?? d).join(', ');
  }

  // ---------- Vraag 5 (testinput) uitgezet; alleen eerste 4 vragen worden getoond ----------
  // Widget _buildVraag5() {
  //   return SingleChildScrollView(
  //     padding: const EdgeInsets.all(24),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'Welke input wil je testen?',
  //           style: Theme.of(context).textTheme.headlineSmall?.copyWith(
  //                 fontWeight: FontWeight.bold,
  //               ),
  //         ),
  //         const SizedBox(height: 8),
  //         Text(
  //           'Kies een testinput om de workout-generator te testen.',
  //           style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  //                 color: Theme.of(context).colorScheme.onSurfaceVariant,
  //               ),
  //         ),
  //         const SizedBox(height: 24),
  //         ...(() {
  //           final all = step6LookupTable;
  //           final visible = all.length > 20 ? all.sublist(all.length - 20) : all;
  //           return visible;
  //         }()).map((testCase) {
  //           final isSelected = _selectedTestCase == testCase;
  //           return Padding(
  //             padding: const EdgeInsets.only(bottom: 8),
  //             child: SizedBox(
  //               width: double.infinity,
  //               child: FilledButton(
  //                 onPressed: () => _onTestInputSelected(testCase),
  //                 style: FilledButton.styleFrom(
  //                   backgroundColor: isSelected ? Colors.purple : Colors.white,
  //                   foregroundColor: isSelected ? Colors.white : Colors.black,
  //                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  //                   alignment: Alignment.centerLeft,
  //                 ),
  //                 child: Text(
  //                   '${_daysShortLabel(testCase.days)} • ${testCase.givenSets} • ${testCase.givenFreq}',
  //                   style: Theme.of(context).textTheme.bodyLarge,
  //                 ),
  //               ),
  //             ),
  //           );
  //         }),
  //       ],
  //     ),
  //   );
  // }
  //
  // void _onTestInputSelected(Step6LookupEntry testCase) {
  //   setState(() {
  //     _selectedTestCase = testCase;
  //   });
  // }

  Widget _buildVraag4() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose muscle group order',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Drag the muscle groups to adjust the order.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ReorderableListView.builder(
              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                return Material(
                  color: Colors.transparent,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  child: child,
                );
              },
              itemCount: _spiergroepVolgorde.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final spiergroep = _spiergroepVolgorde[index];
                return Card(
                  key: ValueKey(spiergroep),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(spiergroep),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpiergroepTile(String spiergroep) {
    final intensiteit = _spiergroepIntensiteit[spiergroep]!;
    final value = intensiteit.value.toDouble();
    final hasSubgroepen = _subSpiergroepen.containsKey(spiergroep);
    final hasBias = _biasOptions.containsKey(spiergroep);
    final hasAdvanced = hasSubgroepen || hasBias;
    final isSubgroepenOpen = _advancedOpen[spiergroep] ?? false;
    final isBiasOpen = _biasOpen[spiergroep] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    spiergroep,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    intensiteit.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            if (!hasSubgroepen || !isSubgroepenOpen) ...[
              const SizedBox(height: 2),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor:
                      Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: Slider(
                  value: value,
                  min: 0,
                  max: 6,
                  divisions: 6,
                  label: intensiteit.label,
                  onChanged: (newValue) {
                    setState(() {
                      final nieuweIntensiteit =
                          SpiergroepIntensiteitExtension.fromValue(
                              newValue.round());
                      _spiergroepIntensiteit[spiergroep] = nieuweIntensiteit;

                      // Als advanced opties dicht zijn, gebruiken subspiergroepen
                      // automatisch dezelfde waarde als de hoofdspiergroep.
                      if (hasSubgroepen && !isSubgroepenOpen) {
                        for (final sub in _subSpiergroepen[spiergroep]!) {
                          _spiergroepIntensiteit[sub] = nieuweIntensiteit;
                        }
                      }

                      // Elke keer dat groeilevels in vraag 3 veranderen,
                      // wordt de volgorde in vraag 4 opnieuw gesorteerd.
                      _initialiseerSpiergroepVolgordeOpGroeiNiveau();
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      SpiergroepIntensiteit.notAtAll.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      SpiergroepIntensiteit.maximal.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
            if (hasSubgroepen && isSubgroepenOpen) ...[
              // const SizedBox(height: 2),
              const Divider(),
              // const SizedBox(height: 2),
              ..._subSpiergroepen[spiergroep]!.map(
                (sub) => Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: _buildSubSpierTile(sub),
                ),
              ),
            ],
            if (hasBias && isBiasOpen) ...[
              // const SizedBox(height: 2),
              const Divider(),
              // const SizedBox(height: 2),
              _buildBiasSlider(spiergroep),
            ],
            if (hasAdvanced)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        if (hasSubgroepen) {
                          _advancedOpen[spiergroep] = !isSubgroepenOpen;
                        } else {
                          _biasOpen[spiergroep] = !isBiasOpen;
                        }
                      });
                    },
                    child: Text(
                      'advanced options',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Bias-slider voor Triceps, Biceps, Lats (3 waarden).
  Widget _buildBiasSlider(String spiergroep) {
    final labels = _biasOptions[spiergroep]!;
    final value = (_biasValue[spiergroep] ?? 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'bias',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 2,
            divisions: 2,
            label: labels[value.round()],
            onChanged: (newValue) {
              setState(() {
                _biasValue[spiergroep] = newValue.round();
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                labels[0],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                labels[2],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Zelfde slider-UI voor subspiergroepen binnen een uitgeklapte spiergroep.
  Widget _buildSubSpierTile(String naam) {
    final intensiteit = _spiergroepIntensiteit[naam]!;
    final value = intensiteit.value.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          naam,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 6,
            divisions: 6,
            label: intensiteit.label,
            onChanged: (newValue) {
              setState(() {
                _spiergroepIntensiteit[naam] =
                    SpiergroepIntensiteitExtension.fromValue(
                        newValue.round());

                // Ook veranderingen in subspier-groeilevels moeten
                // direct de volgorde van vraag 4 bijwerken.
                _initialiseerSpiergroepVolgordeOpGroeiNiveau();
              });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              SpiergroepIntensiteit.notAtAll.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              SpiergroepIntensiteit.maximal.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigatieButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            if (_currentPage > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _vorige,
                  child: const Text('Previous'),
                ),
              ),
            if (_currentPage > 0) const SizedBox(width: 16),
            Expanded(
              flex: _currentPage > 0 ? 1 : 2,
                child: FilledButton(
                onPressed: _isVolgendeEnabled() ? _volgende : null,
                child: Text(_currentPage < 2 ? 'Next' : 'Finish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayDay(String dag) {
    switch (dag) {
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
        return dag;
    }
  }
}
