-- Exploratory analysis 1: grain, keys and duplicates of the raw tables.
-- Run with `dbt compile -s profile_source_grain` and execute the compiled SQL.
-- Findings: docs/exploratory_analysis.md (section 2, findings 1, 3, 5, 11).

-- deal_changes: unique on (deal, time, field)? expected: rows = distinct keys
select
    'deal_changes'                                          as source_table,
    count(*)                                                as row_count,
    count(distinct (deal_id, change_time, changed_field_key)) as distinct_keys,
    count(distinct deal_id)                                 as distinct_deals
from {{ source('pipedrive', 'deal_changes') }}

union all

-- activity: activity_id is NOT unique (11 reused ids), so rows > distinct ids
select
    'activity',
    count(*),
    count(distinct activity_id),
    count(distinct deal_id)
from {{ source('pipedrive', 'activity') }}

union all

-- users: id is unique; emails are not
select
    'users',
    count(*),
    count(distinct id),
    count(distinct email)
from {{ source('pipedrive', 'users') }}
