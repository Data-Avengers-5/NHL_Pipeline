select
    cast(team_id as integer)                                    as team_id,
    cast(franchiseId as integer)                                as franchise_id,
    cast(shortName as varchar)                                  as city,
    cast(teamName as varchar)                                   as team_name,
    cast(abbreviation as varchar)                               as abbreviation
    from {{ source('raw', 'team_info') }}