with source as (

    select * from {{ source('pipedrive', 'deal_changes') }}

),

renamed as (

    select
        {{ generate_surrogate_key(['deal_id', 'change_time', 'changed_field_key']) }} as deal_change_id,
        deal_id                 as deal_id,
        change_time             as changed_at,
        changed_field_key       as changed_field_key,
        new_value               as new_value
    from source

),

final as (

    select * from renamed

)

select * from final
