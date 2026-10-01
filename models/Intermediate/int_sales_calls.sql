with activity as (

    select * from {{ ref('stg_activity') }}

),

activity_types as (

    select * from {{ ref('stg_activity_types') }}

),

funnel_mapping as (

    select * from {{ ref('funnel_step_mapping') }}

),

-- which activity types count as sales calls comes from the mapping seed,
-- not hardcoded here (currently meeting and sc_2)
sales_call_types as (

    select
        source_key                      as activity_type_key
    from funnel_mapping
    where source_type = 'activity'

),

final as (

    select
        activity.activity_key               as activity_key,
        activity.activity_id                as activity_id,
        activity.deal_id                    as deal_id,
        activity.user_id                    as user_id,
        activity.activity_type_key          as activity_type_key,
        activity_types.activity_type_name   as activity_type_name,
        -- due date is the best available call date (no completion time in source)
        activity.due_at                     as called_at
    from activity
    inner join sales_call_types
        on activity.activity_type_key = sales_call_types.activity_type_key
    left join activity_types
        on activity.activity_type_key = activity_types.activity_type_key
    -- a scheduled call that never happened is not a funnel entry
    where activity.is_done

)

select * from final
