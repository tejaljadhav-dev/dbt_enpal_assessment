with stage_history as (

    select * from {{ ref('int_deal_stage_history') }}

),

sales_calls as (

    select * from {{ ref('int_sales_calls') }}

),

funnel_mapping as (

    select * from {{ ref('funnel_step_mapping') }}

),

stage_events as (

    select
        stage_history.deal_id,
        stage_history.entered_at as event_at,
        'stage_change' as event_type,
        stage_history.deal_change_id as source_event_id,
        funnel_mapping.funnel_step,
        funnel_mapping.kpi_name
    from stage_history
    inner join funnel_mapping
        on funnel_mapping.source_type = 'stage'
        and funnel_mapping.source_key = cast(stage_history.stage_id as varchar)

),

sales_call_events as (

    select
        sales_calls.deal_id,
        sales_calls.called_at as event_at,
        'activity' as event_type,
        sales_calls.activity_key as source_event_id,
        funnel_mapping.funnel_step,
        funnel_mapping.kpi_name
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

ranked as (

    select
        *,
        row_number() over (
            partition by deal_id, funnel_step
            order by event_at, source_event_id
        ) as entry_rank
    from all_events

),

final as (

    -- a deal counts as entering a step once: at its first entry
    select
        deal_id,
        funnel_step,
        kpi_name,
        event_at,
        event_type,
        source_event_id
    from ranked
    where entry_rank = 1

)

select * from final
