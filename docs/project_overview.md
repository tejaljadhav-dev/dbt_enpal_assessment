# Project overview: Pipedrive sales funnel (dbt)

dbt project that turns a Pipedrive CRM extract into `rep_sales_funnel_monthly`: the number of deals that entered each funnel step per month.

Output columns: `month`, `kpi_name`, `funnel_step`, `deals_count`.

Findings and decisions are in [exploratory_analysis.md](exploratory_analysis.md). Model-level documentation (grain, columns, assumptions) is in the YAML file next to each model.

## Run it

1. Start the local Postgres with the raw data (needs Docker): `docker compose up -d`
2. Install `dbt-core` and `dbt-postgres` (validated on dbt-core 1.10.23 / dbt-postgres 1.9.1).
3. From the repo root: `dbt build --profiles-dir .`

Connection (see `profiles.yml`): `localhost:5432`, database `postgres`, user and password `admin`. Models are built into the `public_pipedrive_analytics` schema.

## Project structure

```
raw_data/             source CSVs, loaded into Postgres by docker-compose
seeds/                funnel_step_mapping.csv: stages / activity types -> funnel steps
macros/               generate_surrogate_key (deterministic md5 key)
tests/generic/        unique_combination_of_columns, not_negative
tests/                monitor_deal_stage_reentries (warn-only)
models/
  Staging/            views, one per raw table: rename, type, key (+ _sources.yml)
  Intermediate/       views, business logic
  Reporting/          tables, what BI reads
docs/                 project overview, exploratory analysis findings and decisions
```

## Lineage

```
raw CSVs (public schema)
  -> Staging       stg_deal_changes, stg_activity, stg_activity_types,
                   stg_stages, stg_users, stg_fields
  -> Intermediate  int_deal_stage_history, int_sales_calls, int_deals,
                   int_funnel_events   (+ seed funnel_step_mapping)
  -> Reporting     rep_sales_funnel_monthly, dim_stage,
                   dim_activity_type, dim_user
```

| Model | Grain |
|---|---|
| `stg_deal_changes` | one row per deal field change |
| `stg_activity` | one row per activity row |
| `stg_fields` | one row per field option |
| `int_deal_stage_history` | one row per deal entering a stage |
| `int_sales_calls` | one row per completed sales call |
| `int_deals` | one row per deal_id seen in either source |
| `int_funnel_events` | one row per deal per funnel step (first entry) |
| `rep_sales_funnel_monthly` | one row per month and funnel step |

## Funnel mapping

| Step | KPI | Source |
|---|---|---|
| 1 | Lead Generation | deal enters stage 1 |
| 2 | Qualified Lead | stage 2 |
| 2.1 | Sales Call 1 | completed `meeting` activity |
| 3 | Needs Assessment | stage 3 |
| 3.1 | Sales Call 2 | completed `sc_2` activity |
| 4 to 9 | Proposal/Quote Preparation, Negotiation, Closing, Implementation/Onboarding, Follow-up/Customer Success, Renewal/Expansion | stages 4 to 9 |

## Conventions

- Every model: import CTEs, then logic CTEs, then `final`, ending with `select * from final`.
- Every model starts with a `config()` block and a comment explaining its materialization.
- Explicit, aligned `as` aliases on every column.
- Tests guard results rather than every column: grain, inputs that drive counts, values read from raw text, and the seed. Each column is tested once, in staging.
