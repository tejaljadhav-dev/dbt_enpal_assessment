-- Exploratory analysis 3: how activities relate to deals, types and time.
-- Findings: docs/exploratory_analysis.md (section 2, findings 6, 7, 8).

with activity as (

    select * from {{ source('pipedrive', 'activity') }}

),

deals_with_history as (

    select distinct deal_id
    from {{ source('pipedrive', 'deal_changes') }}

)

-- how many activity deals have stage history at all (expected: 8 of ~4.6k)
select
    'activity deal_ids'                                     as check_name,
    null                                                    as detail,
    count(distinct activity.deal_id)                        as value
from activity

union all

select
    'activity deal_ids also in deal_changes',
    null,
    count(distinct activity.deal_id)
from activity
inner join deals_with_history
    on activity.deal_id = deals_with_history.deal_id

union all

-- activity types and completion: the sales calls are meeting and sc_2
select
    'activities by type / done',
    activity.type || ' / done=' || activity.done,
    count(*)
from activity
group by activity.type, activity.done

union all

-- activities end in September 2024, stage changes run to February 2025
select
    'latest activity due_to',
    cast(max(activity.due_to) as varchar),
    null
from activity
