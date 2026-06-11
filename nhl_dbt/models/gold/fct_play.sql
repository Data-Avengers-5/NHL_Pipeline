SELECT
    p.play_id,
    p.game_id,
    p.team_id_for,
    p.team_id_against,
    p.event,
    p.secondary_type,
    p.coord_x,
    p.coord_y,
    p.period,
    p.period_type                       AS play_period_type,
    p.period_time,
    p.event_datetime,
    p.goals_away,
    p.goals_home,
    -- from stg_game
    g.season,
    g.season_year,
    g.game_type,
    g.game_timestamp,
    g.winner,
    g.period_type                   AS game_period_type,
    g.home_team_id,
    g.away_team_id,
    -- from stg_game_penalties
    pen.penalty_severity,
    pen.penalty_minutes

FROM {{ ref('stg_game_plays') }} AS p
LEFT JOIN {{ ref('stg_game') }} AS g
ON p.game_id = g.game_id
LEFT JOIN {{ ref('stg_game_penalties') }} AS pen
ON p.play_id = pen.play_id