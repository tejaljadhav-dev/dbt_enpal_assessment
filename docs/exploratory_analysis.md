# Exploratory analysis: findings and decisions

Every number below was measured directly on the raw tables in the `public` schema before any model was written.

## 1. What each source is

| Table | Rows | Grain | Key | Notes |
|---|---|---|---|---|
| `deal_changes` | 15,406 | one row per (deal, time, field) | none; the combination is unique | 1,995 deals; tracks only 4 fields |
| `activity` | 4,579 | one row per activity | `activity_id` is **not** unique | 4,572 distinct deal_ids |
| `activity_types` | 4 | one row per type | `id`, `type` | joins to `activity.type` |
| `stages` | 9 | one row per stage | `stage_id` | single pipeline |
| `users` | 1,787 | one row per user | `id` | emails are not unique (4 duplicates) |
| `fields` | 4 | one row per deal field | `id`, `field_key` | metadata for `deal_changes`, with JSON option lists |

There is no deals table. A deal exists only as a `deal_id` in `deal_changes` or `activity`.

## 2. Findings

1. **`fields` describes `deal_changes`.** Its 4 rows (`add_time`, `user_id`, `stage_id`, `lost_reason`) are exactly the 4 values of `changed_field_key`. Its option lists decode `stage_id` and `lost_reason` values. All fields belong to the deal entity.
2. **Stage history.** Every deal's first stage is 1. 2,502 moves skip stages (e.g. 4 → 6). Stage entries per month run from January 2024 to February 2025.
3. **Five deal_ids hold two lifecycles.** Each has two `add_time` events and two interleaved stage histories. They account for every backward move (8), every repeated stage (2 consecutive, 15 overall).
4. **`lost_reason` is on every deal** (1,995 of 1,995), always after the deal's last stage change, even for the 324 that reached stage 9. It cannot be used as a status.
5. **`activity_id` is reused:** 4,579 rows but 4,568 distinct ids. The 11 reused ids belong to unrelated rows (different type, user and deal).
6. **Activities barely link to deals.** Only 8 of 4,572 activity deal_ids appear in `deal_changes`.
7. **The sales calls are named in the data.** `meeting` = "Sales Call 1" and `sc_2` = "Sales Call 2". The other two types (`follow_up`, `after_close_call`) are not funnel steps. Each deal has at most one activity per type except one.
8. **Activity timestamps.** The only one is `due_to`. There is no completion time, and activities span January to September 2024 while stage changes run to February 2025.
9. **Stage names match the funnel** except one spelling: Pipedrive has "Qualified lead", the brief says "Qualified Lead".
10. **Lead Generation timing.** `add_time` precedes the move into stage 1 by 2 to 83 days (median 35), so 1,732 of 1,995 deals (87%) land in a different month depending on which date is used. Totals are identical.
11. **Referential integrity is clean.** Every activity user and every `user_id` change exists in `users`; every activity type exists in `activity_types`.

## 3. Decisions

| Decision | Reasoning |
|---|---|
| Steps 1 to 9 come from the deal entering `stage_id` 1 to 9 | The stages already match the funnel (finding 9). |
| Steps 2.1 and 3.1 come from completed `meeting` / `sc_2` activities | The only place calls exist (finding 7). |
| Mapping stored in a seed (`funnel_step_mapping`) | One visible, tested place to change business rules. |
| A deal counts once per step, at its first entry | Keeps the funnel simple; only 5 deals re-enter (finding 3). A warn-only test monitors this. |
| Only completed calls count | A call that did not happen is not a funnel step. |
| Skipped stages are not filled in | The data says the deal never entered them. |
| Lead Generation uses the stage 1 change | One event definition for all stage steps; totals unchanged (finding 10). |
| `lost_reason` ignored for the funnel | Present on every deal (finding 4). |
| Calls are not tied to stage history | Almost no overlap (finding 6). |
| Surrogate keys for `deal_changes`, `activity` and field options | The source has no key, or a non-unique one (finding 5). Hashed deterministically in a small macro instead of adding `dbt_utils`. |
| `int_deals` built from both sources | The deal entity does not exist as a table (finding 1 of section 1). |
| Report zero-filled | Charts and month-over-month comparisons need every month. Sales Call zeros after September 2024 reflect missing data (finding 8). |
| No `unique` on `activity_id` or `email`, no relationship from activities to deals | The data does not support them (findings 5 and 6). |
| Dimensions kept light, no forced star schema | The report does not depend on them. |

## 4. Known limitations

- Sales call dates are due dates, not completion dates.
- Sales Call 1 / 2 cannot be shown for October 2024 onwards.
- 4,564 deals appear only in `activity` and have no stage or owner information.
- If the business wants "new leads created per month", Lead Generation should switch to `add_time`; this is a one-line change in `int_funnel_events`.
