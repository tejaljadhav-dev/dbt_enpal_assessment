with source as (

    select * from {{ source('pipedrive', 'users') }}

),

renamed as (

    select
        id                      as user_id,
        name                    as user_name,
        email                   as email,
        modified                as modified_at
    from source

),

final as (

    select * from renamed

)

select * from final
