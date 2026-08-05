-- Survey MCQ answer outcomes for the developer dashboard (date-ranged).
-- Mirrors public.analytics_survey_mcq_answer_outcomes with [p_from, p_to) filter.

drop function if exists public.dashboard_survey_mcq_answer_outcomes(timestamptz, timestamptz);

create or replace function public.dashboard_survey_mcq_answer_outcomes(
  p_from timestamptz,
  p_to timestamptz
)
returns table (
  step_name text,
  answer_value text,
  users_selected bigint,
  subscription_rate numeric,
  survey_completion_rate numeric,
  subscription_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with constants as (
    select 23::numeric as total_survey_steps
  ),
  normalized_events as (
    select
      public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) as user_id,
      e.event_name,
      e.properties,
      e.created_at
    from public.analytics_events e
    where e.created_at >= p_from
      and e.created_at < p_to
      and public.dashboard_analytics_user_key(e.analytics_user_id, e.anonymous_id) is not null
  ),
  user_outcomes as (
    select
      user_id,
      max((properties ->> 'step_index')::int) filter (
        where event_name = 'onboarding_step_completed'
      ) as max_step_index_completed,
      bool_or(event_name = 'onboarding_completed') as reached_survey_end,
      bool_or(event_name = 'purchase_success') as purchased
    from normalized_events
    group by user_id
  ),
  user_progress as (
    select
      u.user_id,
      u.max_step_index_completed,
      u.reached_survey_end,
      u.purchased,
      case
        when u.reached_survey_end then 1::numeric
        else (
          greatest(coalesce(u.max_step_index_completed, -1), 0) + 1
        ) / c.total_survey_steps
      end as survey_completion_ratio
    from user_outcomes u
    cross join constants c
  ),
  goal_source_events as (
    select
      e.user_id,
      e.created_at,
      1 as source_priority,
      e.properties ->> 'selected_value_summary' as raw_answer
    from normalized_events e
    where e.event_name = 'onboarding_step_completed'
      and e.properties ->> 'step_name' = 'goal'
      and e.properties ->> 'selected_value_summary' is not null
      and btrim(e.properties ->> 'selected_value_summary') <> ''

    union all

    select
      e.user_id,
      e.created_at,
      2 as source_priority,
      e.properties ->> 'selected_goal' as raw_answer
    from normalized_events e
    where e.event_name = 'plan_generation_completed'
      and e.properties ->> 'selected_goal' is not null
      and btrim(e.properties ->> 'selected_goal') <> ''

    union all

    select
      e.user_id,
      e.created_at,
      3 as source_priority,
      e.properties ->> 'selected_goal' as raw_answer
    from normalized_events e
    where e.event_name = 'plan_generation_started'
      and e.properties ->> 'selected_goal' is not null
      and btrim(e.properties ->> 'selected_goal') <> ''
  ),
  goal_raw_per_user as (
    select distinct on (user_id)
      user_id,
      'goal'::text as step_name,
      1::int as step_index,
      raw_answer,
      'goal'::text as delimiter
    from goal_source_events
    order by user_id, source_priority, created_at desc
  ),
  mcq_steps as (
    select *
    from (
      values
        ('biggest_challenge', 3, ';'),
        ('training_experience', 8, null::text),
        ('training_frequency', 10, null::text),
        ('available_days', 11, ','),
        ('split_selection', 12, null::text),
        ('muscle_focus_simple', 14, null::text),
        ('muscle_priority', 15, ','),
        ('plan_generation', 16, null::text),
        ('workout_notification_opt_in', 18, ',')
    ) as t(step_name, step_index, delimiter)
  ),
  raw_answers as (
    select
      g.user_id,
      g.step_name,
      g.step_index,
      g.raw_answer,
      g.delimiter
    from goal_raw_per_user g

    union all

    select
      e.user_id,
      m.step_name,
      m.step_index,
      e.properties ->> 'selected_value_summary' as raw_answer,
      m.delimiter
    from normalized_events e
    inner join mcq_steps m
      on m.step_name = (e.properties ->> 'step_name')
    where e.event_name = 'onboarding_step_completed'
      and e.properties ->> 'selected_value_summary' is not null
      and btrim(e.properties ->> 'selected_value_summary') <> ''

    union all

    select
      e.user_id,
      'training_frequency'::text,
      10,
      e.properties ->> 'frequencyRange',
      null::text
    from normalized_events e
    where e.event_name = 'split_survey_frequency_selected'
      and e.properties ->> 'frequencyRange' is not null
      and btrim(e.properties ->> 'frequencyRange') <> ''

    union all

    select
      e.user_id,
      'split_selection'::text,
      12,
      coalesce(
        e.properties ->> 'splitId',
        e.properties ->> 'selected_value_summary'
      ),
      null::text
    from normalized_events e
    where e.event_name = 'split_survey_split_selected'
      and coalesce(
        e.properties ->> 'splitId',
        e.properties ->> 'selected_value_summary'
      ) is not null
  ),
  split_parts as (
    select
      r.user_id,
      r.step_name,
      r.step_index,
      btrim(part) as answer_part
    from raw_answers r
    cross join lateral unnest(
      case
        when r.delimiter = 'goal' then
          case
            when position('|' in r.raw_answer) > 0 then
              regexp_split_to_array(r.raw_answer, '\s*,\s*(?=[^,|]+\|)')
            else
              regexp_split_to_array(r.raw_answer, '\s*,\s*')
          end
        when r.delimiter = ',' then regexp_split_to_array(r.raw_answer, '\s*,\s*')
        when r.delimiter = ';' then regexp_split_to_array(r.raw_answer, '\s*;\s*')
        else array[r.raw_answer]
      end
    ) as part
    where btrim(part) <> ''
  ),
  exploded_answers as (
    select distinct
      sp.user_id,
      sp.step_name,
      sp.step_index,
      case
        when sp.step_name in ('goal', 'biggest_challenge')
          and position('|' in sp.answer_part) > 0
        then btrim(substring(sp.answer_part from position('|' in sp.answer_part) + 1))
        else sp.answer_part
      end as answer_value
    from split_parts sp
    where btrim(
      case
        when sp.step_name in ('goal', 'biggest_challenge')
          and position('|' in sp.answer_part) > 0
        then btrim(substring(sp.answer_part from position('|' in sp.answer_part) + 1))
        else sp.answer_part
      end
    ) <> ''
  ),
  answer_metrics as (
    select
      ea.step_name,
      ea.step_index,
      ea.answer_value,
      count(distinct ea.user_id) as users_selected_answer,
      count(distinct ea.user_id) filter (where up.reached_survey_end) as users_reached_survey_end,
      count(distinct ea.user_id) filter (where up.purchased) as subscription_count
    from exploded_answers ea
    inner join user_progress up on up.user_id = ea.user_id
    group by ea.step_name, ea.step_index, ea.answer_value
  )
  select
    am.step_name,
    am.answer_value,
    am.users_selected_answer::bigint as users_selected,
    round(
      am.subscription_count::numeric / nullif(am.users_selected_answer, 0),
      4
    ) as subscription_rate,
    round(
      am.users_reached_survey_end::numeric / nullif(am.users_selected_answer, 0),
      4
    ) as survey_completion_rate,
    am.subscription_count::bigint as subscription_count
  from answer_metrics am
  where am.users_selected_answer > 0
    and am.step_name not in ('week_schedule_preview', 'transformation_proof')
  order by am.step_index, am.users_selected_answer desc;
$$;

comment on function public.dashboard_survey_mcq_answer_outcomes(timestamptz, timestamptz) is
  'Survey MCQ answer outcomes for [p_from, p_to): users, completion rate, subscription rate.';

grant execute on function public.dashboard_survey_mcq_answer_outcomes(timestamptz, timestamptz)
  to anon, authenticated, service_role;
