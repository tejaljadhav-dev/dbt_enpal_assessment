-- Materialized as a table: dimensions are read by BI tools alongside the
-- report, so they are stored rather than recomputed on every query.
{{
    config(
        materialized = 'table'
    )
}}

------ Start: Import CTEs ------
with activity_types as (

    select * from {{ ref('stg_activity_types') }}

),

funnel_mapping as (

    select * from {{ ref('funnel_step_mapping') }}

),

------ End: Import CTEs ------

------ Start: Logic CTEs ------

activity_steps as (

    select
        source_key                      as source_key,
        funnel_step                     as funnel_step,
        kpi_name                        as kpi_name
    from funnel_mapping
    where source_type = 'activity'

),

final as (

    select
        activity_types.activity_type_id             as activity_type_id,
        activity_types.activity_type_key            as activity_type_key,
        activity_types.activity_type_name           as activity_type_name,
        activity_types.is_active                    as is_active,
        -- sales calls are exactly the activity types mapped to a funnel step
        activity_steps.funnel_step is not null      as is_sales_call,
        activity_steps.funnel_step                  as funnel_step,
        activity_steps.kpi_name                     as kpi_name
    from activity_types
    left join activity_steps
        on activity_types.activity_type_key = activity_steps.source_key

)
------ End: Logic CTEs ------

------ Start: Final CTE ------

select * from final
