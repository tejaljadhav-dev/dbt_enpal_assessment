with source as (

    select * from {{ source('pipedrive', 'fields') }}

),

renamed as (

    select
        id as field_id,
        field_key,
        name as field_name,
        field_value_options
    from source

),

final as (

    select * from renamed

)

select * from final
