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

    select * from {{ source('pipedrive', 'deal_changes') }}

),

------ End: Import CTEs ------

------ Start: Logic CTEs ------

renamed as (

    select
        -- the source has no id; deal + time + field is unique, so hash it into one key
        {{ generate_surrogate_key(['deal_id', 'change_time', 'changed_field_key']) }} as deal_change_id,
        deal_id                 as deal_id,
        change_time             as changed_at,
        changed_field_key       as changed_field_key,
        -- changed_field_key: kept as text: holds a timestamp, user id, stage id or lost-reason id
        -- depending on changed_field_key, so downstream models cast it per key
        new_value               as new_value
    from source

),

final as (

    select * from renamed

)
------ End: Logic CTEs ------

------ Start: Final CTE ------

select * from final
