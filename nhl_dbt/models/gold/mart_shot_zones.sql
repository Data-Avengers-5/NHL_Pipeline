SELECT
    ts.team_id,
    fp.season_year,
    CASE
        WHEN fp.coord_x >= 69 AND fp.coord_y BETWEEN -22 AND 22  THEN 'slot'
        WHEN fp.coord_x >= 25 AND fp.coord_y > 22                THEN 'left_wing'
        WHEN fp.coord_x >= 25 AND fp.coord_y < -22               THEN 'right_wing'
        WHEN fp.coord_x BETWEEN 25 AND 54                        THEN 'point'
        ELSE 'other'
    END                                                           AS shot_zone,
    COUNT(*) FILTER (WHERE fp.event IN ('Shot', 'Missed Shot', 'Blocked Shot', 'Goal'))  AS total_shot_attempts,
    COUNT(*) FILTER (WHERE fp.event = 'Shot')                                            AS shots_on_goal,
    COUNT(*) FILTER (WHERE fp.event = 'Goal')                                            AS total_goals,
    ROUND(COUNT(*) FILTER (WHERE fp.event = 'Goal') * 100.0 /
          NULLIF(COUNT(*) FILTER (WHERE fp.event = 'Shot'), 0), 2)                       AS shot_conversion_rate,
    COUNT(*) FILTER (WHERE fp.event = 'Goal' AND fp.coord_x IS NOT NULL)                 AS goals_with_coords,
    COUNT(*) FILTER (WHERE fp.event = 'Goal' AND fp.coord_x IS NULL)                     AS goals_missing_coords,
    ROUND(COUNT(*) FILTER (WHERE fp.event = 'Goal' AND fp.coord_x IS NULL) * 100.0 /
          NULLIF(COUNT(*) FILTER (WHERE fp.event = 'Goal'), 0), 2)                       AS goals_missing_coords_pct
FROM {{ ref('fct_play') }} fp
LEFT JOIN {{ ref('fct_game_teams_stats') }} ts
    ON fp.game_id = ts.game_id
    AND fp.team_id_for = ts.team_id
WHERE ts.team_id IS NOT NULL
AND fp.season_year >= 2010
GROUP BY ts.team_id, fp.season_year, shot_zone
ORDER BY shot_conversion_rate DESC