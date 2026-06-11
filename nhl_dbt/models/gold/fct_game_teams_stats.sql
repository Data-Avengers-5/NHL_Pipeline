SELECT
    game_id,
    team_id,
    is_home,
    won,
    settled_in,
    goals,
    shots,
    hits,
    pim,
    pp_opportunities,
    pp_goals,
    pp_conversion_rate,
    face_off_win_perc,
    giveaways,
    takeaways,
    start_rink_side
FROM {{ ref('stg_game_teams_stats') }}