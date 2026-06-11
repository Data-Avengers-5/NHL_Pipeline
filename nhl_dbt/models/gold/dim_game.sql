SELECT
    game_id,
    season,
    season_year,
    game_type,
    game_timestamp,
    venue,
    away_team_id,
    home_team_id,
    away_goals,
    home_goals,
    winner,
    period_type
FROM {{ ref('stg_game') }}