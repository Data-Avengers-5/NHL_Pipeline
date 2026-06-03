# NHL Pipeline 🏒

**JDE Final Project — Data Avengers 5**
End-to-end data pipeline on 19 years of NHL game data, delivering 5 business decisions via a Power BI dashboard.

---

## What This Project Does

We built a decision engine on the [NHL Game Dataset (Kaggle / Martin Ellis)](https://www.kaggle.com/martinellis/nhl-game-data) that answers 5 commercial questions a General Manager would actually face — each backed by descriptive analytics and a quantified recommendation.

The pipeline ingests 6 raw CSV files, transforms them through a star schema in DuckDB managed by dbt, and surfaces findings in a 5-page Power BI dashboard. A data-quality layer (dbt tests + Soda Core) runs throughout, uncovering our headline finding: **41.4% of all NHL goal records are missing coordinate data** — undetected across 19 years of public data.

---

## The 5 Business Questions

| # | Decision | Question |
|---|----------|----------|
| 1 | **Roster Investment** | Which underrated players deliver the most impact per minute of ice time? |
| 2 | **Coaching Strategy** | Which shot zones convert best — where should teams drill? |
| 3 | **Discipline Coaching** | When do penalties actually cost games? |
| 4 | **Venue Strategy** | Where is home-ice advantage largest and smallest? |
| 5 | **Multi-Year Planning** | Which franchises are trending up or down over 19 seasons? |

---

## Architecture

```
CSV files (Kaggle)
    ↓  Polars (extract.py)
Parquet files (data/raw/)
    ↓  Python (load_duckdb.py)
DuckDB (nhl.db)
    ↓  dbt (staging → marts)
Star Schema (fact + dim tables)
    ↓  Power BI
Dashboard (5 pages)
```

**Data quality runs at every layer:** dbt tests on staging + marts, Soda Core scans on raw data, and CI via GitHub Actions on every PR.

---

## Tech Stack

| Layer | Tool |
|-------|------|
| Ingestion | Python 3.11, Polars |
| Storage | DuckDB |
| Transformation | dbt-core + dbt-duckdb |
| Data Quality | dbt tests, Soda Core |
| Linting | Ruff (Python), SQLFluff (SQL) |
| Git hooks | pre-commit |
| CI/CD | GitHub Actions |
| Dashboard | Power BI (Web + Desktop) |

---

## Repo Structure

```
nhl-pipeline/
├── README.md
├── requirements.txt               # Pinned dependencies
├── .github/workflows/ci.yml       # dbt tests run on every PR
├── docs/
│   ├── architecture.md
│   ├── schema_erd.png
│   ├── findings.md                # The 41% story + business answers
│   └── decisions/                 # Architecture Decision Records (ADRs)
├── ingestion/
│   ├── extract.py                 # Polars: CSV → Parquet
│   └── load_duckdb.py             # Parquet → DuckDB
├── dbt_project/
│   ├── dbt_project.yml
│   ├── models/
│   │   ├── staging/               # stg_game, stg_player, stg_play, ...
│   │   └── marts/                 # fact_game_play, dim_player, dim_team, ...
│   ├── tests/
│   └── schema.yml
├── soda/
│   └── checks.yml
└── powerbi/
    └── nhl_dashboard.pbix
```

---

## Dataset

Source: [NHL Game Data — Martin Ellis (Kaggle)](https://www.kaggle.com/martinellis/nhl-game-data)

| File | Rows (approx.) | Description |
|------|----------------|-------------|
| `game.csv` | ~23,000 | Game results, season, home/away teams |
| `game_teams_stats.csv` | ~46,000 | Per-game team statistics |
| `game_skater_stats.csv` | ~1.1M | Per-game individual skater stats |
| `game_goalie_stats.csv` | ~46,000 | Per-game goalie stats |
| `player_info.csv` | ~8,000 | Player metadata |
| `game_plays.csv` | ~5M (filtered to ~900K) | Play-by-play events (filtered to 5 key event types) |

> **Note on `game_plays`:** We filter to 5 event types — Goal, Shot, Missed Shot, Blocked Shot, Penalty — before saving to Parquet. This reduces file size from ~5M rows to ~900K while retaining all events needed to answer the business questions.

---

## Setup

### Prerequisites

- Python 3.11
- Mac or Windows with admin rights
- Power BI Desktop (Windows) or Power BI Web at [app.powerbi.com](https://app.powerbi.com) (Mac)

### 1. Clone the repo

```bash
git clone https://github.com/Data-Avengers-5/nhl-pipeline.git
cd nhl-pipeline
```

### 2. Create a virtual environment and install dependencies

```bash
python -m venv venv
source venv/bin/activate        # Mac/Linux
# or: venv\Scripts\activate     # Windows

pip install -r requirements.txt
```

### 3. Download the data

Download the 6 CSV files from [Kaggle](https://www.kaggle.com/martinellis/nhl-game-data) and place them in:

```
data/raw/csv/
```

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

### 6. Open Power BI

Connect to `nhl.duckdb` via ODBC, or import the Parquet files directly as a fallback.

---

## Data Quality

Role 5 owns data quality for this project. Key checks:

- **dbt tests** — not_null, unique, and accepted_values on every staging and mart model
- **Soda Core** — row count thresholds, null rate checks, and freshness checks on raw tables
- **Headline finding** — 41.4% of goal records (61,740 of 148,992) are missing x/y coordinate data; shots are only 0.34% missing. This is a systematic upstream defect surfaced by our test suite.

See `soda/checks.yml` and `dbt_project/schema.yml` for full details.

---

## Team Roles

| Role | Member | Owns |
|------|--------|------|
| Tech Lead / Architect | Kevin | Repo, schema decisions, PR reviews, presentation |
| Ingestion + Schema Engineer | Zayanah | Polars ingestion, dbt sources, staging models |
| Analytics Engineer | Yan Han | dbt marts, business logic SQL |
| BI Engineer | Sid | Power BI dashboard (5 pages) |
| Data Quality + Documentation Lead | Normasitah | dbt tests, Soda Core, documentation, CI |

---

## CI/CD

GitHub Actions runs `dbt test` automatically on every pull request to `main`. No PR merges if tests are failing.

See `.github/workflows/ci.yml`.

---

## Key Rules (From Team Charter)

- **MVP first.** No Phase 2 work merges to `main` until MVP is shipped.
- **Stuck > 2 hours?** Ask your buddy before end of day.
- **Done early?** Pair with whoever is most stuck — don't grab the next task solo.
- **LLM-generated code** must be understood before it's committed. PR reviewer will ask you to explain one line.
- Only the Tech Lead commits changes to `requirements.txt` and `dbt_project.yml`.

---

## Documentation

Full project documentation lives in `/docs`:

- `architecture.md` — pipeline design and tool decisions
- `schema_erd.png` — entity-relationship diagram
- `findings.md` — the 41% story, business question answers, and recommendations
- `decisions/` — Architecture Decision Records for key choices made during the project

---

## License

This project is for educational purposes as part of the Generation Junior Data Engineer Programme. Dataset credit: Martin Ellis via Kaggle.
