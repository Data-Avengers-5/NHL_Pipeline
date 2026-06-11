SELECT
    team_id,
    franchise_id,
    city,
    team_name,
    abbreviation
FROM {{ ref('stg_team_info') }}