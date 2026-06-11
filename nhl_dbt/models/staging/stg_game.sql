select
    cast(game_id as bigint)                                    as game_id,
    cast(season as integer)                                    as season,
    -- extract readable season start year e.g. 20162017 → 2016
    cast(cast(season as integer) / 10000 as integer)           as season_year,
    cast(type as varchar)                                      as game_type,
    cast(date_time_gmt as timestamp)                           as game_timestamp,
    cast(venue as varchar)                                     as venue,
    cast(away_team_id as integer)                              as away_team_id,
    cast(home_team_id as integer)                              as home_team_id,
    cast(away_goals as integer)                                as away_goals,
    cast(home_goals as integer)                                as home_goals,
    -- split outcome into winner + period_type
    split_part(outcome, ' win ', 1)                            as winner,
    split_part(outcome, ' win ', 2)                            as period_type,
    -- flag tbc outcomes for exclusion downstream
    case when outcome like '%tbc%' then true else false end     as is_tbc,
    -- flag all-star games for exclusion downstream
    case when type = 'A' then true else false end               as is_allstar

from {{ source('raw', 'game') }}

-- exclude all-star games and tbc outcomes at staging level
where type != 'A'
  and outcome not like '%tbc%'