-- Materialized as a view: one aggregation pass over ~15k deal changes and
-- ~4.6k activities is cheap at this volume. Switch to a table if it becomes
-- the base for a deal dimension that is queried heavily.
{{
    config(
        materialized = 'view'
    )
}}

with deal_changes as (

    select * from {{ ref('stg_deal_changes') }}

),

stage_history as (

    select * from {{ ref('int_deal_stage_history') }}

),

activity as (

    select * from {{ ref('stg_activity') }}

),

sales_calls as (

    select * from {{ ref('int_sales_calls') }}

),

fields as (

    select * from {{ ref('stg_fields') }}

),

-- there is no deals table, so the deal entity is every deal_id seen in either
-- source. Most activity deal_ids have no change history at all.
all_deals as (

    select deal_id from deal_changes
    union
    select deal_id from activity

),

creation as (

    -- five deal_ids carry two add_time events (two lifecycles); the first one
    -- is the creation date, lifecycle_count exposes the rest
    select
        deal_id                         as deal_id,
        min(changed_at)                 as created_at,
        count(*)                        as lifecycle_count
    from deal_changes
    where changed_field_key = 'add_time'
    group by deal_id

),

-- latest value of each tracked field, to describe the deal's current state
latest_values as (

    select
        deal_id                         as deal_id,
        changed_field_key               as changed_field_key,
        new_value                       as new_value,
        changed_at                      as changed_at,
        row_number() over (
            partition by deal_id, changed_field_key
            order by changed_at desc
        )                               as recency_rank
    from deal_changes
    where changed_field_key in ('user_id', 'stage_id', 'lost_reason')

),

current_state as (

    -- pivot the latest values into one row per deal
    select
        deal_id                                                                         as deal_id,
        max(case when changed_field_key = 'user_id' then cast(new_value as integer) end)   as owner_user_id,
        max(case when changed_field_key = 'stage_id' then cast(new_value as integer) end)  as current_stage_id,
        max(case when changed_field_key = 'lost_reason' then new_value end)                as lost_reason_id,
        max(case when changed_field_key = 'lost_reason' then changed_at end)               as lost_at
    from latest_values
    where recency_rank = 1
    group by deal_id

),

stage_summary as (

    select
        deal_id                                             as deal_id,
        max(stage_id)                                       as furthest_stage_id,
        max(entered_at)                                     as last_stage_changed_at,
        -- feeds the re-entry monitoring test
        count(*) filter (where stage_entry_number > 1)      as stage_reentry_count
    from stage_history
    group by deal_id

),

activity_summary as (

    select
        deal_id                         as deal_id,
        count(*)                        as activity_count
    from activity
    group by deal_id

),

sales_call_summary as (

    select
        deal_id                         as deal_id,
        count(*)                        as completed_sales_call_count
    from sales_calls
    group by deal_id

),

-- decode lost_reason ids into labels using the expanded field options
lost_reasons as (

    select
        option_id                       as lost_reason_id,
        option_label                    as lost_reason
    from fields
    where field_key = 'lost_reason'

),

final as (

    select
        all_deals.deal_id                                           as deal_id,
        -- false for deals known only from activities: no stage, owner or creation data
        creation.deal_id is not null                                as has_deal_history,
        creation.created_at                                         as created_at,
        coalesce(creation.lifecycle_count, 0)                       as lifecycle_count,
        current_state.owner_user_id                                 as owner_user_id,
        current_state.current_stage_id                              as current_stage_id,
        stage_summary.furthest_stage_id                             as furthest_stage_id,
        stage_summary.last_stage_changed_at                         as last_stage_changed_at,
        coalesce(stage_summary.stage_reentry_count, 0)              as stage_reentry_count,
        current_state.lost_reason_id                                as lost_reason_id,
        lost_reasons.lost_reason                                    as lost_reason,
        current_state.lost_at                                       as lost_at,
        coalesce(activity_summary.activity_count, 0)                as activity_count,
        coalesce(sales_call_summary.completed_sales_call_count, 0)  as completed_sales_call_count
    from all_deals
    left join creation
        on all_deals.deal_id = creation.deal_id
    left join current_state
        on all_deals.deal_id = current_state.deal_id
    left join stage_summary
        on all_deals.deal_id = stage_summary.deal_id
    left join activity_summary
        on all_deals.deal_id = activity_summary.deal_id
    left join sales_call_summary
        on all_deals.deal_id = sales_call_summary.deal_id
    left join lost_reasons
        on current_state.lost_reason_id = lost_reasons.lost_reason_id

)

select * from final
