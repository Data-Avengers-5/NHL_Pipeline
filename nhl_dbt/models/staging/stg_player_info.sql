SELECT
    CAST(player_id AS bigint)                                   AS player_id,
    firstName                                                   AS first_name,
    lastName                                                    AS last_name,
    firstName || ' ' || lastName                                AS full_name,
    nationality,
    birthCity                                                   AS birth_city,
    CAST(birthDate AS date)                                     AS birth_date,
    primaryPosition                                             AS primary_position,
    CAST(height_cm AS float)                                    AS height_cm,
    ROUND(CAST(weight AS float)/2.205,1)                        AS weight_kg,
    shootsCatches                                               AS shoots_catches
FROM  {{ source('raw', 'player_info') }}