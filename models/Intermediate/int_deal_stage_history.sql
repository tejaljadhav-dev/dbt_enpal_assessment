-- Materialized as a view: window functions over ~9k stage changes are cheap
-- and the model only feeds int_funnel_events. Switch to a table if deal
-- volumes grow or other models start reading it heavily.
{{
    config(
        materialized = 'view'
    )
}}

with deal_changes as (

    select * from {{ ref('stg_deal_changes') }}

),

stages as (

    select * from {{ ref('stg_stages') }}

),

-- keep only stage moves; each one is the deal entering a stage
stage_changes as (

    select
        deal_change_id                  as deal_change_id,
        deal_id                         as deal_id,
        -- null (not an error) if new_value is not a valid id; the not_null test flags it
        {{ safe_cast_integer('new_value') }} as stage_id,
        changed_at                      as entered_at
    from deal_changes
    where changed_field_key = 'stage_id'

),

final as (

    select
        stage_changes.deal_change_id    as deal_change_id,
        stage_changes.deal_id           as deal_id,
        stage_changes.stage_id          as stage_id,
        stages.stage_name               as stage_name,
        stage_changes.entered_at        as entered_at,
        -- stage the deal came from; null for its first stage. Lets consumers
        -- spot skips (4 -> 6) and backward moves.
        lag(stage_changes.stage_id) over (
            partition by stage_changes.deal_id
            order by stage_changes.entered_at
        )                               as previous_stage_id,
        -- 1 = first time the deal entered this stage, 2+ = re-entry
        -- (only happens in the five deal_ids that carry two lifecycles)
        row_number() over (
            partition by stage_changes.deal_id, stage_changes.stage_id
            order by stage_changes.entered_at
        )                               as stage_entry_number
    from stage_changes
    left join stages
        on stage_changes.stage_id = stages.stage_id

)

select * from final
