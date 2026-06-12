# NHL Pipeline 🏒

**JDE Final Project — Data Avengers 5**
The data pipeline that runs a hockey franchise. Five calls. Five million-dollar decisions. One pipeline.

---

## What This Project Does

We built a decision engine on 19 years of NHL game data that answers 5 commercial questions a General Manager would actually face — each backed by descriptive analytics and a quantified recommendation.

The pipeline ingests 7 raw CSV files, transforms them through a star schema in DuckDB managed by dbt, and surfaces findings in a dashboard answering the 5 business decisions. A data-quality layer (dbt tests + Soda Core + Elementary) runs throughout, uncovering our headline finding: **41.4% of all NHL goal records are missing coordinate data** — undetected across 19 years of public data.

---

## The 5 Business Decisions

| # | The Call | The Question | The Mart |
|---|----------|-------------|----------|
| 1 | **The Trade** | Which undervalued players deliver the most impact per minute of ice time? | `mart_player_season` |
| 2 | **The Drill** | Which shot zones convert best — where should teams drill? | `mart_shot_zones` |
| 3 | **The Penalty** | When do penalties actually cost games? | `mart_penalty_cost` |
| 4 | **The Arena** | Where is home-ice advantage largest and smallest? | `mart_venue_advantage` |
| 5 | **The Future** | Which franchises are trending up or down over 19 seasons? | `mart_team_trajectory` |

*Business call → mart → SQL query → quantified recommendation.*

---

## Architecture

```
7 CSV files (Kaggle)
        ↓  Polars (extract.py)
Parquet files (data/raw/)
        ↓  Python (load_duckdb.py)
DuckDB — Bronze Layer (raw, immutable)
        ↓  dbt staging models
Silver Layer (7 staging views — cleaned, typed)
        ↓  dbt dims + fact_play
Dims + Silver Fact (4 dims + fact_play — 5M rows)
        ↓  dbt mart models
Gold Layer (5 marts — one per business decision)
        ↓
Dashboard (5 decision pages)
```

**Data quality runs at every layer:** dbt tests on staging + marts, Soda Core scans, Elementary observability, and CI via GitHub Actions on every PR.

---

## Tech Stack

| Layer | Tool |
|-------|------|
| Language | Python 3.11 |
| Ingestion | Polars |
| Storage | DuckDB |
| Transformation | dbt-core + dbt-duckdb |
| Data Quality | dbt tests + Soda Core |
| Observability | Elementary Data |
| Linting | Ruff (Python), SQLFluff (SQL) |
| Git hooks | pre-commit |
| CI/CD | GitHub Actions |
| Dashboard | Power BI Web (app.powerbi.com) |

*All tools are free, open-source, and Python-native. No vendor lock-in. No licensing fees.*

---

## Repo Structure

```
NHL_Pipeline/
├── README.md
├── requirements.txt               # Pinned dependencies
├── .github/workflows/ci.yml       # dbt compile runs on every PR
├── data/                          # CSVs go here (gitignored) — download from Kaggle
│   └── .gitkeep
├── docs/
│   ├── architecture.md            # Pipeline design and tool decisions
│   ├── findings.md                # The 41% story + data quality findings
│   ├── validation_samples.md      # 5 business queries with quantified recommendations
│   └── table_relationships.JPG    # ERD
├── python/
│   └── ingest.py                  # Polars: CSV → DuckDB bronze layer
├── nhl_dbt/
│   ├── dbt_project.yml
│   ├── models/
│   │   ├── staging/               # 7 staging views (silver layer)
│   │   └── gold/                  # dims, facts, 5 marts
│   │       ├── dim_game.sql
│   │       ├── dim_player.sql
│   │       ├── dim_team.sql
│   │       ├── fct_play.sql
│   │       ├── fct_game_teams_stats.sql
│   │       ├── mart_player_season.sql
│   │       ├── mart_shot_zones.sql
│   │       ├── mart_penalty_cost.sql
│   │       ├── mart_venue_advtg.sql
│   │       ├── mart_team_traject.sql
│   │       └── schema.yml
│   └── profiles.yml               # local only — not committed
└── soda/
    └── checks.yml                 # Soda Core data quality checks
```

---

## Dataset

Source: [NHL Game Data — Martin Ellis (Kaggle)](https://www.kaggle.com/martinellis/nhl-game-data)
Coverage: 2000–2020 · 19 seasons · 23,735 games · 5,050,529 in-game events

| File | Rows | Description | Powers |
|------|------|-------------|--------|
| `game.csv` | 23,735 | Game results and metadata | All decisions |
| `game_teams_stats.csv` | 52,610 | Per-game team statistics | Decisions 4, 5 |
| `game_skater_stats.csv` | 945,830 | Per-game individual skater stats | Decision 1 |
| `game_goalie_stats.csv` | ~46,000 | Per-game goalie stats | Supporting |
| `player_info.csv` | 3,925 | Player metadata | All decisions |
| `game_plays.csv` | 5,050,529 | Play-by-play events (filtered to 5 event types) | Decisions 2, 3 |
| `game_penalties.csv` | 247,828 | One row per penalty event | Decision 3 |

> **Note on `game_plays`:** We filter to 5 event types at ingestion — Goal, Shot, Missed Shot, Blocked Shot, Penalty — reducing file size while retaining everything needed for the business questions.

---

## Setup

### Prerequisites
- Python 3.11
- Mac or Windows with admin rights
- Power BI Web at [app.powerbi.com](https://app.powerbi.com)

### 1. Clone the repo
```bash
git clone https://github.com/Data-Avengers-5/NHL_Pipeline.git
cd NHL_Pipeline
```

### 2. Install dependencies
```bash
pip install -r requirements.txt
```

### 3. Download the data
Download the 7 CSV files from [Kaggle](https://www.kaggle.com/martinellis/nhl-game-data) and place them in `data/raw/csv/`.

### 4. Run ingestion
```bash
# Step 1: Convert CSVs to Parquet
python ingestion/extract.py

# Step 2: Load Parquet files into DuckDB
python ingestion/load_duckdb.py
```

### 5. Run dbt
```bash
cd dbt_project
dbt deps
dbt run
dbt test
```

### 6. Run data quality checks
```bash
soda scan -d nhl_duckdb -c soda/configuration.yml soda/checks.yml
```

---

## Data Quality

Role 5 owns data quality for this project. Key checks across three independent layers:

| Layer | Tool | What it checks |
|-------|------|---------------|
| Silver | dbt tests | not_null, unique, accepted_values, relationships on all 7 staging models |
| Gold | dbt tests | Same checks on all 5 mart models |
| All layers | Soda Core | Row counts, null rates, value ranges |
| Pipeline | Elementary | Observability — DQ scores per model, lineage, run history |
| Every PR | GitHub Actions | Full dbt build + tests before any merge |

**Headline finding:** 41.4% of GOAL events (61,740 of 148,992) are missing x/y rink coordinates. SHOT events are only 0.34% missing. This structural defect is surfaced — not hidden — at three independent quality layers.

---

## Team Roles

| Role | Member | Owns |
|------|--------|------|
| Tech Lead / Architect | Kevin | Repo, schema decisions, PR reviews, presentation |
| Ingestion + Schema Engineer | Zayanah | Polars ingestion, dbt sources, staging models, ERD |
| Analytics Engineer | Yan Han | dbt marts, business logic SQL, fact_play |
| Pipeline Engineer | Sid | dbt project structure, CI/CD wiring, GitHub Actions |
| Data Quality + Documentation Lead | Normasitah | dbt tests, Soda Core, Elementary, documentation |

---

## CI/CD

GitHub Actions runs `dbt build` + `dbt test` automatically on every pull request to `main`. No PR merges if tests are failing. See `.github/workflows/ci.yml`.

---

## Key Rules

- **MVP first.** No Phase 2 work merges to `main` until Phase 1 is fully shipped.
- **Never push directly to `main`.** All changes go through a reviewed PR.
- **Stuck > 2 hours?** Ask your buddy before end of day.
- **Done early?** Pair with whoever is most stuck — swarm rule applies.
- Only the Tech Lead commits changes to `requirements.txt` and `dbt_project.yml`.

---

## Documentation

Full project documentation in `/docs`:
- `architecture.md` — pipeline design, tool decisions, medallion layers
- `findings.md` — the 41% story, business question answers, recommendations
- `decisions/` — Architecture Decision Records for key choices

---

## CV Bullet

*"Built production data pipeline (Polars · DuckDB · dbt · Soda Core · Elementary · GitHub Actions). Tested. Observable. Reproducible in 60 seconds on any laptop."*

---

## License

Educational project — Generation Singapore Junior Data Engineer Programme.
Dataset: [Martin Ellis / Kaggle](https://www.kaggle.com/martinellis/nhl-game-data) — CC BY-NC-SA 4.0.
