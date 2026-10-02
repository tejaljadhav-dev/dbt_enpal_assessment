{#-
    Reconciliation test: rebuilds the funnel straight from the raw tables with
    independent SQL (no staging or intermediate models) and compares it with
    rep_sales_funnel_monthly cell by cell. Returns every month + step where the
    two disagree, so the test passes only when the full model chain produces
    exactly what the business rules say it should: one entry per deal per step,
    dated at the first entry, completed sales calls only.
    Zero-filled report rows are excluded because the raw rebuild has no rows
    for months without entries.
-#}

with stage_first_entry as (

    select
        deal_id                         as deal_id,
        new_value                       as funnel_step,
        min(change_time)                as first_at
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'stage_id'
    group by deal_id, new_value

),

call_first_entry as (

    select
        deal_id                         as deal_id,
        case type when 'meeting' then '2.1' when 'sc_2' then '3.1' end as funnel_step,
        min(due_to)                     as first_at
    from {{ source('pipedrive', 'activity') }}
    where done
        and type in ('meeting', 'sc_2')
    group by deal_id, type

),

expected as (

    select
        cast(date_trunc('month', first_at) as date)     as month,
        funnel_step                                     as funnel_step,
        count(*)                                        as deals_count
    from (
        select * from stage_first_entry
        union all
        select * from call_first_entry
    ) as entries
    group by 1, 2

),

actual as (

    select
        month                           as month,
        funnel_step                     as funnel_step,
        deals_count                     as deals_count
    from {{ ref('rep_sales_funnel_monthly') }}
    where deals_count > 0

),

final as (

    select
        coalesce(expected.month, actual.month)                  as month,
        coalesce(expected.funnel_step, actual.funnel_step)      as funnel_step,
        expected.deals_count                                    as expected_deals_count,
        actual.deals_count                                      as actual_deals_count
    from expected
    full outer join actual
        on expected.month = actual.month
        and expected.funnel_step = actual.funnel_step
    where expected.deals_count is distinct from actual.deals_count

)

select * from final
