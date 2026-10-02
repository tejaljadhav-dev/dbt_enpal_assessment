-- Exploratory analysis 2: stage paths, repeated lifecycles and Lead Generation timing.
-- Findings: docs/exploratory_analysis.md (section 2, findings 2, 3, 4, 10).

with changes as (

    select * from {{ source('pipedrive', 'deal_changes') }}

),

-- five deal_ids carry two add_time events (two lifecycles)
multi_lifecycle_deals as (

    select deal_id
    from changes
    where changed_field_key = 'add_time'
    group by deal_id
    having count(*) > 1

),

stage_moves as (

    select
        deal_id,
        cast(new_value as integer)                          as stage_id,
        lag(cast(new_value as integer)) over (
            partition by deal_id
            order by change_time
        )                                                   as previous_stage_id
    from changes
    where changed_field_key = 'stage_id'

),

-- move types: first, next, skip_forward, same, backward.
-- Backward and same moves occur only inside multi_lifecycle_deals.
move_types as (

    select
        stage_moves.deal_id in (select deal_id from multi_lifecycle_deals) as in_multi_lifecycle_deal,
        case
            when previous_stage_id is null              then 'first'
            when stage_id = previous_stage_id + 1       then 'next'
            when stage_id > previous_stage_id + 1       then 'skip_forward'
            when stage_id = previous_stage_id           then 'same'
            else 'backward'
        end                                                 as move_type
    from stage_moves

),

-- Lead Generation: gap between deal creation and the move into stage 1
creation_vs_stage_1 as (

    select
        created.deal_id,
        extract(epoch from stage_1.entered_at - created.created_at) / 86400 as gap_days,
        date_trunc('month', created.created_at) <> date_trunc('month', stage_1.entered_at) as different_month
    from (
        select deal_id, min(change_time) as created_at
        from changes where changed_field_key = 'add_time' group by deal_id
    ) as created
    inner join (
        select deal_id, min(change_time) as entered_at
        from changes where changed_field_key = 'stage_id' and new_value = '1' group by deal_id
    ) as stage_1
        on created.deal_id = stage_1.deal_id

)

select
    'stage move types'                                      as check_name,
    move_type || ' (in multi-lifecycle deal: ' || in_multi_lifecycle_deal || ')' as detail,
    count(*)                                                as value
from move_types
group by move_type, in_multi_lifecycle_deal

union all

select 'creation to stage 1: deals', null, count(*) from creation_vs_stage_1
union all
select 'creation to stage 1: median gap (days)', null, round(percentile_cont(0.5) within group (order by gap_days)::numeric, 1) from creation_vs_stage_1
union all
select 'creation to stage 1: deals in a different month', null, count(*) filter (where different_month) from creation_vs_stage_1
