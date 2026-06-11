select
    cast(game_id as bigint)                                    as game_id,
    cast(team_id as bigint)                                    as team_id,
    CASE WHEN
        hoa = 'home' THEN true
        ELSE false
    END                                                                               as is_home,
    CAST(won AS bool)                                                                 as won,
    COALESCE(settled_in, 'REG')                                                       as settled_in,
    CAST(goals AS integer)                                                            as goals,
    CAST(shots AS integer)                                                            as shots,
    CAST(hits AS integer)                                                             as hits,
    CAST(pim AS integer)                                                              as pim,
    CAST(powerPlayOpportunities AS integer)                                           as pp_opportunities,
    CAST(powerPlayGoals AS integer)                                                   as pp_goals,
    CAST(powerPlayGoals AS float) / NULLIF(CAST(powerPlayOpportunities AS float), 0) as pp_conversion_rate,
    CAST(faceOffWinPercentage AS float)                                               as face_off_win_perc,
    CAST(giveaways AS integer)                                                        as giveaways,
    CAST(takeaways AS integer)                                                        as takeaways,
    CAST(startRinkSide AS varchar)                                                    as start_rink_side
from {{ source('raw', 'game_teams_stats') }}
