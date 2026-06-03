# Architecture

## Overview

The NHL Pipeline follows a **medallion architecture** — the industry-standard pattern for production data pipelines. Raw CSV files from Kaggle enter at the bottom and emerge as business-ready tables powering a decision-support dashboard.

```
7 Raw CSV files (Kaggle)
        ↓
    Bronze Layer        ← raw, immutable data loaded as-is
        ↓
    Silver Layer        ← 7 staging views: cleaned, typed, standardised
        ↓
    Dims + fact_play    ← 4 conformed dims + silver fact (5M rows)
        ↓
    Gold Layer          ← 5 marts, one per business decision
        ↓
    Dashboard           ← 5 decision pages with quantified recommendations
```

---

## Data Flow

### Step 1 — Extract (CSV → Parquet)
`ingestion/extract.py` reads all 7 raw CSV files using **Polars** and saves them as Parquet files in `data/raw/`. Parquet is a compressed, columnar format that loads significantly faster than CSV and handles the large `game_plays` file (5M rows) without memory issues.

**Key decision:** `game_plays.csv` is filtered to 5 event types (Goal, Shot, Missed Shot, Blocked Shot, Penalty) before saving — reducing ~5M rows while retaining everything needed for the business questions.

### Step 2 — Load (Parquet → DuckDB Bronze)
`ingestion/load_duckdb.py` reads the Parquet files and loads them into **DuckDB** as raw Bronze tables. Every row is loaded as-is — no transformations at this stage. This preserves the original data for auditing and quality checks.

### Step 3 — Transform (dbt staging → dims → marts)
**dbt** manages all SQL transformations in three layers:

- **Staging (Silver):** One view per source table. Renames columns to snake_case, casts data types, and adds derived columns (e.g. `has_coordinates` flag for the 41% finding). 7 staging models total.
- **Dims + Silver Fact:** 4 conformed dimension tables (dim_player, dim_team, dim_game, dim_date) + 1 ephemeral `fact_play` with derived shot_zone and score_state columns.
- **Gold Marts:** 5 pre-aggregated tables aligned to the grain each business decision needs. One mart per call.

### Step 4 — Quality Gates
Data quality runs at every layer, owned by Role 5:
- **dbt tests** on every staging model and mart
- **Soda Core** scans on Bronze and Silver layers
- **Elementary** observability — DQ scores per model, lineage, run history
- **GitHub Actions** — full dbt build + tests on every PR before merge

### Step 5 — Serve (Dashboard)
The dashboard reads from the 5 Gold mart tables and presents each business decision with a quantified recommendation.

---

## Medallion Layers

| Layer | Tables | Rows | Purpose |
|-------|--------|------|---------|
| Bronze | 7 raw tables | As-is from source | Immutable source data — never modified after load |
| Silver | 7 staging views | Cleaned | Typed, renamed, derived columns added |
| Intermediate | fact_play (ephemeral) | 5,050,529 | Canonical event ledger with shot_zone + score_state |
| Dims | 4 dimension tables | Varies | Conformed dimensions used by all 5 marts |
| Gold | 5 mart tables | Pre-aggregated | Decision-ready, one per business call |

---

## Source Dataset

7 CSV files from the [NHL Game Dataset (Kaggle / Martin Ellis)](https://www.kaggle.com/martinellis/nhl-game-data).
Coverage: 2000–2020 · 19 seasons.

| File | Rows | Description | Powers |
|------|------|-------------|--------|
| `game.csv` | 23,735 | Game results and metadata | All decisions |
| `game_teams_stats.csv` | 52,610 | Per-game team statistics | Decisions 4, 5 |
| `game_skater_stats.csv` | 945,830 | Per-game individual skater stats | Decision 1 |
| `game_goalie_stats.csv` | ~46,000 | Per-game goalie stats | Supporting |
| `player_info.csv` | 3,925 | Player metadata | All decisions |
| `game_plays.csv` | 5,050,529 | Play-by-play events (filtered to 5 event types) | Decisions 2, 3 |
| `game_penalties.csv` | 247,828 | One row per penalty event | Decision 3 |

---

## Data Quality Layer

| Tool | Where it runs | What it checks |
|------|--------------|----------------|
| dbt tests | Silver + Gold | not_null, unique, accepted_values, relationships |
| Soda Core | Bronze + Silver | Row counts, null rates, value ranges |
| Elementary | All layers | Observability — DQ scores, lineage, run history |
| GitHub Actions | Every PR | Full dbt build + tests before any merge |

**Headline finding:** 41.4% of GOAL events (61,740 of 148,992) are missing x/y rink coordinates. SHOT events are only 0.34% missing. This structural defect is surfaced — not hidden — at three independent quality layers.

---

## Tool Decisions

| Tool | Role | Why chosen |
|------|------|-----------|
| Polars | Ingestion | 10-100× faster than pandas on 5M rows; native DuckDB integration |
| DuckDB | Storage | Zero setup, free, runs locally, ANSI SQL (ports to Snowflake/BigQuery) |
| dbt | Transformation | Version-controlled SQL, built-in testing, ref() lineage automatic |
| Soda Core | Data quality | YAML-based checks, easy to read and maintain |
| Elementary | Observability | dbt-native, no separate infrastructure needed |
| Ruff + SQLFluff | Linting | Modern, fast, pre-commit hooks |
| GitHub Actions | CI/CD | Free for public repos, standard dbt CI patterns |
| Power BI Web | Dashboard | Mac-compatible, meets bootcamp brief requirement |

*All tools are free, open-source, Python-native, and 2026-current. No vendor lock-in. No licensing fees.*

---

## Key Design Decisions

**Why Parquet as an intermediate format?**
Converting CSVs to Parquet before loading into DuckDB gives better performance and allows the ingestion step to be re-run independently without re-running the full pipeline.

**Why filter `game_plays` early?**
The raw file has 5M rows but most event types are not needed for the business questions. Filtering to 5 event types at ingestion keeps the database lean and fast.

**Why separate `game_penalties` as its own table?**
Penalty events need their own grain (one row per penalty, with period and severity) to answer Business Decision 3 (penalty cost analysis) cleanly. Keeping it separate avoids inflating `game_plays`.

**Why not fix the 41% NULL coordinates?**
The missing coordinates are a real data defect in the source. Filling them in would hide a genuine quality problem. Instead, we surface it explicitly with a `has_coordinates` flag so analysts know which records cannot be used for shot location analysis.

**Why Option B (Hybrid Multi-Mart) architecture?**
Each business decision gets its own pre-aggregated mart for fast queries. One detailed silver `fact_play` preserves full lineage. This is the dbt-native pattern — clean separation between event-level detail and decision-level aggregation.
