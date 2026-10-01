with source as (

    select * from {{ source('pipedrive', 'deal_changes') }}

)

select
    {{ generate_surrogate_key(['deal_id', 'change_time', 'changed_field_key']) }} as deal_change_id,
    deal_id,
    change_time as changed_at,
    changed_field_key,
    new_value
from source
