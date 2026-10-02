-- Materialized as a table: dimensions are read by BI tools alongside the
-- report, so they are stored rather than recomputed on every query.
{{
    config(
        materialized = 'table'
    )
}}

------ Start: Import CTEs ------
with users as (

    select * from {{ ref('stg_users') }}

),

deals as (

    select * from {{ ref('int_deals') }}

),

------ End: Import CTEs ------

------ Start: Logic CTEs ------

-- how many deals each user currently owns, for workload / ownership slicing
owned_deals as (

    select
        owner_user_id                   as user_id,
        count(*)                        as owned_deal_count
    from deals
    where owner_user_id is not null
    group by owner_user_id

),

final as (

    select
        users.user_id                                   as user_id,
        users.user_name                                 as user_name,
        -- not unique across users, so not usable as a key
        users.email                                     as email,
        users.modified_at                               as modified_at,
        coalesce(owned_deals.owned_deal_count, 0)       as owned_deal_count
    from users
    left join owned_deals
        on users.user_id = owned_deals.user_id

)
------ End: Logic CTEs ------

------ Start: Final CTE ------

select * from final
