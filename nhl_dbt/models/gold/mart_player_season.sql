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
    GROUP BY s.player_id, g.season_year
),
player_ages AS (
    SELECT
        player_id,
        birth_date,
        FLOOR(
            DATEDIFF('day', CAST(birth_date AS DATE), DATE '2019-12-31') / 365.25
        )                                                   AS age_at_end_of_dataset
    FROM {{ ref('stg_player_info') }}
)
SELECT
    ps.player_id,
    ps.season_year,
    ps.games_played,
    ps.total_goals,
    ps.total_assists,
    ps.total_points,
    ps.total_shots,
    ps.total_hits,
    ps.total_pp_goals,
    ps.total_sh_goals,
    ps.total_penalty_minutes,
    ps.total_plus_minus,
    ps.total_toi_seconds,
    pa.age_at_end_of_dataset,
    -- veteran flag: age >= 35 at end of dataset (2019-12-31)
    CASE
        WHEN pa.age_at_end_of_dataset >= 35 THEN true
        ELSE false
    END                                                     AS is_veteran,
    -- points per 60 minutes
    ROUND(
        ps.total_points * 3600.0 / NULLIF(ps.total_toi_seconds, 0), 2
    )                                                       AS points_per_60,
    -- underused flag: high impact but low ice time relative to peers
    CASE
        WHEN ps.games_played >= 10
            AND ROUND(ps.total_points * 3600.0 / NULLIF(ps.total_toi_seconds, 0), 2)
             > AVG(ROUND(ps.total_points * 3600.0 / NULLIF(ps.total_toi_seconds, 0), 2))
             OVER (PARTITION BY ps.season_year)
            AND ps.total_toi_seconds
             < AVG(ps.total_toi_seconds) OVER (PARTITION BY ps.season_year)
        THEN true
        ELSE false
    END                                                     AS is_underused_high_impact
FROM player_season ps
LEFT JOIN player_ages pa ON ps.player_id = pa.player_id
ORDER BY points_per_60 DESC