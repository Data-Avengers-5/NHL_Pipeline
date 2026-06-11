SELECT
    ts.team_id,
    -- from stg_game
    g.season_year,
    COUNT(*)                                                            AS games_played,
    -- from stg_team_stats
    COUNT(*) FILTER (WHERE ts.won = True)                               AS wins,
    ROUND(COUNT(*) FILTER (WHERE ts.won = true) * 100.0 / COUNT(*), 1)  AS win_pct,
    ROUND(AVG(ts.goals), 2)                                             AS avg_goals_for,
    ROUND(AVG(ts.shots), 2)                                             AS avg_shots    
FROM {{ ref('stg_game') }} AS g
LEFT JOIN {{ ref('stg_game_teams_stats') }}                             AS ts
ON g.game_id = ts.game_id
GROUP BY ts.team_id, g.season_year