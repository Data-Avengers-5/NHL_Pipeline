import polars as pl
import duckdb
from pathlib import Path

# ── Paths ──────────────────────────────────────────────
DATA_DIR = Path(__file__).parent.parent / "data"
DB_PATH  = Path(__file__).parent.parent / "nhl_raw.duckdb"

# ── Connect to DuckDB ──────────────────────────────────
con = duckdb.connect(str(DB_PATH))
con.execute("CREATE SCHEMA IF NOT EXISTS raw")

print(f"Connected to DuckDB at {DB_PATH}")
print(f"Reading CSVs from {DATA_DIR}")

# ── CSV files to load ──────────────────────────────────
CSV_FILES = {
    "game":             "game.csv",
    "game_plays":       "game_plays.csv",
    "game_teams_stats": "game_teams_stats.csv",
    "game_skater_stats":"game_skater_stats.csv",
    "game_penalties":   "game_penalties.csv",
    "player_info":      "player_info.csv",
    "team_info":        "team_info.csv",
}

# ── Load each CSV into raw.* ───────────────────────────
for table_name, filename in CSV_FILES.items():
    filepath = DATA_DIR / filename
    print(f"\nLoading {filename}...")

    df = pl.read_csv(filepath, ignore_errors=True,
                     null_values=["", "NA", "null", "N/A"])

    con.execute(f"DROP TABLE IF EXISTS raw.{table_name}")
    con.execute(f"CREATE TABLE raw.{table_name} AS SELECT * FROM df")

    row_count = con.execute(f"SELECT COUNT(*) FROM raw.{table_name}").fetchone()[0]
    print(f"  raw.{table_name}: {row_count:,} rows loaded")

con.close()
print("\nDone. All tables loaded into nhl_raw.duckdb")