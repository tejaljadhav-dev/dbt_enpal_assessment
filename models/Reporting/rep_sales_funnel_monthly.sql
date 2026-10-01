select
    cast(date_trunc('month', event_at) as date) as month,
    kpi_name,
    funnel_step,
    count(distinct deal_id) as deals_count
from {{ ref('int_funnel_events') }}
group by 1, 2, 3
