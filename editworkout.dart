import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../functionaliteit/workout_generator.dart';
import '../functionaliteit/workout_storage.dart';
import 'weekplanning.dart';

const List<String> _editWorkoutWeekdays = [
  'Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag', 'Zondag',
];

/// Scherm om workouts te bewerken: workouts/oefeningen toevoegen/verwijderen,
/// volgorde aanpassen (ReorderableListView), sets/reps/rir/rust per oefening,
/// en oefeningen wisselen voor alternatieven (zelfde spiergroep).
class EditWorkoutScreen extends StatefulWidget {
  final SurveyResultSummary summary;
  final int? initialWorkoutIndex;

  const EditWorkoutScreen({
    super.key,
    required this.summary,
    this.initialWorkoutIndex,
  });

  @override
  State<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends State<EditWorkoutScreen> {
  late String _pattern;
  late List<String> _days;
  /// Per workout: lijst van geselecteerde dagen (meerdere dagen mogelijk).
  late List<List<String>> _scheduledDaysPerWorkout;
  late List<List<Stap10ExerciseEntry>> _exercisesPerDay;

  List<String> _allExerciseNames = [];
  Map<String, ({String reps, String restTime})> _exerciseMeta = {};
  Map<String, List<String>> _alternativesPerExercise = {};

  late int _selectedWorkoutIndex;
  bool _hasUnsavedChanges = false;
  bool _allowDirectPop = false;

  void _goToWeekplanning() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WeekplanningScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeInOut));
          final offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
      (route) => route.isFirst,
    );
  }

  @override
  void initState() {
    super.initState();
    final p = widget.summary.step6ResultPattern ?? '';
    final d = widget.summary.step6ResultDays ?? [];
    final e = widget.summary.step10PerDayExercises ?? [];
    final scheduled = widget.summary.scheduledDaysPerWorkout;
    _pattern = p;
    _days = List.from(d);
    if (scheduled != null && scheduled.length >= d.length) {
      _scheduledDaysPerWorkout = scheduled.map((list) => List<String>.from(list)).toList();
    } else {
      _scheduledDaysPerWorkout = d.map((day) => <String>[day]).toList();
    }
    while (_scheduledDaysPerWorkout.length < _days.length) {
      _scheduledDaysPerWorkout.add([]);
    }
    _exercisesPerDay = e.map((day) => day.toList()).toList();

    final initialIndex = widget.initialWorkoutIndex;
    if (initialIndex != null &&
        initialIndex >= 0 &&
        initialIndex < _exercisesPerDay.length) {
      _selectedWorkoutIndex = initialIndex;
    } else {
      _selectedWorkoutIndex = 0;
    }

    _loadExerciseData();
  }

  Future<void> _loadExerciseData() async {
    try {
      final json = await rootBundle.loadString('lib/workouts_info/oefeninglijst.json');
      final data = jsonDecode(json) as Map<String, dynamic>;
      final list = data['exerciseList'] as List<dynamic>;
      final allNames = <String>[];
      final exerciseToMuscles = <String, List<String>>{};
      final meta = <String, ({String reps, String restTime})>{};
      final muscleToExercises = <String, List<String>>{};

      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        final exercises = map['exercises'] as List<dynamic>? ?? [];
        final names = <String>[];
        for (final e in exercises) {
          final exMap = e as Map<String, dynamic>;
          final name = exMap['name'] as String? ?? '';
          final trained = (exMap['trainedMuscles'] as List<dynamic>?)
              ?.map((m) => (m as String).trim().toLowerCase())
              .toList() ?? [];
          if (name.isNotEmpty) {
            // Shoulder Press appears twice in JSON (Side Delts + Front Delts); only add once.
            if (name == 'Shoulder Press' && allNames.contains('Shoulder Press')) continue;
            names.add(name);
            allNames.add(name);
            exerciseToMuscles[name] = trained;
            meta[name] = (
              reps: (exMap['reps'] as String? ?? '').trim(),
              restTime: (exMap['restTime'] as String? ?? '').trim(),
            );
            for (final m in trained) {
              muscleToExercises.putIfAbsent(m, () => []).add(name);
            }
          }
        }
      }

      final alternatives = <String, List<String>>{};
      // Eerst: alternatieven op basis van similarExercises uit de JSON,
      // en de relaties symmetrisch maken.
      // Shoulder Press appears twice because of Side Delts and Front Delts, so one entry needs to be deleted
      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        final exercises = map['exercises'] as List<dynamic>? ?? [];
        for (final e in exercises) {
          final exMap = e as Map<String, dynamic>;
          final name = exMap['name'] as String? ?? '';
          final similarRaw = exMap['similarExercises'] as List<dynamic>?;
          if (name.isEmpty) continue;
          if (similarRaw != null && similarRaw.isNotEmpty) {
            final sims = similarRaw
                .map((s) => (s as String).trim())
                .where((s) => s.isNotEmpty)
                .toList();
            // Voor de hoofd-oefening: alle similarExercises als alternatieven.
            alternatives[name] = {
              ...(alternatives[name] ?? const []),
              ...sims,
            }.toList()
              ..sort();
            // Maak de relatie symmetrisch: ook vanuit elke similar oefening
            // moet je kunnen terugwisselen naar de originele en andere similars.
            for (final sim in sims) {
              final existing = alternatives[sim] ?? const <String>[];
              final union = {
                ...existing,
                name,
                ...sims.where((other) => other != sim),
              };
              alternatives[sim] = union.toList()..sort();
            }
          }
        }
      }
      // Fallback: voor oefeningen zonder explicit similarExercises
      // nog steeds alternatieven op basis van dezelfde spiergroep.
      for (final name in allNames) {
        alternatives.putIfAbsent(name, () {
          final muscles = exerciseToMuscles[name] ?? [];
          final alt = <String>{};
          for (final m in muscles) {
            for (final ex in muscleToExercises[m] ?? []) {
              if (ex != name) alt.add(ex);
            }
          }
          return alt.toList()..sort();
        });
      }

      if (mounted) {
        setState(() {
          _allExerciseNames = allNames..sort();
          _exerciseMeta = meta;
          _alternativesPerExercise = alternatives;
        });
      }
    } catch (_) {}
  }

  SurveyResultSummary _buildSummary() {
    final scheduled = _scheduledDaysPerWorkout.map((list) => List<String>.from(list)).toList();
    while (scheduled.length < _days.length) {
      scheduled.add([]);
    }
    final existingNames = widget.summary.workoutNames;
    final List<String> workoutNames = (existingNames != null &&
            existingNames.length == _exercisesPerDay.length)
        ? List<String>.from(existingNames)
        : List.generate(_exercisesPerDay.length, (i) => 'workout ${i + 1}');
    return SurveyResultSummary(
      availableDays: widget.summary.availableDays,
      muscleOrder: widget.summary.muscleOrder,
      totalSetsPerWeek: widget.summary.totalSetsPerWeek,
      highestFreq: widget.summary.highestFreq,
      caseInfo: widget.summary.caseInfo,
      step6ResultPattern: _pattern,
      step6ResultDays: _days,
      step6ExpectedPattern: widget.summary.step6ExpectedPattern,
      step6ExpectedDays: widget.summary.step6ExpectedDays,
      step7Info: widget.summary.step7Info,
      step10PerDayExercises: _exercisesPerDay,
      scheduledDaysPerWorkout: scheduled,
      workoutNames: workoutNames,
    );
  }

  Future<void> _save() async {
    final summary = _buildSummary();
    if (!isValidWorkoutSplit(summary)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'At least 1 workout with at least 1 exercise with at least 1 setis required',
            ),
          ),
        );
      }
      return;
    }
    await saveWorkoutSplit(summary);
    if (!mounted) return;
    _hasUnsavedChanges = false;
    _allowDirectPop = true;
    _goToWeekplanning();
  }

  void _addWorkout() {
    setState(() {
      _hasUnsavedChanges = true;
      _days.add('Workout ${_days.length + 1}');
      _scheduledDaysPerWorkout.add([]);
      _exercisesPerDay.add([]);
      // Pattern meegroeien met cijfer (voor step6ResultPattern); geen letters.
      _pattern += (_exercisesPerDay.length).toString();
      _selectedWorkoutIndex = _exercisesPerDay.length - 1;
    });
  }

  void _removeWorkout(int index) {
    if (_exercisesPerDay.length <= 1) return;
    setState(() {
      _hasUnsavedChanges = true;
      // Bij custom toegevoegde workouts kon pattern soms korter zijn; guard tegen out-of-range.
      if (index >= 0 && index < _pattern.length) {
        _pattern = _pattern.replaceRange(index, index + 1, '');
      }
      _days.removeAt(index);
      _scheduledDaysPerWorkout.removeAt(index);
      _exercisesPerDay.removeAt(index);
      if (_selectedWorkoutIndex >= _exercisesPerDay.length) {
        _selectedWorkoutIndex = _exercisesPerDay.length - 1;
      } else if (_selectedWorkoutIndex >= index && _selectedWorkoutIndex > 0) {
        _selectedWorkoutIndex--;
      }
    });
  }

  void _editWorkoutName() {
    final i = _selectedWorkoutIndex;
    if (i >= _days.length) return;
    var name = _days[i];
    final controller = TextEditingController(text: name);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Naam workout'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Bijv. Maandag, Push, A',
          ),
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(context),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final newName = controller.text.trim();
                    if (newName.isNotEmpty) {
                      setState(() {
                        _days[i] = newName;
                        _hasUnsavedChanges = true;
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addCustomExercise() {
    final nameController = TextEditingController();
    final setsController = TextEditingController(text: '2');
    final repsController = TextEditingController(text: '5-7');
    final rirController = TextEditingController();
    final restController = TextEditingController(text: '180');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom exercise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Exercise name',
                  hintText: 'E.g. custom exercise',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: setsController,
                decoration: const InputDecoration(labelText: 'Sets'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repsController,
                decoration: const InputDecoration(labelText: 'Reps'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rirController,
                decoration: const InputDecoration(labelText: 'Reps In Reserve'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: restController,
                decoration: const InputDecoration(labelText: 'Rest (seconds)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final sets = int.tryParse(setsController.text) ?? 3;
              final reps = repsController.text.trim().isEmpty ? '' : repsController.text.trim();
              final rir = rirController.text.trim();
              print('rest: ${restController.text}');
              final restSeconds = int.tryParse(restController.text) ?? 180;
              print('restSeconds: $restSeconds');
              setState(() {
                _hasUnsavedChanges = true;
                _exercisesPerDay[_selectedWorkoutIndex].add((
                  name: name,
                  sets: sets,
                  reps: reps,
                  restTime: '${restSeconds}s',
                  rir: rir,
                  restSeconds: restSeconds,
                ));
                // Zorg dat custom oefening ook verschijnt in de algemene 'Add exercise'-lijst.
                if (!_allExerciseNames.contains(name)) {
                  _allExerciseNames = [..._allExerciseNames, name]..sort();
                  _exerciseMeta[name] = (
                    reps: reps,
                    restTime: '${restSeconds}s',
                  );
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Toevoegen'),
          ),
        ],
      ),
    );
  }

  void _addExercise() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Add exercise',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline),
                        title: Text(
                          'Custom',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        subtitle: const Text('Add your own exercise'),
                        onTap: () {
                          Navigator.pop(context);
                          _addCustomExercise();
                        },
                      ),
                      const Divider(height: 1),
                      ..._allExerciseNames.map((name) {
                        final meta = _exerciseMeta[name];
                        return ListTile(
                          title: Text(name),
                          subtitle: meta != null ? Text('${meta.reps} · ${meta.restTime}') : null,
                          onTap: () {
                            final entry = (
                              name: name,
                              sets: 3,
                              reps: meta?.reps ?? '',
                              restTime: meta?.restTime ?? '',
                              rir: '',
                              restSeconds: _parseRestToSeconds(meta?.restTime ?? ''),
                            );
                            setState(() {
                              _hasUnsavedChanges = true;
                              _exercisesPerDay[_selectedWorkoutIndex].add(entry);
                            });
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeExercise(int workoutIndex, int exerciseIndex) {
    setState(() {
      _hasUnsavedChanges = true;
      _exercisesPerDay[workoutIndex].removeAt(exerciseIndex);
    });
  }

  void _onReorderExercises(int oldIndex, int newIndex) {
    setState(() {
      _hasUnsavedChanges = true;
      final list = _exercisesPerDay[_selectedWorkoutIndex];
      if (newIndex > oldIndex) newIndex--;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });
  }

  void _editExercise(int workoutIndex, int exerciseIndex) {
    final list = _exercisesPerDay[workoutIndex];
    if (exerciseIndex >= list.length) return;
    var entry = list[exerciseIndex];
    var sets = entry.sets;
    var reps = entry.reps;
    var rir = entry.rir;
    var restSeconds = entry.restSeconds > 0 ? entry.restSeconds : _parseRestToSeconds(entry.restTime);

    final setsController = TextEditingController(text: '$sets');
    final repsController = TextEditingController(text: reps);
    final rirController = TextEditingController(text: rir);
    final restController = TextEditingController(text: '$restSeconds');

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: setsController,
                decoration: const InputDecoration(labelText: 'Sets'),
                keyboardType: TextInputType.number,
                onChanged: (v) => sets = int.tryParse(v) ?? sets,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repsController,
                decoration: const InputDecoration(labelText: 'Reps'),
                onChanged: (v) => reps = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rirController,
                decoration: const InputDecoration(labelText: 'Reps In Reserve'),
                onChanged: (v) => rir = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: restController,
                decoration: const InputDecoration(labelText: 'Rest (seconds)'),
                keyboardType: TextInputType.number,
                onChanged: (v) => restSeconds = int.tryParse(v) ?? restSeconds,
              ),
              if ((_alternativesPerExercise[entry.name]?.length ?? 0) > 0) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAlternativesAndSwap(workoutIndex, exerciseIndex);
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Swap Exercise'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    sets = int.tryParse(setsController.text) ?? sets;
                    reps = repsController.text.trim().isEmpty ? entry.reps : repsController.text;
                    rir = rirController.text;
                    restSeconds = int.tryParse(restController.text) ?? restSeconds;
                    setState(() {
                      _hasUnsavedChanges = true;
                      list[exerciseIndex] = (
                        name: entry.name,
                        sets: sets,
                        reps: reps,
                        restTime: entry.restTime,
                        rir: rir,
                        restSeconds: restSeconds,
                      );
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAlternativesAndSwap(int workoutIndex, int exerciseIndex) {
    final entry = _exercisesPerDay[workoutIndex][exerciseIndex];
    final alts = _alternativesPerExercise[entry.name];
      if (alts == null || alts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No alternatives available for this exercise.'),
          ),
        );
        return;
      }
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Alternatieven voor ${entry.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: alts.length,
                itemBuilder: (context, i) {
                  final altName = alts[i];
                  final metaAlt = _exerciseMeta[altName];
                  final metaEntry = _exerciseMeta[entry.name];
                  return ListTile(
                    title: Text(altName),
                    subtitle: metaAlt != null ? Text('${metaAlt.reps} · ${metaAlt.restTime}') : null,
                    onTap: () {
                      setState(() {
                        _hasUnsavedChanges = true;
                        final nameA = entry.name;
                        final nameB = altName;
                        for (int w = 0; w < _exercisesPerDay.length; w++) {
                          for (int idx = 0; idx < _exercisesPerDay[w].length; idx++) {
                            final rec = _exercisesPerDay[w][idx];
                            if (rec.name == nameA) {
                              _exercisesPerDay[w][idx] = (
                                name: nameB,
                                sets: rec.sets,
                                reps: metaAlt?.reps ?? rec.reps,
                                restTime: metaAlt?.restTime ?? rec.restTime,
                                rir: rec.rir,
                                restSeconds: rec.restSeconds > 0 ? rec.restSeconds : _parseRestToSeconds(metaAlt?.restTime ?? ''),
                              );
                            } else if (rec.name == nameB) {
                              _exercisesPerDay[w][idx] = (
                                name: nameA,
                                sets: rec.sets,
                                reps: metaEntry?.reps ?? rec.reps,
                                restTime: metaEntry?.restTime ?? rec.restTime,
                                rir: rec.rir,
                                restSeconds: rec.restSeconds > 0 ? rec.restSeconds : _parseRestToSeconds(metaEntry?.restTime ?? ''),
                              );
                            }
                          }
                        }
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static int _parseRestToSeconds(String restTime) {
    if (restTime.isEmpty) return 180;
    final lower = restTime.toLowerCase();
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(lower);
    if (minMatch != null) return (int.tryParse(minMatch.group(1) ?? '') ?? 0) * 60;
    final secMatch = RegExp(r'(\d+)\s*s').firstMatch(lower);
    if (secMatch != null) return int.tryParse(secMatch.group(1) ?? '') ?? 180;
    final numMatch = RegExp(r'~?\s*(\d+)').firstMatch(restTime);
    if (numMatch != null) return (int.tryParse(numMatch.group(1) ?? '') ?? 3) * 60;
    return 180;
  }

  @override
  Widget build(BuildContext context) {
    final workouts = _exercisesPerDay;
    if (workouts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Edit Workout'),
        ),
        body: const Center(child: Text('No workouts')),
      );
    }

    final currentExercises = workouts[_selectedWorkoutIndex];
    final dayLabel = _selectedWorkoutIndex < _days.length
        ? _days[_selectedWorkoutIndex]
        : 'Workout ${_selectedWorkoutIndex + 1}';

    return PopScope(
      canPop: _allowDirectPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_hasUnsavedChanges) {
          if (mounted) _goToWeekplanning();
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Unsaved changes',
                  style: Theme.of(ctx).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to leave? Your changes will not be saved.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        if (leave == true && mounted) {
          _goToWeekplanning();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Edit Workouts'),
          actions: [
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      /// Add a bit of space between the text of the current workout and the left side of the dropdown text field
                      final label = _selectedWorkoutIndex < _days.length
                          ? _days[_selectedWorkoutIndex]
                          : 'Workout ${_selectedWorkoutIndex + 1}';
                      return InkWell(
                        onTap: () async {
                          final box = context.findRenderObject() as RenderBox?;
                          if (box == null || !mounted) return;
                          final topLeft = box.localToGlobal(Offset.zero);
                          final screenWidth = MediaQuery.sizeOf(context).width;
                          const menuLeftInset = 14.0;
                          // Rechthoek even breed als dropdown, links uitgelijnd met ruimte; zo align het menu links
                          final position = RelativeRect.fromLTRB(
                            menuLeftInset,
                            topLeft.dy + box.size.height,
                            screenWidth - menuLeftInset - box.size.width,
                            0,
                          );
                          final selected = await showMenu<int>(
                            context: context,
                            position: position,
                            items: List.generate(workouts.length, (i) {
                              final itemLabel = i < _days.length ? _days[i] : 'Workout ${i + 1}';
                              return PopupMenuItem<int>(
                                value: i,
                                child: Text(itemLabel),
                              );
                            }),
                          );
                          if (selected != null && mounted) {
                            setState(() => _selectedWorkoutIndex = selected);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: Theme.of(context).textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Workout toevoegen',
                  onPressed: _addWorkout,
                ),
                if (workouts.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Workout verwijderen',
                    onPressed: () => _removeWorkout(_selectedWorkoutIndex),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Name: ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                GestureDetector(
                  onTap: _editWorkoutName,
                  child: Text(
                    dayLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: Theme.of(context).colorScheme.primary,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Scheduled on: ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Expanded(
                  child: _ScheduledDaysDropdown(
                    selectedDays: _selectedWorkoutIndex < _scheduledDaysPerWorkout.length
                        ? _scheduledDaysPerWorkout[_selectedWorkoutIndex]
                        : [],
                    weekdays: _editWorkoutWeekdays,
                    displayDayName: _displayDayName,
                    onChanged: (newDays) {
                      setState(() {
                        _hasUnsavedChanges = true;
                        while (_scheduledDaysPerWorkout.length <= _selectedWorkoutIndex) {
                          _scheduledDaysPerWorkout.add([]);
                        }
                        _scheduledDaysPerWorkout[_selectedWorkoutIndex] = List.from(newDays);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${currentExercises.length} exercises',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: currentExercises.length,
              onReorder: _onReorderExercises,
              itemBuilder: (context, index) {
                final ex = currentExercises[index];
                return Card(
                  key: ValueKey('${_selectedWorkoutIndex}_${ex.name}_$index'),
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, size: 20),
                    ),
                    title: Text(
                      ex.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${ex.sets} sets · ${ex.reps} reps',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _removeExercise(_selectedWorkoutIndex, index),
                    ),
                    onTap: () => _editExercise(_selectedWorkoutIndex, index),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
            ),
          ),
        ],
        ),
      ),
    );
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
}

/// Dropdown-achtige knop die de geselecteerde dagen toont; bij klik opent een menu met checkboxes per dag.
class _ScheduledDaysDropdown extends StatelessWidget {
  final List<String> selectedDays;
  final List<String> weekdays;
  final String Function(String) displayDayName;
  final ValueChanged<List<String>> onChanged;

  const _ScheduledDaysDropdown({
    required this.selectedDays,
    required this.weekdays,
    required this.displayDayName,
    required this.onChanged,
  });

  String _label(List<String> selected, List<String> weekdays, String Function(String) displayDayName) {
    if (selected.isEmpty) return 'Not scheduled';
    final inOrder = weekdays.where(selected.contains).map(displayDayName).toList();
    return inOrder.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final label = _label(selectedDays, weekdays, displayDayName);
    return InkWell(
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final topLeft = box.localToGlobal(Offset.zero);
        final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
        final screen = MediaQuery.sizeOf(context);
        final position = RelativeRect.fromLTRB(
          topLeft.dx,
          bottomRight.dy,
          screen.width - bottomRight.dx,
          screen.height - bottomRight.dy,
        );
        showMenu<void>(
          context: context,
          position: position,
          items: [
            PopupMenuItem<void>(
              enabled: false,
              child: _ScheduledDaysMenuContent(
                initialSelected: selectedDays,
                weekdays: weekdays,
                displayDayName: displayDayName,
                onChanged: onChanged,
              ),
            ),
          ],
        );
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.arrow_drop_down),
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// Menu-inhoud met checkboxes; houdt eigen state bij zodat de lijst direct visueel update.
class _ScheduledDaysMenuContent extends StatefulWidget {
  final List<String> initialSelected;
  final List<String> weekdays;
  final String Function(String) displayDayName;
  final ValueChanged<List<String>> onChanged;

  const _ScheduledDaysMenuContent({
    required this.initialSelected,
    required this.weekdays,
    required this.displayDayName,
    required this.onChanged,
  });

  @override
  State<_ScheduledDaysMenuContent> createState() => _ScheduledDaysMenuContentState();
}

class _ScheduledDaysMenuContentState extends State<_ScheduledDaysMenuContent> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
  }

  void _toggle(String dag) {
    setState(() {
      if (_selected.contains(dag)) {
        _selected.remove(dag);
      } else {
        _selected.add(dag);
      }
      widget.onChanged(List<String>.from(_selected));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: widget.weekdays.map((dag) {
        return CheckboxListTile(
          value: _selected.contains(dag),
          title: Text(widget.displayDayName(dag)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (_) => _toggle(dag),
        );
      }).toList(),
    );
  }
}
