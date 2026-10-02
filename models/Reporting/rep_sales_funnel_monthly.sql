-- Materialized as a table: this is the model BI tools and analysts query, so
-- the whole chain of views is computed once per dbt run instead of on
-- every read.
{{
    config(
        materialized = 'table'
    )
}}

with funnel_events as (

    select * from {{ ref('int_funnel_events') }}

),

funnel_mapping as (

    select * from {{ ref('funnel_step_mapping') }}

),

-- deals entering each funnel step per calendar month
monthly_counts as (

    select
        -- first day of the month, as a date
        cast(date_trunc('month', event_at) as date)     as month,
        funnel_step                                     as funnel_step,
        -- int_funnel_events is already one row per deal and step; distinct
        -- guards against double counting if that ever changes
        count(distinct deal_id)                         as deals_count
    from funnel_events
    group by 1, 2

),

month_bounds as (

    select
        min(month)                                      as first_month,
        max(month)                                      as last_month
    from monthly_counts

),

-- every month between the first and last event, so gaps are not skipped
month_spine as (

    select
        cast(series.month_start as date)                as month
    from month_bounds
    cross join lateral generate_series(
        month_bounds.first_month,
        month_bounds.last_month,
        interval '1 month'
    ) as series (month_start)

),

-- zero-fill: one row for every month and every funnel step, so a step with
-- no entries in a month shows 0 instead of a missing row
month_step_grid as (

    select
        month_spine.month                               as month,
        funnel_mapping.kpi_name                         as kpi_name,
        funnel_mapping.funnel_step                      as funnel_step
    from month_spine
    cross join funnel_mapping

),

final as (

    select
        month_step_grid.month                           as month,
        month_step_grid.kpi_name                        as kpi_name,
        month_step_grid.funnel_step                     as funnel_step,
        coalesce(monthly_counts.deals_count, 0)         as deals_count
    from month_step_grid
    left join monthly_counts
        on month_step_grid.month = monthly_counts.month
        and month_step_grid.funnel_step = monthly_counts.funnel_step

)

select * from final
