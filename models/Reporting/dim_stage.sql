-- Materialized as a table: dimensions are read by BI tools alongside the
-- report, so they are stored rather than recomputed on every query.
{{
    config(
        materialized = 'table'
    )
}}

------ Start: Import CTEs ------
with stages as (

    select * from {{ ref('stg_stages') }}

),

funnel_mapping as (

    select * from {{ ref('funnel_step_mapping') }}

),

------ End: Import CTEs ------

------ Start: Logic CTEs ------

stage_steps as (

    select
        source_key                      as source_key,
        funnel_step                     as funnel_step,
        kpi_name                        as kpi_name
    from funnel_mapping
    where source_type = 'stage'

),

final as (

    select
        stages.stage_id                 as stage_id,
        -- Pipedrive spelling, e.g. "Qualified lead"
        stages.stage_name               as stage_name,
        stage_steps.funnel_step         as funnel_step,
        -- reporting spelling, e.g. "Qualified Lead"
        stage_steps.kpi_name            as kpi_name
    from stages
    left join stage_steps
        -- source_key is text because it also holds activity type keys
        on cast(stages.stage_id as varchar) = stage_steps.source_key

)
------ End: Logic CTEs ------

------ Start: Final CTE ------

select * from final
