# Architecture

## Overview

The NHL Pipeline follows a **medallion architecture** — a layered approach where data gets progressively cleaner and more structured as it moves through the pipeline. Raw CSV files from Kaggle enter at the bottom and emerge as business-ready tables powering a Power BI dashboard.

```
Raw CSV files (Kaggle)
        ↓
    Bronze Layer        ← raw, untouched data
        ↓
    Silver Layer        ← cleaned, typed, standardised
        ↓
    Gold Layer          ← business-ready tables
        ↓
    Power BI Dashboard  ← 5 decision pages
```

---

## Data Flow

### Step 1 — Extract (CSV → Parquet)
`ingestion/extract.py` reads all 6 raw CSV files using **Polars** and saves them as Parquet files in `data/raw/`. Parquet is a compressed, columnar format that loads significantly faster than CSV and handles the large `game_plays` file (5M rows) without memory issues.

**Key decision:** `game_plays.csv` is filtered to 5 event types (Goal, Shot, Missed Shot, Blocked Shot, Penalty) before saving — reducing ~5M rows to ~900K while retaining everything needed for the business questions.

### Step 2 — Load (Parquet → DuckDB)
`ingestion/load_duckdb.py` reads the Parquet files and loads them into **DuckDB** as raw Bronze tables. Every row is loaded as-is — no transformations at this stage. This preserves the original data for auditing and quality checks.

### Step 3 — Transform (dbt staging → marts)
**dbt** manages all SQL transformations in two layers:

- **Staging (Silver):** One model per source table. Renames columns to consistent naming conventions, casts data types, and adds derived columns (e.g. `has_coordinates` flag for the 41% finding).
- **Marts (Gold):** Business-logic models that answer the 5 business questions. Built on top of staging models.

### Step 4 — Serve (Power BI)
Power BI connects to DuckDB and reads from the Gold mart tables. The dashboard has 5 pages, one per business question.

---

## Medallion Layers

| Layer | Tables | Purpose |
|-------|--------|---------|
| Bronze | 6 raw tables | Immutable source data — never modified after load |
| Silver | 6 staging models | Cleaned, typed, renamed, with derived columns |
| Gold | 5 mart models | Analytical tables aligned to the 5 business questions |

---

## Data Quality Layer

Data quality runs across all three layers, owned by Role 5:

| Tool | Where it runs | What it checks |
|------|--------------|----------------|
| dbt tests | Silver + Gold | not_null, unique, accepted_values, relationships |
| Soda Core | Bronze + Silver | Row counts, null rates, freshness |
| GitHub Actions | Every PR | Runs dbt tests automatically before any merge |

**Headline finding:** 41.4% of GOAL events (61,740 of 148,992) are missing x/y rink coordinates. Only 0.34% of SHOT events are missing coordinates. This structural defect is surfaced — not hidden — at three independent quality layers.

---

## Source Dataset

6 CSV files from the [NHL Game Dataset (Kaggle / Martin Ellis)](https://www.kaggle.com/martinellis/nhl-game-data):

| File | Rows | Description |
|------|------|-------------|
| `game.csv` | ~23,000 | Game results and metadata |
| `game_teams_stats.csv` | ~46,000 | Per-game team statistics |
| `game_skater_stats.csv` | ~1.1M | Per-game individual skater stats |
| `game_goalie_stats.csv` | ~46,000 | Per-game goalie stats |
| `player_info.csv` | ~8,000 | Player metadata |
| `game_plays.csv` | ~900K (filtered) | Play-by-play events |

---

## Tool Decisions

| Tool | Role | Why chosen |
|------|------|-----------|
| Polars | Ingestion | Handles large files (5M rows) faster than pandas, less memory |
| DuckDB | Storage | Zero setup, runs locally, free, works natively with dbt and Parquet |
| dbt | Transformation | Version-controlled SQL, built-in testing, clear staging/mart separation |
| Soda Core | Data quality | YAML-based checks, easy to read and maintain |
| Power BI Web | Dashboard | Mac-compatible alternative to Power BI Desktop |
| GitHub Actions | CI/CD | Runs dbt tests automatically on every pull request |

---

## Key Design Decisions

**Why Parquet as an intermediate format?**
Converting CSVs to Parquet before loading into DuckDB gives better performance and allows the ingestion step to be re-run independently without re-running the full pipeline.

**Why filter `game_plays` early?**
The raw file has ~5M rows but most event types are not needed for the business questions. Filtering to 5 event types at ingestion keeps the database lean and fast.

**Why not fix the 41% NULL coordinates?**
The missing coordinates are a real data defect in the source. Filling them in would hide a genuine quality problem from the dashboard. Instead, we surface it explicitly so coaches and analysts know which records cannot be used for shot location analysis.
