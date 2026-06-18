# NHL Pipeline 🏒

**JDE Final Project — Data Avengers 5**
The data pipeline that runs a hockey franchise. Five calls. Five million-dollar decisions. One pipeline.

---

## What This Project Does

We built a decision engine on 19 years of NHL game data that answers 5 commercial questions a General Manager would actually face — each backed by descriptive analytics and a quantified recommendation.

The pipeline ingests 7 raw CSV files, transforms them through a star schema in DuckDB managed by dbt, and surfaces findings in a Power BI dashboard. Along the way it uncovered the headline finding: **46.3% of all NHL goal records are missing coordinate data** — a structural defect undetected across 19 years of public data.

---

## The 5 Business Decisions

| # | The Call        | The Question                                                              | The Mart              |
| - | --------------- | ------------------------------------------------------------------------- | --------------------- |
| 1 | **The Trade**   | Which undervalued players deliver the most impact per minute of ice time? | `mart_player_season`  |
| 2 | **The Drill**   | Which shot zones convert best — where should teams drill?                 | `mart_shot_zones`     |
| 3 | **The Penalty** | When do penalties actually cost games?                                    | `mart_penalty_cost`   |
| 4 | **The Arena**   | Where is home-ice advantage largest and smallest?                         | `mart_venue_advtg`    |
| 5 | **The Future**  | Which franchises are trending up or down over 19 seasons?                 | `mart_team_traject`   |

*Business call → mart → SQL query → quantified recommendation.*

See `NHL_Dashboard.pdf` for the final dashboard and `full_validation.md` for verified query outputs with post-2019 outcome cross-checks.

---

## Architecture

```
7 CSV files (Kaggle)
        ↓  Polars  (python/ingest.py)
DuckDB — Bronze Layer  (raw.* — immutable)
        ↓  dbt staging models
Silver Layer  (7 staging views — deduped, cleaned, typed)
        ↓  dbt gold models
Gold Layer  (3 dims + 2 facts + 5 marts — star schema)
        ↓  Parquet / CSV export  (python/export_marts.py)
Power BI Desktop Dashboard  (5 decision pages)
```

**Medallion architecture, single DuckDB file.** Bronze loads raw CSVs via Polars. Silver materialises 7 staging views with `QUALIFY ROW_NUMBER()` deduplication to resolve duplicate rows discovered in three 2018–2019 raw tables. Gold materialises a star schema of dims and facts plus 5 purpose-built marts, one per business call.

---

## Tech Stack

| Layer          | Tool                  |
| -------------- | --------------------- |
| Language       | Python 3.11           |
| Ingestion      | Polars                |
| Storage        | DuckDB                |
| Transformation | dbt-core + dbt-duckdb |
| Data Quality   | dbt tests             |
| CI/CD          | GitHub Actions        |
| Dashboard      | Power BI Desktop      |

All tools are free, open-source (or free tier), and Python-native. No vendor lock-in, no licensing fees. DuckDB's ANSI SQL ports to Snowflake or BigQuery with minimal rework if scaled up.

---

## Repo Structure

```
NHL_Pipeline/
├── README.md
├── requirements.txt                    # Pinned dependencies
├── .github/workflows/ci.yml            # dbt compile runs on every PR
├── data/
│   ├── (raw CSVs gitignored — download from Kaggle)
│   └── exports/                        # Mart exports for Power BI
├── docs/
│   ├── architecture.md                 # Pipeline design and tool decisions
│   ├── findings.md                     # The 41% story + data quality findings
│   └── table_relationships.JPG         # ERD
├── python/
│   ├── ingest.py                       # Polars: CSV → DuckDB bronze layer
│   ├── export_marts.py                 # Gold marts → data/exports/ (5 mart CSVs for Power BI)
│   ├── export_rolling.py               # Rolling 3-year win-rate + trajectory classification (Call 5)
│   └── export_trajectory_change.py     # 2017→2019 trajectory delta table (Call 5 infographic)
├── nhl_dbt/
│   ├── dbt_project.yml
│   └── models/
│       ├── staging/                    # 7 staging views (silver layer)
│       └── gold/                       # dims, facts, 5 marts
│           ├── dim_game.sql
│           ├── dim_player.sql
│           ├── dim_team.sql
│           ├── fct_play.sql
│           ├── fct_game_teams_stats.sql
│           ├── mart_player_season.sql
│           ├── mart_shot_zones.sql
│           ├── mart_penalty_cost.sql
│           ├── mart_venue_advtg.sql
│           ├── mart_team_traject.sql
│           └── schema.yml
├── notebooks/                          # Exploratory Jupyter notebooks
├── full_validation.md                  # Verified outputs for all 5 calls
├── NHL_Dashboard.pbix                  # Final Power BI file
├── NHL_Dashboard.pdf                   # PDF export of the dashboard
└── nhl_all_infographics.pdf            # Decision-page infographics
```

---

## Dataset

Source: [NHL Game Data — Martin Ellis (Kaggle)](https://www.kaggle.com/martinellis/nhl-game-data)
Coverage: 2000–2020 · 19 seasons · 23,735 games · 5,050,529 in-game events

| File                    | Rows      | Description                                     | Powers         |
| ----------------------- | --------- | ----------------------------------------------- | -------------- |
| `game.csv`              | 23,735    | Game results and metadata                       | All decisions  |
| `game_teams_stats.csv`  | 52,610    | Per-game team statistics                        | Decisions 4, 5 |
| `game_skater_stats.csv` | 945,830   | Per-game individual skater stats                | Decision 1     |
| `player_info.csv`       | 3,925     | Player metadata                                 | All decisions  |
| `game_plays.csv`        | 5,050,529 | Play-by-play events (filtered to 6 event types) | Decisions 2, 3 |
| `game_penalties.csv`    | 247,828   | One row per penalty event                       | Decision 3     |
| `team_info.csv`         | 33        | Team metadata                                   | All decisions  |

> **Note on `game_plays`:** We filter to 6 event types at the staging layer — Goal, Shot, Missed Shot, Blocked Shot, Penalty, Takeaway — retaining everything needed for the business questions while reducing volume.

---

## Setup

### Prerequisites

- Python 3.11
- DuckDB-compatible OS (Mac, Linux, or Windows / WSL)
- Power BI Desktop (Windows) to open the `.pbix` dashboard

### 1. Clone the repo

```bash
git clone https://github.com/Data-Avengers-5/NHL_Pipeline.git
cd NHL_Pipeline
```

### 2. Install dependencies

```bash
python -m venv .venv
source .venv/bin/activate          # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
```

### 3. Download the data

Download the 7 CSV files from [Kaggle](https://www.kaggle.com/martinellis/nhl-game-data) and place them in `data/`.

### 4. Run bronze ingestion

```bash
python python/ingest.py
```

This loads all 7 CSVs into the DuckDB `raw` schema using Polars (10–100× faster than pandas on this volume).

### 5. Run dbt transformations

```bash
cd nhl_dbt
dbt deps
dbt build
```

`dbt build` runs all staging and gold models and executes the `not_null` tests on `mart_penalty_cost`. End-to-end pipeline runtime: approximately 2 minutes on a modern laptop.

### 6. View the dashboard

Open `NHL_Dashboard.pbix` in Power BI Desktop. To refresh from your local DuckDB, run `python python/export_marts.py` to regenerate the files under `data/exports/`, then refresh in Power BI.

---

## Data Quality

Data quality is enforced through **dbt tests** integrated into the build:

| Check type   | Location                         | What it checks                                                        |
| ------------ | -------------------------------- | --------------------------------------------------------------------- |
| `not_null`   | `mart_penalty_cost`              | 5 critical columns on the penalty mart                                |
| Source dedup | Staging layer                    | `QUALIFY ROW_NUMBER()` removes duplicate rows in 2018–2019 raw tables |
| Schema       | `nhl_dbt/models/gold/schema.yml` | Column types and primary-key uniqueness                               |

Source data issues — including duplicate rows across three raw tables in the 2018–2019 seasons (which doubled goal-event counts before fixing) — are documented in `docs/findings.md` and resolved at the staging layer rather than masked downstream.

**Headline finding:** 46.3% of GOAL events (61,737 of 133,345) are missing x/y rink coordinates. SHOT events are only 0.34% missing. Root cause: NHL only began tracking coordinates in 2007–08; pre-2010 records are 100% missing for both shots and goals (58,949 of 58,949). Post-2010 coverage is 99.96% complete (32 missing of 71,576). The `mart_shot_zones` mart is therefore scoped to 2010-onwards to avoid era-boundary bias. Full analysis in `docs/findings.md`.

---

## CI/CD

GitHub Actions runs `dbt compile` on every pull request to `main`, completing in ~40 seconds. This validates that all models parse, `ref()` dependencies resolve, and the DAG is consistent — without requiring the gitignored CSV data to be present on the CI runner. See `.github/workflows/ci.yml`.

Local development uses the full `dbt build` (compile + run + test) once CSVs are downloaded.

---

## Considered but Not Implemented

The following tools were evaluated or scaffolded and may feature in future iterations:

- **Soda Core** — YAML checks defined in `soda/checks.yml`; execution deferred to a future iteration
- **Elementary** — evaluated for dbt-native observability; not implemented within the project timeline
- **Ruff / SQLFluff / pre-commit hooks** — evaluated as part of the linting strategy; not adopted in this iteration

Including these honestly here rather than in the active stack — the scope call was deliberate.

---

## Documentation

Pipeline documentation in `/docs`:

- `architecture.md` — pipeline design, tool decisions, medallion layers
- `findings.md` — the 41% story, business question answers, recommendations

Verified outputs and deliverables at the repo root:

- `full_validation.md` — verified SQL outputs for all 5 business calls, with post-2019 outcome cross-checks
- `NHL_Dashboard.pdf` — final Power BI dashboard export
- `nhl_all_infographics.pdf` — decision-page infographics

---

## License

Educational project — Generation Singapore Junior Data Engineer Programme.
Dataset: [Martin Ellis / Kaggle](https://www.kaggle.com/martinellis/nhl-game-data) — CC BY-NC-SA 4.0.