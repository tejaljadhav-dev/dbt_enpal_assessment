with funnel_events as (

    select * from {{ ref('int_funnel_events') }}

),

-- deals entering each funnel step per calendar month. Months where no deal
-- entered a step have no row (no zero-filling).
monthly as (

    select
        -- first day of the month, as a date
        cast(date_trunc('month', event_at) as date)     as month,
        kpi_name                                        as kpi_name,
        funnel_step                                     as funnel_step,
        -- int_funnel_events is already one row per deal and step; distinct
        -- guards against double counting if that ever changes
        count(distinct deal_id)                         as deals_count
    from funnel_events
    group by 1, 2, 3

),

final as (

    select * from monthly

)

select * from final
