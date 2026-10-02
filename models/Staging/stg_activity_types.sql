-- Materialized as a view: staging only renames and lightly cleans one raw
-- table, so a view stays in sync with the latest load without duplicating
-- the data. Volumes are small (at most ~15k rows), so querying it is cheap.
{{
    config(
        materialized = 'view'
    )
}}

------ Start: Import CTEs ------
with source as (

    select * from {{ source('pipedrive', 'activity_types') }}

),

------ End: Import CTEs ------

------ Start: Logic CTEs ------

renamed as (

    select
        id                      as activity_type_id,
        -- join key to activity.type (e.g. meeting = "Sales Call 1", sc_2 = "Sales Call 2")
        type                    as activity_type_key,
        name                    as activity_type_name,
        -- source stores 'Yes' / 'No' as text
        active = 'Yes'          as is_active
    from source

),

final as (

    select * from renamed

)
------ End: Logic CTEs ------

------ Start: Final CTE ------

select * from final
