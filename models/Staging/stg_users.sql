-- Materialized as a view: staging only renames and lightly cleans one raw
-- table, so a view stays in sync with the latest load without duplicating
-- the data. Volumes are small (at most ~15k rows), so querying it is cheap.
{{
    config(
        materialized = 'view'
    )
}}

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
