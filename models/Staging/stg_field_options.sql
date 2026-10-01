with fields as (

    select * from {{ source('pipedrive', 'fields') }}
    where field_value_options is not null

),

options as (

    select
        fields.id as field_id,
        fields.field_key,
        option ->> 'id' as option_id,
        option ->> 'label' as option_label
    from fields
    cross join lateral jsonb_array_elements(fields.field_value_options) as option

)

select
    -- option ids restart at 1 for every field, so the key includes field_key
    {{ generate_surrogate_key(['field_key', 'option_id']) }} as field_option_id,
    field_id,
    field_key,
    option_id,
    option_label
from options
