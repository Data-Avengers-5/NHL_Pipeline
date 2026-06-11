SELECT
    play_id                                         AS play_id,
    CAST(penaltySeverity AS VARCHAR)                AS penalty_severity,
    CAST(penaltyMinutes AS integer)                 AS penalty_minutes
FROM {{ source('raw', 'game_penalties') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY play_id ORDER BY penaltyMinutes DESC) = 1