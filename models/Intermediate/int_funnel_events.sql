-- Materialized as a view rather than ephemeral: it holds the funnel business
-- logic, so keeping it queryable in the database makes it easy to inspect
-- and debug individual deals. Small enough that a table is not needed.
{{
    config(
        materialized = 'view'
    )
}}

------ Start: Import CTEs ------
with stage_history as (

    select * from {{ ref('int_deal_stage_history') }}

),

sales_calls as (

    select * from {{ ref('int_sales_calls') }}

),

funnel_mapping as (

    select * from {{ ref('funnel_step_mapping') }}

),

------ End: Import CTEs ------

------ Start: Logic CTEs ------

-- steps 1-9: the deal moving into the mapped stage
stage_events as (

    select
        stage_history.deal_id           as deal_id,
        stage_history.entered_at        as event_at,
        'stage_change'                  as event_type,
        stage_history.deal_change_id    as source_event_id,
        funnel_mapping.funnel_step      as funnel_step,
        funnel_mapping.kpi_name         as kpi_name
    from stage_history
    inner join funnel_mapping
        on funnel_mapping.source_type = 'stage'
        -- source_key is text because it also holds activity type keys
        and funnel_mapping.source_key = cast(stage_history.stage_id as varchar)

),

-- steps 2.1 and 3.1: a completed sales call of the mapped activity type.
-- Most activity deal_ids are not in deal_changes, so these are not tied to
-- the stage history.
sales_call_events as (

    select
        sales_calls.deal_id             as deal_id,
        sales_calls.called_at           as event_at,
        'activity'                      as event_type,
        sales_calls.activity_key        as source_event_id,
        funnel_mapping.funnel_step      as funnel_step,
        funnel_mapping.kpi_name         as kpi_name
    from sales_calls
    inner join funnel_mapping
        on funnel_mapping.source_type = 'activity'
        and funnel_mapping.source_key = sales_calls.activity_type_key

),

all_events as (

    select * from stage_events
    union all
    select * from sales_call_events

),

-- order each deal's entries into a step by time; source_event_id breaks ties
-- so the result is deterministic
ranked as (

    select
        *,
        row_number() over (
            partition by deal_id, funnel_step
            order by event_at, source_event_id
        )                               as entry_rank
    from all_events

),

final as (

    -- a deal counts as entering a step once, at its first entry, so re-entries
    -- and repeated calls do not inflate the funnel
    select
        deal_id                         as deal_id,
        funnel_step                     as funnel_step,
        kpi_name                        as kpi_name,
        event_at                        as event_at,
        event_type                      as event_type,
        source_event_id                 as source_event_id
    from ranked
    where entry_rank = 1

)
------ End: Logic CTEs ------

------ Start: Final CTE ------

select * from final
