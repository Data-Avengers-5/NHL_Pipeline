import duckdb
import os

conn = duckdb.connect("nhl_raw.duckdb")
os.makedirs("data/exports", exist_ok=True)

# Mart 1 — Player Season (joined with dim_player for names)
df = conn.execute("""
    SELECT
        p.full_name                     AS player_name,
        p.primary_position              AS position,
        m.season_year,
        m.games_played,
        m.total_goals,
        m.total_assists,
        m.total_points,
        m.total_toi_seconds / 3600.0    AS total_toi_hours,
        m.points_per_60,
        m.is_underused_high_impact
    FROM main_gold.mart_player_season m
    JOIN main_gold.dim_player p ON m.player_id = p.player_id
    WHERE m.games_played >= 5
""").fetchdf()
df.to_csv("data/exports/mart_player_season.csv", index=False)
print(f"Exported mart_player_season: {len(df):,} rows")

# Mart 2 — Shot Zones (aggregated across all teams and seasons)
df = conn.execute("""
    SELECT
        shot_zone,
        season_year,
        SUM(shots_on_goal)                  AS total_shots,
        SUM(total_goals)                    AS total_goals,
        ROUND(AVG(shot_conversion_rate), 2) AS avg_conversion_rate
    FROM main_gold.mart_shot_zones
    WHERE shot_zone IS NOT NULL
    GROUP BY shot_zone, season_year
    ORDER BY avg_conversion_rate DESC
""").fetchdf()
df.to_csv("data/exports/mart_shot_zones.csv", index=False)
print(f"Exported mart_shot_zones: {len(df):,} rows")

# Mart 3 — Penalty Cost
df = conn.execute("""
    SELECT
        season_year,
        period,
        penalty_severity,
        SUM(total_penalties)        AS total_penalties,
        SUM(games_with_penalty)     AS games_with_penalty,
        ROUND(AVG(loss_rate_pc), 2) AS avg_loss_rate_pc
    FROM main_gold.mart_penalty_cost
    WHERE period IN (1, 2, 3)
    AND penalty_severity IS NOT NULL
    GROUP BY season_year, period, penalty_severity
    ORDER BY period, avg_loss_rate_pc DESC
""").fetchdf()
df.to_csv("data/exports/mart_penalty_cost.csv", index=False)
print(f"Exported mart_penalty_cost: {len(df):,} rows")

# Mart 4 — Venue Advantage
df = conn.execute("""
    SELECT
        venue,
        season_year,
        home_games,
        home_wins,
        ROUND(home_win_pct, 2)      AS home_win_pct,
        ROUND(avg_home_goals, 2)    AS avg_home_goals,
        ROUND(avg_away_goals, 2)    AS avg_away_goals,
        ROUND(home_win_pct - 50, 2) AS home_advantage_uplift
    FROM main_gold.mart_venue_advtg
    WHERE venue IS NOT NULL
""").fetchdf()
df.to_csv("data/exports/mart_venue_advtg.csv", index=False)
print(f"Exported mart_venue_advtg: {len(df):,} rows")

# Mart 5 — Team Trajectory (joined with dim_team for names)
df = conn.execute("""
    SELECT
        t.team_name,
        t.city,
        m.season_year,
        m.games_played,
        m.wins,
        ROUND(m.win_pct, 4)         AS win_pct,
        ROUND(m.avg_goals_for, 2)   AS avg_goals_for,
        ROUND(m.avg_shots, 2)       AS avg_shots
    FROM main_gold.mart_team_traject m
    JOIN main_gold.dim_team t ON m.team_id = t.team_id
    ORDER BY t.team_name, m.season_year
""").fetchdf()
df.to_csv("data/exports/mart_team_traject.csv", index=False)
print(f"Exported mart_team_traject: {len(df):,} rows")

conn.close()
print("\nAll exports complete. Files saved to data/exports/")