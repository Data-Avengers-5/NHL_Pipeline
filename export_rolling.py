import duckdb, os

conn = duckdb.connect('nhl_raw.duckdb')
os.makedirs('data/exports', exist_ok=True)

df = conn.execute("""
WITH rolling AS (
    SELECT
        t.team_name,
        m.season_year,
        m.wins,
        m.win_pct,
        ROUND(AVG(m.win_pct) OVER (
            PARTITION BY m.team_id
            ORDER BY m.season_year
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2) AS rolling_3yr_win_pct
    FROM main_gold.mart_team_traject m
    JOIN main_gold.dim_team t ON m.team_id = t.team_id
),
with_trajectory AS (
    SELECT *,
        LAG(rolling_3yr_win_pct, 1) OVER (PARTITION BY team_name ORDER BY season_year) AS prev_1,
        LAG(rolling_3yr_win_pct, 2) OVER (PARTITION BY team_name ORDER BY season_year) AS prev_2
    FROM rolling
)
SELECT
    team_name,
    season_year,
    wins,
    win_pct,
    rolling_3yr_win_pct,
    CASE
        WHEN rolling_3yr_win_pct > prev_1 AND prev_1 > prev_2 THEN 'rising'
        WHEN rolling_3yr_win_pct < prev_1 AND prev_1 < prev_2 THEN 'falling'
        ELSE 'stable'
    END AS trajectory
FROM with_trajectory
ORDER BY team_name, season_year
""").fetchdf()

df.to_csv('data/exports/mart_team_traject_rolling.csv', index=False)
print(f'Exported: {len(df):,} rows')
print(df[df.season_year == 2019][['team_name','rolling_3yr_win_pct','trajectory']].sort_values('rolling_3yr_win_pct', ascending=False).to_string())
