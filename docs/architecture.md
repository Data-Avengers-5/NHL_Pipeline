# Architecture

## Overview

The NHL Pipeline follows a **medallion architecture** — the industry-standard pattern for analytics pipelines. Raw CSV files from Kaggle enter at the bottom and emerge as business-ready tables powering a Power BI decision-support dashboard.

```
7 Raw CSV files (Kaggle)
        ↓
    Bronze Layer        ← raw, immutable data loaded as-is
        ↓
    Silver Layer        ← 7 staging views: deduped, cleaned, typed
        ↓
    Gold Layer          ← 3 dims + 2 facts + 5 marts (star schema)
        ↓
    Power BI Dashboard  ← 5 decision pages with quantified recommendations
```

---

## Data Flow

### Step 1 — Ingest (CSV → DuckDB Bronze)

`python/ingest.py` reads all 7 raw CSVs using **Polars** and loads them directly into DuckDB under the `raw` schema. Polars is 10–100× faster than pandas on this volume and integrates natively with DuckDB. No intermediate file format — CSVs flow straight into the database in one step.

Every row is loaded as-is. No transformations at this stage. This preserves the original data for auditing and downstream quality work.

### Step 2 — Stage (DuckDB Bronze → Silver)

`dbt staging` materialises 7 views, one per source table. Each view standardises column names to snake_case, casts data types, filters obviously invalid rows, and derives helper columns.

Three of the staging models (`stg_game_plays`, `stg_game_penalties`, `stg_game_skater_stats`) apply `QUALIFY ROW_NUMBER() OVER (PARTITION BY <pk> ORDER BY ...) = 1` to deduplicate rows discovered in the 2018–2019 raw data. Before this fix, goal-event counts for 2018 were roughly double what they should have been (33,000 vs 16,500 expected).

`stg_game_plays` filters to 6 event types — Goal, Shot, Missed Shot, Blocked Shot, Penalty, Takeaway — retaining everything needed for the business questions while reducing volume.

### Step 3 — Transform to Gold (Silver → dims + facts + marts)

dbt materialises the gold layer as a star schema:

- **3 dimensions** — `dim_game`, `dim_player`, `dim_team`
- **2 facts** — `fct_play` (2.2M rows, post-filter event ledger with derived shot zones), `fct_game_teams_stats` (52,610 rows)
- **5 marts** — one per business decision: `mart_player_season`, `mart_shot_zones`, `mart_penalty_cost`, `mart_venue_advtg`, `mart_team_traject`

Each mart is pre-aggregated to the grain its business question needs.

### Step 4 — Data Quality

Data quality is enforced through **dbt tests** at gold layer, plus source-side deduplication at the staging layer:

- `not_null` tests on 5 critical columns of `mart_penalty_cost`
- Source dedup via `QUALIFY ROW_NUMBER()` in three staging models
- Schema validation in `nhl_dbt/models/gold/schema.yml`

### Step 5 — Export and Serve

`python/export_marts.py` queries the 5 gold marts (joined with `dim_player` and `dim_team` for human-readable names) and writes CSVs to `data/exports/`. Two additional scripts produce supplementary analyses for Call 5:

- `python/export_rolling.py` — 3-year rolling win-rate per team plus trajectory classification (rising / falling / stable)
- `python/export_trajectory_change.py` — 2017→2019 trajectory delta table

The Power BI Desktop dashboard reads these CSVs and presents each business decision with a quantified recommendation.

---

## Medallion Layers

| Layer  | Artifacts                | Notes                                                          |
| ------ | ------------------------ | -------------------------------------------------------------- |
| Bronze | 7 raw tables (`raw.*`)   | Immutable source data, loaded as-is via Polars                 |
| Silver | 7 staging views          | Renamed, typed, deduped (where needed), derived columns added  |
| Gold   | 3 dims + 2 facts + 5 marts | Star schema; marts pre-aggregated for direct dashboard consumption |

---

## Source Dataset

7 CSV files from the [NHL Game Dataset (Kaggle / Martin Ellis)](https://www.kaggle.com/martinellis/nhl-game-data). Coverage: 2000–2020 · 19 seasons.

| File                    | Rows      | Description                                     | Powers         |
| ----------------------- | --------- | ----------------------------------------------- | -------------- |
| `game.csv`              | 23,735    | Game results and metadata                       | All decisions  |
| `game_teams_stats.csv`  | 52,610    | Per-game team statistics                        | Decisions 4, 5 |
| `game_skater_stats.csv` | 945,830   | Per-game individual skater stats                | Decision 1     |
| `player_info.csv`       | 3,925     | Player metadata                                 | All decisions  |
| `game_plays.csv`        | 5,050,529 | Play-by-play events (filtered to 6 event types) | Decisions 2, 3 |
| `game_penalties.csv`    | 247,828   | One row per penalty event                       | Decision 3     |
| `team_info.csv`         | 33        | Team metadata                                   | All decisions  |

---

## Headline Finding

**46.3% of GOAL events (61,737 of 133,345) are missing x/y rink coordinates.** SHOT events are only 0.34% missing.

Root cause: the NHL began tracking play-level coordinates in the 2007–08 season. Pre-2010 records are 100% missing for both shots and goals; post-2010 records are <0.15% missing. The defect is an era boundary, not random noise.

**Pipeline response:** rather than imputing missing coordinates and hiding the gap, `mart_shot_zones` is scoped to 2010+ only. The full analysis lives in `findings.md`.

---

## Tool Decisions

| Tool             | Role           | Why chosen                                                                |
| ---------------- | -------------- | ------------------------------------------------------------------------- |
| Polars           | Ingestion      | 10–100× faster than pandas on 5M rows; native DuckDB integration         |
| DuckDB           | Storage        | Zero setup, runs locally, ANSI SQL (ports to Snowflake/BigQuery)         |
| dbt-duckdb       | Transformation | Version-controlled SQL, built-in testing, automatic `ref()` lineage     |
| dbt tests        | Data quality   | Integrated into the build; fail-fast on regressions                       |
| GitHub Actions   | CI/CD          | Free for public repos; runs `dbt compile` on every PR                     |
| Power BI Desktop | Dashboard      | Reads CSV exports; meets bootcamp brief                                   |

All tools are free, open-source (or free tier), and Python-native. No vendor lock-in. No licensing fees.

### Considered but Not Implemented

The following tools were evaluated or scaffolded but not executed within the project timeline:

- **Soda Core** — YAML checks designed for 7 staging tables (row counts, completeness, uniqueness, validity) and committed to `soda/checks.yml`. Execution deferred to a future iteration; dbt tests cover the critical-path validations for the current scope.
- **Elementary** — evaluated for dbt-native observability; not implemented in this iteration.
- **Ruff / SQLFluff / pre-commit hooks** — evaluated as part of the linting strategy; not adopted in this iteration.

---

## Key Design Decisions

**Why direct CSV → DuckDB instead of an intermediate Parquet step?** Polars reads CSVs into DuckDB efficiently in one operation; an intermediate Parquet stage would add filesystem I/O without meaningful gain at this volume. Adding Parquet would make sense if the bronze data needed to be shared across multiple downstream systems or persisted as immutable history outside DuckDB.

**Why filter `game_plays` early?** The raw file has 5M rows but only 6 event types are needed for the business questions. Filtering at the staging layer (rather than carrying all rows through to gold) keeps every downstream model lean and reduces gold-build time.

**Why separate `game_penalties` as its own source table?** Penalty events need their own grain — one row per penalty, with period and severity — to answer Decision 3 cleanly. Keeping it separate avoids inflating `fct_play` and lets `mart_penalty_cost` aggregate cleanly without redundant joins.

**Why scope `mart_shot_zones` to 2010+ rather than imputing missing coordinates?** The missing coordinates are a real era-boundary defect in the source, not random noise. Imputing them would manufacture data that didn't exist. Scoping the mart to the post-tracking era surfaces the limitation honestly while preserving 100% of the analytically useful rows.

**Why the deduplication in staging?** Three raw tables (`game_plays`, `game_penalties`, `game_skater_stats`) contain duplicate rows in the 2018–2019 seasons. Resolving this at the staging layer with `QUALIFY ROW_NUMBER()` means every downstream model sees clean data without needing dedup logic of its own.

**Why a mart per business decision?** Each mart is pre-aggregated to the grain its decision needs, so dashboard queries are fast and the SQL behind each call is auditable in isolation. The shared dims and facts preserve full lineage back to the source.