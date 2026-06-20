# Pipeline Model ERD

Full entity-relationship diagram — dims, facts, and gold marts.
Verified against actual dbt SQL. Last updated June 2026.

> **Note:** `dim_player` and `dim_team` are also consumed by Power BI
> for readable names — those are BI-layer connections, not dbt SQL joins.

```mermaid
erDiagram
  dim_game ||--o{ fct_play : "game_id"
  dim_game ||--o{ fct_game_teams_stats : "game_id"
  dim_game ||--o{ mart_player_season : "season_year"
  dim_team ||--o{ fct_game_teams_stats : "team_id"
  dim_player ||--o{ mart_player_season : "birth_date"
  fct_play ||--o{ mart_shot_zones : "play events"
  fct_play ||--o{ mart_penalty_cost : "penalty plays"
  fct_game_teams_stats ||--o{ mart_venue_advtg : "team outcomes"
  fct_game_teams_stats ||--o{ mart_team_traject : "team outcomes"

  dim_game {
    bigint game_id PK
    int season_year
    varchar venue
    int home_team_id
    int away_team_id
  }
  dim_team {
    int team_id PK
    varchar team_name
    varchar city
    varchar abbreviation
  }
  dim_player {
    bigint player_id PK
    varchar full_name
    varchar primary_position
    date birth_date
  }
  fct_play {
    varchar play_id PK
    bigint game_id FK
    varchar event
    int period
    float coord_x
    float coord_y
  }
  fct_game_teams_stats {
    bigint game_id FK
    int team_id FK
    boolean won
    int goals
    int shots
  }
  mart_player_season {
    bigint player_id FK
    bigint game_id FK
    int season_year
    float points_per_60
    boolean is_veteran
    boolean is_underused_high_impact
  }
  mart_shot_zones {
    varchar shot_zone PK
    int season_year
    float shot_conversion_rate
  }
  mart_penalty_cost {
    int period PK
    varchar penalty_severity PK
    float loss_rate_pc
  }
  mart_venue_advtg {
    varchar venue PK
    int season_year
    float home_win_pct
  }
  mart_team_traject {
    int team_id FK
    int season_year
    float win_pct
    varchar trajectory
  }
```
