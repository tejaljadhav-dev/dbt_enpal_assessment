with source as (

    select * from {{ source('pipedrive', 'activity') }}

)

select
    -- activity_id is reused by unrelated rows in the source, so the row key
    -- also includes the deal and type
    {{ generate_surrogate_key(['activity_id', 'deal_id', 'type']) }} as activity_key,
    activity_id,
    deal_id,
    type as activity_type_key,
    assigned_to_user as user_id,
    done as is_done,
    due_to as due_at
from source
