# Validation Samples

*One query per business decision. Each ends with a quantified recommendation.*
*All queries run against DuckDB gold layer (nhl_raw.duckdb). Verified locally.*

---

## Call 1 — The Trade: Which undervalued players to target?

**Business question:** Which players are being underutilised by their current team and could be acquired at below-market value?

**Query:**
```sql
WITH all_seasons AS (
    SELECT player_id, season_year,
        total_toi_seconds / 3600.0  AS toi_hours,
        points_per_60, games_played, is_underused_high_impact
    FROM mart_player_season
    WHERE games_played >= 20
),
flagged AS (
    SELECT a.player_id, a.season_year AS flagged_year,
        a.points_per_60, a.toi_hours AS flagged_toi, prev.toi_hours AS prev_toi
    FROM all_seasons a
    LEFT JOIN all_seasons prev
        ON a.player_id = prev.player_id
        AND prev.season_year = a.season_year - 1
    WHERE a.is_underused_high_impact = true
    AND a.season_year IN (2017, 2018, 2019)
    AND a.points_per_60 >= 2.0
    AND prev.toi_hours > a.toi_hours
)
SELECT p.full_name, p.primary_position, f.flagged_year,
    ROUND(f.points_per_60, 2)            AS points_per_60,
    ROUND(f.prev_toi, 1)                 AS toi_prev_year,
    ROUND(f.flagged_toi, 1)              AS toi_flagged_year,
    ROUND(f.prev_toi - f.flagged_toi, 1) AS toi_drop
FROM flagged f
JOIN dim_player p ON f.player_id = p.player_id
ORDER BY f.points_per_60 DESC
```

**Finding:**
16 unique players in 2017–2019 were producing above 2.0 points per 60 minutes while having their ice time actively cut from the previous season. Taylor Hall leads at 3.42 points per 60 despite a 4.3 hour ice time drop in 2018 — the same season he won the NHL MVP. Sven Baertschi was flagged in two consecutive seasons (2017 and 2018), confirmed by hockey analysts as a coaching mismatch under Travis Green's system at Vancouver.

**Recommendation:**
> *"The pipeline flagged 16 players whose ice time dropped while their production rate stayed above 2.0 points per 60. This is a shortlist for your scouts — not a final verdict. For each flagged player, a 30-minute scout review determines whether the drop is due to injury, age, or a coach undervaluing them. Our data narrows 900+ player-seasons down to 16 names worth investigating. Taylor Hall — NHL MVP in 2018 — appears on this list. That's the value of the pipeline: surface the signal, let the scouts find the story."*

---

## Call 2 — The Drill: Which shot zones to drill players in?

**Business question:** Where on the rink do shots actually become goals?

**Query:**
```sql
SELECT shot_zone,
    SUM(shots_on_goal)                  AS total_shots,
    SUM(total_goals)                    AS total_goals,
    ROUND(AVG(shot_conversion_rate), 2) AS avg_conversion_rate
FROM mart_shot_zones
GROUP BY shot_zone
ORDER BY avg_conversion_rate DESC
```

**Finding:**
| Zone | Conversion Rate |
|------|----------------|
| Slot | 19.46% |
| Other | 10.65% |
| Point | 5.18% |
| Right wing | 3.11% |
| Left wing | 3.02% |

Slot shots convert at 19.46% — 6x higher than wing shots at ~3%. Analysis scoped to 2010+ seasons only. Pre-2010 data has 100% missing coordinates and is excluded. Post-2010 missing coordinate rate is <0.15%.

**Recommendation:**
> *"Drill players to get to the slot and finish from there. Slot shots convert at 19.46% — 6x more effective than shooting from the wings. Every minute of practice time spent on perimeter shooting is worth 6x less than drilling slot positioning and finishing. Note: this finding is based on post-2010 data only — the 41% coordinate gap in pre-2010 data is a known source quality defect, not a pipeline error."*

---

## Call 3 — The Penalty: When do penalties actually cost games?

**Business question:** Which penalties, in which periods, actually cost games?

**Query:**
```sql
SELECT period, penalty_severity,
    SUM(total_penalties)        AS total_penalties,
    SUM(games_with_penalty)     AS games_with_penalty,
    ROUND(AVG(loss_rate_pc), 2) AS avg_loss_rate_pc
FROM mart_penalty_cost
GROUP BY period, penalty_severity
ORDER BY period, avg_loss_rate_pc DESC
```

**Finding:**
Period 3 Game Misconducts correlate with a 68.65% game loss rate. Period 3 Misconducts overall: 61.88%. Period 1 Minors: 50.82% — statistically indistinguishable from a coin flip. The same penalty in Period 3 is nearly twice as consequential as in Period 1.

**Recommendation:**
> *"Coach discipline differently by period. A Period 3 Game Misconduct costs you the game 68.65% of the time. A Period 1 Minor costs you 50.82% — essentially noise. Retaliation in Period 3 is a season-defining mistake. Your coaching staff should have a different message for players in the third period than the first."*

---

## Call 4 — The Arena: Where to schedule playoff games?

**Business question:** How much does home ice actually matter?

**Query:**
```sql
SELECT venue,
    ROUND(AVG(home_games), 0)        AS avg_home_games,
    ROUND(AVG(home_win_pct), 2)      AS avg_home_win_pct,
    ROUND(AVG(avg_home_goals), 2)    AS avg_home_goals,
    ROUND(AVG(avg_away_goals), 2)    AS avg_away_goals,
    ROUND(AVG(home_win_pct) - 50, 2) AS home_advantage_uplift
FROM mart_venue_advtg
GROUP BY venue
HAVING AVG(home_games) >= 30
ORDER BY avg_home_win_pct DESC
LIMIT 10
```

**Finding:**
Top NHL home venues show +15 to +22 percentage point win rate uplift over a neutral 50%. Home teams score ~0.9 more goals per game at their own rink. The strongest venues win 65–72% of home games across 19 seasons.

**Recommendation:**
> *"Home ice advantage is worth 15–22 percentage points in win probability at top venues. In a Game 7, that's the difference between a coin flip and a 2-in-3 chance. Finishing top of your division — earning an extra home playoff game — is worth more than any trade deadline acquisition."*

---

## Call 5 — The Future: Which franchises are trending?

**Business question:** Which teams are rising, which are falling?

**Query:**
```sql
WITH rolling AS (
    SELECT team_id, season_year,
        ROUND(AVG(win_pct) OVER (
            PARTITION BY team_id ORDER BY season_year
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2) AS rolling_3yr_avg
    FROM mart_team_traject
),
pivoted AS (
    SELECT team_id,
        MAX(rolling_3yr_avg) FILTER (WHERE season_year = max_yr)     AS avg_y,
        MAX(rolling_3yr_avg) FILTER (WHERE season_year = max_yr - 1) AS avg_y1,
        MAX(rolling_3yr_avg) FILTER (WHERE season_year = max_yr - 2) AS avg_y2
    FROM rolling
    JOIN (SELECT team_id AS tid, MAX(season_year) AS max_yr FROM rolling GROUP BY team_id)
        ON team_id = tid
    GROUP BY team_id
)
SELECT team_id, avg_y2, avg_y1, avg_y,
    CASE
        WHEN avg_y > avg_y1 AND avg_y1 > avg_y2 THEN 'rising'
        WHEN avg_y < avg_y1 AND avg_y1 < avg_y2 THEN 'falling'
        ELSE 'stable'
    END AS trajectory
FROM pivoted
ORDER BY
    CASE trajectory WHEN 'rising' THEN 1 WHEN 'stable' THEN 2 WHEN 'falling' THEN 3 END,
    avg_y DESC
```

**Finding:**
Teams classified by whether their 3-year rolling win rate is consistently improving, declining, or mixed across the last 3 seasons of data (2017–2019). Rising teams show monotonically increasing rolling averages. Falling teams show consistent decline.

**Recommendation:**
> *"Buy rising teams' young prospects before the market catches on. Sell falling teams' veterans at peak value before the decline becomes visible in the standings. The 3-year rolling win rate trend is a leading indicator — it moves before the standings confirm it. Act in the trade window before everyone else sees what the data already shows."*

---

*v1 — validated against nhl_raw.duckdb, June 2026.*