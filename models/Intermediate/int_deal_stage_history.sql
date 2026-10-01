with deal_changes as (

    select * from {{ ref('stg_deal_changes') }}

),

stages as (

    select * from {{ ref('stg_stages') }}

),

stage_changes as (

    select
        deal_change_id                  as deal_change_id,
        deal_id                         as deal_id,
        cast(new_value as integer)      as stage_id,
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
        lag(stage_changes.stage_id) over (
            partition by stage_changes.deal_id
            order by stage_changes.entered_at
        )                               as previous_stage_id,
        row_number() over (
            partition by stage_changes.deal_id, stage_changes.stage_id
            order by stage_changes.entered_at
        )                               as stage_entry_number
    from stage_changes
    left join stages
        on stage_changes.stage_id = stages.stage_id

)

select * from final
