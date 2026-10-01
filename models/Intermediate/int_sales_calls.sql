with sales_call_types as (

    select source_key as activity_type_key
    from {{ ref('funnel_step_mapping') }}
    where source_type = 'activity'

)

select
    activity.activity_key,
    activity.activity_id,
    activity.deal_id,
    activity.user_id,
    activity.activity_type_key,
    activity_types.activity_type_name,
    activity.due_at as called_at
from {{ ref('stg_activity') }} as activity
inner join sales_call_types
    on activity.activity_type_key = sales_call_types.activity_type_key
left join {{ ref('stg_activity_types') }} as activity_types
    on activity.activity_type_key = activity_types.activity_type_key
-- a scheduled call that never happened is not a funnel entry
where activity.is_done
