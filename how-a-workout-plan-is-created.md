# How a personalized workout plan is created

This document describes exactly how Lift Better builds an individual workout plan. It follows the steps the app actually runs after the survey. Nothing is included that the app does not do, and nothing that leads to the plan is left out.

---

## Short summary: which survey information is used?

The survey asks several questions. Only some of them determine the plan. Below is first what is asked, then what actually goes into the calculation.

### What the survey asks

1. **Goals** — for example build muscle, lose body fat, get stronger, be more consistent, be more healthy.
2. **What someone struggles with** — for example wanting an optimized program, not knowing exactly what to do, consistency and motivation, combining training with the rest of life, or feeling confident in the gym.
3. **Training experience** — beginner, intermediate, or advanced.
4. **Exercise selection** — simple yet effective exercises, or optimal exercises.
5. **Training frequency** — how many times per week someone wants to train: 1–2, 2–3, 3–4, 4–5, or 5–6 days.
6. **Available days** — which weekdays someone can train.
7. **Split choice** — which training structure fits (for example Full Body, Upper/Lower, Anterior/Posterior, Push/Pull/Legs), including the exact placement of those workouts on the chosen days.
8. **Muscle focus** — how much each muscle group (or, in advanced mode, up to 21 muscles) should be trained, from “not at all” to “maximal.”
9. **Muscle group priority** — in which order muscles matter when choices have to be made about sets.

Optional in advanced muscle focus (depending on exercise mode):

- **Muscle bias** for biceps, triceps, and lats (which part of the muscle gets more emphasis).
- **Sub-biases** such as upper chest, side delts, upper glutes, or training spinal erectors separately.

### What of that determines the plan

The plan is built from this input:

- chosen frequency band and available days (to show split options)
- the split and day layout chosen by the user
- growth level per (sub)muscle
- priority order of muscle groups
- exercise mode (simple or optimal)
- any bias and sub-bias choices

Goals, struggle answers, and training experience are asked in the survey, but they do not determine the number of sets, frequency per muscle, or which exercises end up in the plan. They shape onboarding guidance and presentation, not the volume and exercise calculation.

---

## <u>**Workout generation process**</u>

After the survey is finished, the app builds the plan on-device. There is no external server that invents the plan. The pipeline runs in this order:

1. Lock in the chosen split and weekly layout.
2. Determine frequency and sets per muscle from growth level.
3. Merge sub-muscles into muscle groups, correcting for exercises that train multiple muscles at once.
4. Sum weekly set volume.
5. Lock in muscle priority order.
6. Assign the correct muscle groups to each training day.
7. Expand muscle groups back into sub-muscles with sets per day.
8. Shorten workouts to a maximum of 20 effective sets per session.
9. Add sets where the rules allow it.
10. Convert sets into concrete exercises, rep ranges, and rest times.
11. Merge identical workouts into one workout scheduled on multiple days.

Each of these steps is covered as its own chapter below.

---

## Chapter 1 — Locking in the weekly structure

In the survey, the user chooses how many days per week they want to train and which days are available. From that combination, the app shows a fixed list of possible splits. Examples of split types are:

- Full Body
- Upper / Lower
- Anterior / Posterior
- Push / Pull / Legs
- combinations of those, such as Upper / Lower / Full Body

The user picks one split option and one concrete weekly layout. That layout maps each training day to a session type, for example:

- Monday: Upper
- Wednesday: Lower
- Friday: Upper

From this point on, the weekly structure is fixed. Later steps distribute volume and exercises across exactly these days and session types. The app does not invent a new day arrangement; it works with what the user chose.

For later volume calculation, the number of training days in that layout counts as available frequency for muscles, capped at three. That means: in the ranking tables, a muscle cannot get a target frequency above three times per week, even if someone has more training days. The muscle can still land on multiple days through the split, but the starting frequency from the ranking tables is limited to 0–3.

---

## Chapter 2 — Converting growth level per muscle into frequency and sets

Every (sub)muscle that received an intensity in the survey gets a growth level from 0 to 6.

In simple muscle focus, the user chooses a level per main group (Chest, Back, Arms, Abs, Legs). Those levels are translated to the underlying muscles. In advanced mode, levels can be set directly per muscle or sub-muscle.

### Volume level of a muscle

Independent of what the user wants, every muscle has a fixed volume level from 1 to 4. That level describes how “heavy” or recoverable that muscle is treated in the system. Examples:

- Upper chest: 1
- Mid chest: 2
- Biceps: 3
- Side delts: 4
- Lats: 4
- Hamstrings: 4 (in simple exercise mode: 3)

### From growth level to ranking

Growth level is converted into a starting ranking:

- growth level 0 → ranking 10 (no training)
- growth level 1 → ranking 9
- growth level 2 → ranking 6
- growth level 3 → ranking 4
- growth level 4 → ranking 3
- growth level 5 → ranking 2
- growth level 6 → ranking 1

Each ranking maps to a frequency and a set count per session:

- ranking 1 → 3× per week, 3 sets
- ranking 2 → 3× per week, 2 sets
- ranking 3 → 2× per week, 3 sets
- ranking 4 → 3× per week, 1 set
- ranking 5 → 2× per week, 2 sets
- ranking 6 → 2× per week, 1 set
- ranking 7 → 1× per week, 3 sets
- ranking 8 → 1× per week, 2 sets
- ranking 9 → 1× per week, 1 set
- ranking 10 → 0× per week, 0 sets

### When a ranking is not allowed

A ranking is only valid if both of these are true:

1. the muscle’s volume level is among the allowed volume levels for that ranking
2. the ranking’s frequency is not higher than the available frequency from Chapter 1

If the starting ranking is not allowed, the system moves one ranking down (numerically higher, so less aggressive) and tries again until a valid ranking is found.

The result of this chapter is, for each muscle: how often per week, and with how many sets each time.

---

## Chapter 3 — Merging sub-muscles into muscle groups

After Chapter 2, values still exist per individual muscle, such as Mid chest, Upper chest, Side delts, and Front delts. To distribute them across workouts, they are merged into muscle groups such as Chest or Shoulders.

For each muscle group, the system determines:

- frequency (the highest frequency among the sub-muscles in that group)
- the number of sets per training session in that group

Important: if two sub-muscles are trained by the same exercise, their sets are not added blindly. The system looks at the exercise list and books sets so that overlap is not double-counted.

There are fixed exception rules for certain groups:

### Shoulders

Side delts and front delts are converted into a combination of shoulder press sets and lateral raise sets using a fixed table. The set count for the shoulder group is the sum of those two exercise counts.

### Upper Back

All sub-muscle sets are added up, minus the minimum of rear delts and mid traps. That corrects overlap between those two.

### Quadriceps & Glutes

Overlap between rectus femoris, vastus muscles, and gluteus maximus is corrected as follows:

- if rectus femoris + gluteus maximus is less than or equal to vastus: total minus (rectus femoris + gluteus maximus)
- otherwise: total minus vastus

### Other groups

For groups without a special rule: exercises that train multiple sub-muscles count, per session, as the maximum of the remaining sets for those sub-muscles; those sets are then booked off.

The result of this chapter is, per muscle group, something like: frequency 3, sets per session 4, 3, 3.

---

## Chapter 4 — Summing sets per week

All sets from Chapter 3 are summed per muscle group across sessions. Those weekly totals are then added together into one number: the provisional weekly set volume of the whole plan.

This number is an intermediate result. Later, sets can still be removed or added per workout.

---

## Chapter 5 — Muscle priority order

The survey provides an order of muscle groups: which muscles matter most.

That order is used later when something has to give. If a workout becomes too long, sets are removed first from muscles lower in priority. When sets may be added, that happens in the opposite direction relative to the shortening logic, so priority still matters.

Muscle groups with growth level 0 are not included in this priority list.

The fixed groups that participate in priority include: Chest, Shoulders, Triceps, Lats, Upper Back, Biceps, Forearms, Abs, Obliques, Spinal Erectors, Quadriceps, Glutes, Hamstrings, Adductors, and Calves.

---

## Chapter 6 — Placing muscle groups on training days

Each training day has a session type from the chosen split. For each session type, it is fixed which muscle groups may appear.

### Full Body

All muscle groups that have volume in the plan, in the user’s priority order.

### Upper

Chest, Upper Back, Lats, Biceps, Triceps, Shoulders, Forearms.

### Lower

Quadriceps, Glutes, Hamstrings, Calves, Adductors, Abs, Obliques, Spinal Erectors.

### Anterior

Chest, Obliques, Forearms, Abs, Shoulders, Adductors, Quadriceps, Triceps.

### Posterior

Biceps, Upper Back, Lats, Spinal Erectors, Hamstrings, Glutes, Calves.

### Push

Chest, Shoulders, Triceps, Abs, Obliques.

### Pull

Biceps, Upper Back, Lats, Spinal Erectors, Forearms.

### Legs

Quadriceps, Glutes, Hamstrings, Adductors, Calves.

Within such a fixed list, order is reshuffled to the survey priority. Muscle groups without volume are skipped.

If a muscle group appears multiple times per week, the system tracks which occurrence it is. That later determines which set slot from “sets per session” (for example the first, second, or third number) is used on that day.

---

## Chapter 7 — Expanding muscle groups back into sub-muscles

At this point, days still consist of muscle groups. For exercise selection and set logic, they must become sub-muscles again.

For groups with sub-muscles, that happens in a fixed order:

- Chest → Mid chest, Upper chest
- Shoulders → Side delts, Front delts
- Upper Back → Rear delts, Mid traps, Upper traps
- Quadriceps → Rectus Femoris, Vastus Muscles
- Glutes → Gluteus Maximus, Upper Glutes

For each sub-muscle, the system checks frequency and sets from Chapter 2, and which occurrence of that group’s training this day is. Only if that sub-muscle still has a session owed at that point does it land on the day with the matching set count.

For muscle groups without a separate sub-muscle expansion, the group itself remains, with the set count from the correct session slot in Chapter 3.

The result is a list per training day such as: Mid chest 3 sets, Upper chest 1 set, Side delts 3 sets, and so on.

---

## Chapter 8 — Shortening workouts to a maximum of 20 effective sets

A workout is not allowed to become too long. The limit is 20 effective sets per session.

“Effective sets” means sets after overlap correction. If one exercise covers multiple muscles, those do not all count separately. The count uses the same overlap logic later used for exercise assignment.

If a day has more than 20 effective sets, sets are removed:

1. start with the muscles lowest in priority
2. remove at most one set from such a muscle per round
3. recount
4. repeat until the workout is at or below 20 effective sets, or until nothing more can be removed

A muscle with 1 set that is removed disappears from that day entirely.

For splits that work as a repeating cycle, matching session types are then kept in sync again so the same workout kind does not drift apart.

---

## Chapter 9 — Adding sets where allowed

After shortening, the system may add sets again, but only under fixed conditions. The limit remains 20 effective sets per workout.

The system walks through the (sub)muscles and, for each muscle on a day, checks:

- how many sets that muscle already has on that day
- how many calendar days until that muscle is next trained
- the original ranking of that muscle
- the volume level of that muscle

Only if that combination falls within the allowance rules does the muscle get one extra set. Then the count is recalculated. If that extra set would push the workout above 20 effective sets, the set is undone.

The rules differ by recovery distance. In short:

- at 2 days until the next training, a set may only be added under strict conditions when there are already 1 or 2 sets
- at 3, 4, or 5 days, the conditions become gradually more open
- at 7 days (the muscle does not return earlier that week), separate thresholds apply

No set is added to a muscle that has 0 sets on that day. Adding stops when no muscle may receive another set, or when the workout is full.

---

## Chapter 10 — Converting sets into exercises

At this point it is fixed, per day, which (sub)muscles get how many sets. Those sets are converted into concrete exercises from the exercise list.

Each exercise has fixed metadata:

- name
- trained muscles
- rep range (often 5–7 by default)
- rest time

Assignment depends on exercise mode.

### Simple exercise mode

Here a muscle usually gets one primary exercise. Examples of that logic:

- Mid chest → machine chest flies
- Upper chest (only if that bias is on) → low to high flies
- Lats → wide grip lat pulldowns
- Biceps → machine bicep curls
- Triceps → tricep extensions
- Hamstrings → seated leg curl
- Gluteus Maximus → hip thrusts
- Upper glutes (only if that bias is on) → hip abductions
- Spinal erectors (only if separate training is on) → spinal extensions

### Optimal exercise mode

Here sets can be split across two exercises, and bias choices matter. Examples:

- Biceps, triceps, and lats: part of the sets go to exercise 1, the rest to exercise 2, depending on muscle bias 0, 1, or 2.
- Shoulders: side delts and front delts are converted via a table into shoulder press and lateral raise sets.
- Upper back: rear delts and mid traps can get separate exercises instead of one shared row.
- Hamstrings: sets are split across straight-leg deadlift and seated leg curl.
- Quadriceps outside an anterior/posterior split: rectus femoris goes to leg extensions; vastus minus those extensions goes to leg press.
- Quadriceps in simple mode or in an anterior/posterior split: max(rectus femoris, vastus) goes to leg extensions.

Muscles already fully covered by an earlier exercise do not get another separate exercise for the same sets.

The result of this chapter is, per training day, a list of exercises with sets, reps, and rest.

---

## Chapter 11 — Merging identical workouts

If multiple days have exactly the same exercises with the same values, they are merged into one workout scheduled on multiple days.

Example: three Full Body days with the same content become one Full Body workout, scheduled on Monday, Wednesday, and Friday.

If the same name appears multiple times with different content, later copies get a number, such as Upper (2).

This is the final result the user sees in the weekly planner: workout names, which days they fall on, and per workout the exercises with sets, reps, and rest.

---

## Which muscles the system knows

The plan works with these muscles and groups.

### Upper body

- Biceps
- Triceps
- Mid chest
- Upper chest
- Front delts
- Side delts
- Lats
- Mid traps
- Upper traps
- Rear delts
- Spinal erectors
- Abs
- Obliques
- Forearms

### Lower body

- Rectus femoris
- Vastus muscles
- Gluteus maximus
- Upper glutes
- Hamstrings
- Adductors
- Calves

Survey muscle groups can bundle several of these muscles. Chest covers mid chest and upper chest. Shoulders covers side delts and front delts. Upper back covers rear delts, mid traps, and upper traps. Legs, in simple mode, covers among other things quadriceps, glutes, hamstrings, adductors, and calves.

---

## What does not happen when the plan is created

To avoid misunderstandings:

- Goals such as “build muscle” or “lose bodyfat” do not automatically change the set formula.
- Training experience does not change the ranking tables or exercise assignment.
- There is no week-to-week progression built into the generated plan itself. The plan ships with fixed set and rep ranges; progression happens later through the user while logging.
- The app does not choose weekdays other than those in the selected layout.
- Exercises outside the internal exercise list and assignment rules are not invented.

---

## Final picture

A personalized plan therefore does not come from one rule of thumb, but from a fixed chain:

survey answers about days, split, muscle focus, priority, and exercise mode → frequency and sets per muscle → group aggregation with overlap correction → distribution across the chosen split days → shortening and targeted set additions to a workable workout length → conversion into concrete exercises → merging identical days.

Every user with the same relevant input gets the same type of plan through the same rules. Differences in the final plan come directly from differences in that input, not from randomness.
