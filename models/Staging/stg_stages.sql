with source as (

    select * from {{ source('pipedrive', 'stages') }}

),

renamed as (

    select
        stage_id,
        stage_name
    from source

),

final as (

    select * from renamed

)

select * from final
