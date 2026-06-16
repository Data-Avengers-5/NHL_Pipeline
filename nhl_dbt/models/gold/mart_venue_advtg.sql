SELECT
    venue,
    season_year,
    COUNT(*)                                                                       AS home_games,
    COUNT(*) FILTER(WHERE winner = 'home')                                         AS home_wins,
    ROUND((COUNT(*) FILTER(WHERE winner = 'home'))/COUNT(*)*100.0,2)               AS home_win_pct,
    ROUND(AVG(home_goals), 2)                                                      AS avg_home_goals,
    ROUND(AVG(away_goals), 2)                                                      AS avg_away_goals
FROM {{ ref('dim_game') }}
GROUP BY venue, season_year