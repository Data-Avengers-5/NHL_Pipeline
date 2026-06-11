WITH player_season AS (
    SELECT
        s.player_id,
        g.season_year,
        COUNT(DISTINCT s.game_id)                           AS games_played,
        SUM(s.goals)                                        AS total_goals,
        SUM(s.assists)                                      AS total_assists,
        SUM(s.points)                                       AS total_points,
        SUM(s.shots)                                        AS total_shots,
        SUM(s.hits)                                         AS total_hits,
        SUM(s.pp_goals)                                     AS total_pp_goals,
        SUM(s.sh_goals)                                     AS total_sh_goals,
        SUM(s.penalty_minutes)                              AS total_penalty_minutes,
        SUM(s.plus_minus)                                   AS total_plus_minus,
        SUM(s.time_on_ice)                                  AS total_toi_seconds,
        SUM(s.even_time_on_ice)                             AS total_even_toi_seconds
    FROM {{ ref('stg_game_skater_stats') }} s
    LEFT JOIN {{ ref('stg_game') }} g
        ON s.game_id = g.game_id
    WHERE g.season_year IS NOT NULL
    GROUP BY s.player_id, g.season_year,
)

SELECT
    player_id,
    season_year,
    games_played,
    total_goals,
    total_assists,
    total_points,
    total_shots,
    total_hits,
    total_pp_goals,
    total_sh_goals,
    total_penalty_minutes,
    total_plus_minus,
    total_toi_seconds,
    -- points per 60 minutes
    ROUND(total_points * 3600.0 / NULLIF(total_toi_seconds, 0), 2)          AS points_per_60,
    -- underused flag: high impact but low ice time relative to peers
    CASE
        WHEN games_played >= 10
            AND ROUND(total_points * 3600.0 / NULLIF(total_toi_seconds, 0), 2)
             > AVG(ROUND(total_points * 3600.0 / NULLIF(total_toi_seconds, 0), 2))
             OVER (PARTITION BY season_year)
            AND total_toi_seconds
             < AVG(total_toi_seconds) OVER (PARTITION BY season_year)
        THEN true
        ELSE false
    END                                                                      AS is_underused_high_impact
FROM player_season
ORDER BY points_per_60 DESC