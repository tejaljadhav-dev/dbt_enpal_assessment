-- Materialized as a view: staging only renames and lightly cleans one raw
-- table, so a view stays in sync with the latest load without duplicating
-- the data. Volumes are small (at most ~15k rows), so querying it is cheap.
{{
    config(
        materialized = 'view'
    )
}}

with source as (

    select * from {{ source('pipedrive', 'activity') }}

),

renamed as (

    select
        -- activity_id is reused by unrelated rows in the source, so the row key
        -- also includes the deal and type
        {{ generate_surrogate_key(['activity_id', 'deal_id', 'type']) }} as activity_key,
        activity_id             as activity_id,
        deal_id                 as deal_id,
        type                    as activity_type_key,
        assigned_to_user        as user_id,
        done                    as is_done,
        -- the only activity timestamp in the source; there is no completion time
        due_to                  as due_at
    from source

),

final as (

    select * from renamed

)

select * from final
