SELECT
    player_id,
    first_name,
    last_name,
    full_name,
    nationality,
    birth_city,
    birth_date,
    primary_position,
    height_cm,
    weight_kg,
    shoots_catches
FROM {{ ref('stg_player_info') }}