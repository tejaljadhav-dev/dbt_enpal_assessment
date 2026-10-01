with source as (

    select * from {{ source('pipedrive', 'activity_types') }}

),

renamed as (

    select
        id                      as activity_type_id,
        type                    as activity_type_key,
        name                    as activity_type_name,
        active = 'Yes'          as is_active
    from source

),

final as (

    select * from renamed

)

select * from final
