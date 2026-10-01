with funnel_events as (

    select * from {{ ref('int_funnel_events') }}

),

monthly as (

    select
        cast(date_trunc('month', event_at) as date)     as month,
        kpi_name                                        as kpi_name,
        funnel_step                                     as funnel_step,
        count(distinct deal_id)                         as deals_count
    from funnel_events
    group by 1, 2, 3

),

final as (

    select * from monthly

)

select * from final
