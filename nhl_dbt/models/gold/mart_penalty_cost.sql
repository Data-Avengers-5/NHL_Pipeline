WITH penalty_games AS (
    SELECT
        team_id_for, --team that fouled
        season_year,
        period,
        game_id,
        penalty_severity,
        penalty_minutes,
        CASE WHEN winner = 'home' THEN home_team_id
             ELSE away_team_id
        END AS winning_team_id,
        CASE WHEN team_id_for = (
                CASE WHEN winner = 'home' THEN home_team_id
                     ELSE away_team_id END)
             THEN true ELSE false
        END AS pen_team_won
    FROM {{ ref('fct_play') }}
    WHERE event = 'Penalty'
    AND season_year IS NOT NULL
    AND penalty_severity IS NOT NULL
)

SELECT
    team_id_for                                                                     AS team_id,
    season_year,
    penalty_severity,
    period,
    COUNT(DISTINCT game_id)                                                         AS games_with_penalty,
    COUNT(*)                                                                        AS total_penalties,
    ROUND(AVG(penalty_minutes), 2)                                                  AS avg_penalty_minutes,
    COUNT(DISTINCT game_id) FILTER(WHERE pen_team_won = TRUE)                                      AS pen_team_won,
    COUNT(DISTINCT game_id) FILTER(WHERE pen_team_won = FALSE)                      AS pen_team_lost,
    ROUND(COUNT(DISTINCT game_id) FILTER (WHERE pen_team_won = false) 
      * 100.0 / NULLIF(COUNT(DISTINCT game_id), 0), 2)                              AS loss_rate_pc
FROM penalty_games
GROUP BY team_id_for, season_year, penalty_severity, period
ORDER BY loss_rate_pc DESC