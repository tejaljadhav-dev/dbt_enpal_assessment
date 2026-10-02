{#-
    Monitoring test: returns one row per deal that entered a stage it had
    already been in. The funnel counts only a deal's first entry into each
    step, which is a safe simplification while re-entries are rare: the
    current extract has 5 such deals (all deal_ids carrying two lifecycles).
    Warns, without failing the build, if that number grows past the baseline,
    which would mean the first-entry rule starts hiding real activity.
-#}
{{
    config(
        severity = 'warn',
        warn_if = '>5'
    )
}}

with deals as (

    select * from {{ ref('int_deals') }}

),

final as (

    select
        deal_id                         as deal_id,
        stage_reentry_count             as stage_reentry_count
    from deals
    where stage_reentry_count > 0

)

select * from final
