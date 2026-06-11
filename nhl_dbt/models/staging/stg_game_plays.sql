SELECT
    CAST(play_id AS varchar)                                AS play_id,
    CAST(game_id AS bigint)                                 AS game_id,
    CAST(team_id_for AS bigint)                             AS team_id_for,
    CAST(team_id_against AS bigint)                         AS team_id_against,
    CAST(event AS varchar)                                  AS event,
    CAST(secondaryType AS varchar)                          AS secondary_type,
    CAST(st_x AS integer)                                   AS coord_x,
    CAST(st_y AS integer)                                   AS coord_y,
    CAST(period AS integer)                                 AS period,
    CAST(periodType AS varchar)                             AS period_type,
    CAST(periodTime AS integer)                             AS period_time,
    CAST(dateTime AS timestamp)                              AS event_datetime,
    CAST(goals_away AS integer)                             AS goals_away,
    CAST(goals_home AS integer)                             AS goals_home
FROM {{ source('raw', 'game_plays') }}
WHERE event IN ('Shot', 'Goal', 'Missed Shot', 'Blocked Shot', 'Penalty', 'Takeaway')
QUALIFY ROW_NUMBER() OVER (PARTITION BY play_id ORDER BY period_time) = 1