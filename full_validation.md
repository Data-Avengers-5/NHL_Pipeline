# NHL Pipeline — Full Validation Samples

*Five queries. Five business decisions. All verified against nhl_raw.duckdb
(Group_NHL_Pipeline) and cross-checked against real-world outcomes June 2026.*

---

## Call 1 — The Trade: Which undervalued players to target?

**Business question:** Which players are producing above league-average efficiency per
minute while receiving below-average playing time — and could be acquired at
below-market value?

**Query:**
```sql
SELECT
    p.full_name,
    p.primary_position,
    m.season_year,
    m.games_played,
    m.age_at_end_of_dataset,
    ROUND(m.points_per_60, 2)                AS points_per_60,
    ROUND(m.total_toi_seconds / 3600.0, 1)   AS toi_hours
FROM main_gold.mart_player_season m
JOIN main_gold.dim_player p ON m.player_id = p.player_id
WHERE m.is_underused_high_impact = TRUE
AND   m.season_year >= 2017
AND   m.games_played >= 41
AND   m.is_veteran = FALSE
ORDER BY m.points_per_60 DESC
LIMIT 10
```

**How the flags work — all data-driven, no external research required:**

`is_underused_high_impact` flags TRUE when both conditions are met for that season:
- `points_per_60 > AVG(points_per_60) OVER (PARTITION BY season_year)` → above 1.57
  (league average for qualifying players, 2017-2019)
- `total_toi_seconds < AVG(total_toi_seconds) OVER (PARTITION BY season_year)` →
  below 33.74 hours (league average total season TOI for qualifying players, 2017-2019)

`is_veteran` flags TRUE when age >= 35 calculated directly from `birth_date` in
`player_info.csv`:
`FLOOR(DATEDIFF('day', CAST(birth_date AS DATE), DATE '2019-12-31') / 365.25) >= 35`

Both flags are computed entirely within the dataset. No external research is required
to build the shortlist.

**Finding:**

| Player | Age | Season | Games | pts/60 | TOI hrs | After 2019 | Verdict |
|--------|-----|--------|-------|--------|---------|------------|---------|
| Ryan Spooner | 27 | 2017 | 59 | 2.73 | 15.0 | Left NHL after 2019 but became a KHL star — 109 pts in 142 games with Avangard; still playing | ⚠️ Found success elsewhere |
| Jesper Bratt | 21 | 2018 | 51 | 2.56 | 25.8 | NJD franchise cornerstone & alternate captain; five straight 70+ point seasons | ✅ Strong |
| Dominik Kahun | 24 | 2019 | 56 | 2.50 | 24.8 | 83 NHL points across CHI, PIT, BUF & EDM; IIHF silver 2023; now Lausanne HC | ✅ Partial |
| Austin Wagner | 22 | 2018 | 62 | 2.28 | 18.5 | Reliable bottom-6 forward, 178 NHL games; now KHL (Shanghai Dragons) | ⚠️ Found success elsewhere |
| Paul Byron | 30 | 2018 | 56 | 2.28 | 27.2 | Montreal alternate captain; played all 22 games of the Canadiens' 2021 Cup Final run | ✅ Strong |
| Travis Boyd | 26 | 2018 | 54 | 2.26 | 17.7 | Two 30+ point seasons at Arizona (career-high 35) when given real minutes | ✅ Strong |
| Evan Rodrigues | 26 | 2017 | 48 | 2.24 | 11.1 | Won back-to-back Stanley Cups with Florida Panthers (2024 & 2025) | ✅ Strong |
| Tyler Ennis | 30 | 2018 | 56 | 2.18 | 18.3 | Suppressed at Toronto behind Nylander; 37 pts next season at Ottawa/Edmonton given minutes | ✅ Strong |
| Vinnie Hinostroza | 25 | 2017 | 50 | 2.17 | 11.5 | Veteran journeyman, 460+ NHL games; still in NHL system 2025-26 (Minnesota, then Florida) | ✅ Partial |
| Martin Frk | 26 | 2017 | 68 | 2.14 | 11.7 | Elite AHL scorer (200+ goals, hardest shot in AHL history); offense-first game, brief NHL stints | ⚠️ Found success elsewhere |

All 10 shortlisted players went on to meaningful pro careers. 7 became established
NHL contributors; the other 3 found success elsewhere (Spooner and Wagner in the KHL,
Frk an elite AHL scorer). Evan Rodrigues won back-to-back Stanley Cups with Florida in
2024 and 2025. Travis Boyd and Tyler Ennis both broke out the moment they were given
real ice time elsewhere — exactly the underused-but-productive signal the pipeline is
built to detect. Not one shortlisted player washed out of pro hockey, confirming the
metric surfaced genuine talent.

**Recommendation:**
> *"The pipeline narrows 15,099 player-seasons to 10 names. Filtering is fully
> automated using data within the dataset — ages from player_info.csv remove veterans
> automatically. The 1.57 pts/60 and 33.74-hour TOI thresholds recalculate each
> season dynamically. The pipeline does not make the trade. It surfaces the right
> names to investigate."*

---

## Call 2 — The Drill: Which shot zones to prioritise in practice?

**Business question:** Where on the rink do shots actually become goals — and where
should players spend their practice time?

**Query:**
```sql
SELECT
    shot_zone,
    SUM(shots_on_goal)                      AS total_shots,
    SUM(total_goals)                        AS total_goals,
    ROUND(AVG(shot_conversion_rate), 2)     AS avg_conversion_rate
FROM main_gold.mart_shot_zones
WHERE shot_zone IS NOT NULL
GROUP BY shot_zone
ORDER BY avg_conversion_rate DESC
```

**Finding:**
| Zone | Conversion Rate | Total Shots | Total Goals |
|------|----------------|-------------|-------------|
| Slot | 19.45% | 279,298 | 54,329 |
| Other | 10.65% | 162,571 | 17,312 |
| Point | 5.18% | 151,222 | 7,829 |
| Right wing | 3.13% | 123,952 | 3,883 |
| Left wing | 3.05% | 124,966 | 3,806 |
Slot shots convert at 19.45% — 6x higher than wing shots at ~3%. Analysis scoped to
2010-2019 only. Pre-2010 data has 100% missing coordinates and is excluded. Post-2010
coverage is 99.96% complete (32 missing of 71,576).

**Recommendation:**
> *"Drill players to get to the slot and finish from there. Your forwards need ~5 slot
> shots to score one goal. From the wing, they need ~30. Same player, same skill —
> different location. Every minute of practice time spent on perimeter shooting is
> worth 6x less than drilling slot positioning and finishing."*

---

## Call 3 — The Penalty: When do penalties actually cost games?

**Business question:** Which penalties, in which periods, actually correlate with
losing the game?

**Query:**
```sql
SELECT
    period,
    penalty_severity,
    SUM(total_penalties)            AS total_penalties,
    SUM(games_with_penalty)         AS games_with_penalty,
    ROUND(AVG(loss_rate_pc), 2)     AS avg_loss_rate_pc
FROM main_gold.mart_penalty_cost
WHERE period IN (1, 2, 3)
AND   penalty_severity IS NOT NULL
GROUP BY period, penalty_severity
ORDER BY period, avg_loss_rate_pc DESC
```

**Finding:**
Period 3 Game Misconducts correlate with a 68.65% game loss rate — the highest of any
penalty type and period combination. Period 3 Misconducts overall: 61.88%. Period 1
Minor penalties: 50.82% — statistically indistinguishable from a coin flip. Period 3
Minor penalties show a 49.14% loss rate — slightly below 50% — because winning teams
have more puck possession and draw more defensive penalties. The same penalty in
Period 3 is up to 18 percentage points more consequential than in Period 1.

**Correlation vs causation note:**
The data shows loss rates associated with penalties — it does not prove the penalty
caused the loss. Teams already losing may take more desperate penalties. However,
Game Misconducts in Period 3 show a 68.65% loss rate versus 56.50% in Period 1 — a
12-point gap for the same penalty type. If score state alone explained the pattern,
that gap would be much smaller. Severity and timing carry independent signal.

**Recommendation:**
> *"Coach discipline differently by period. A Period 1 Minor barely matters — 50.82%
> loss rate is noise. A Period 3 Game Misconduct costs you the game 68.65% of the
> time. Whether the penalty caused the loss or the losing situation caused the penalty,
> the coaching message is the same: composure in Period 3 is non-negotiable."*

---

## Call 4 — The Arena: How much does home ice actually matter?

**Business question:** How much does playing at home improve a team's chances of
winning — and which venues show the strongest effect?

**Query:**
```sql
SELECT
    venue,
    ROUND(AVG(home_games), 0)           AS avg_home_games,
    ROUND(AVG(home_win_pct), 2)         AS avg_home_win_pct,
    ROUND(AVG(avg_home_goals), 2)       AS avg_home_goals,
    ROUND(AVG(avg_away_goals), 2)       AS avg_away_goals,
    ROUND(AVG(home_win_pct) - 50, 2)    AS home_advantage_uplift
FROM main_gold.mart_venue_advtg
GROUP BY venue
HAVING AVG(home_games) >= 30
ORDER BY avg_home_win_pct DESC
LIMIT 10
```

**Finding:**
| Venue | Team | Avg Win % | Uplift | Home Goals | Away Goals |
|-------|------|-----------|--------|------------|------------|
| Reunion Arena | Dallas Stars | 72.22% | +22.22pp | 3.36 | 2.06 |
| Corel Centre | Ottawa Senators | 66.26% | +16.26pp | 3.32 | 2.19 |
| Amalie Arena | Tampa Bay Lightning | 65.86% | +15.86pp | 3.44 | 2.66 |
| Compaq Center at San Jose | San Jose Sharks | 65.79% | +15.79pp | 3.34 | 2.24 |
| PPG Paints Arena | Pittsburgh Penguins | 65.69% | +15.69pp | 3.51 | 2.71 |

Top NHL home venues show +13 to +22 percentage point win rate uplift over a neutral
50% baseline. Home teams score approximately 0.9 more goals per game at their own
arena. Note: Reunion Arena (Dallas Stars) has a small sample (~36 home games per
season) and should be treated with caution. San Jose Sharks appear twice under two
arena names — the same venue renamed mid-dataset. Filter: HAVING AVG(home_games) >= 30
excludes outdoor and neutral site games.

**Recommendation:**
> *"Home ice advantage is worth +13 to +22 percentage points in win probability at top
> NHL venues. Home teams also score ~0.9 more goals per game at their own rink. In a
> Game 7, that is not a small edge — it is the difference between a coin flip and
> winning two times out of three. Finishing top of your division to earn home playoff
> games is worth more than most trade deadline acquisitions."*

---

## Call 5 — The Future: Which franchises are trending up or down?

**Business question:** Which teams are rising, stable or falling as of 2019 — and
what does that mean for franchise investment decisions?

**Query:**
```sql
WITH rolling AS (
    SELECT
        t.team_name,
        m.season_year,
        m.wins,
        m.win_pct,
        ROUND(AVG(m.win_pct) OVER (
            PARTITION BY m.team_id
            ORDER BY m.season_year
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2) AS rolling_3yr_win_pct
    FROM main_gold.mart_team_traject m
    JOIN main_gold.dim_team t ON m.team_id = t.team_id
),
with_trajectory AS (
    SELECT *,
        LAG(rolling_3yr_win_pct, 1) OVER (PARTITION BY team_name ORDER BY season_year) AS prev_1,
        LAG(rolling_3yr_win_pct, 2) OVER (PARTITION BY team_name ORDER BY season_year) AS prev_2
    FROM rolling
)
SELECT team_name, season_year, wins, win_pct, rolling_3yr_win_pct,
    CASE
        WHEN rolling_3yr_win_pct > prev_1 AND prev_1 > prev_2 THEN 'rising'
        WHEN rolling_3yr_win_pct < prev_1 AND prev_1 < prev_2 THEN 'falling'
        ELSE 'stable'
    END AS trajectory
FROM with_trajectory
ORDER BY team_name, season_year
```

**How the classification works:**
Trajectory measures consistent directional momentum across 3 consecutive seasons —
not the net change between two endpoints. A small but unbroken decline classifies as
falling. A larger but inconsistent swing classifies as stable. Example: St. Louis
Blues (-0.73pp net) are falling because their rolling rate declined consistently each
year. Montreal Canadiens (-1.47pp net) are stable because their year-by-year movement
was inconsistent.

**Finding:**
9 rising, 12 stable, 12 falling franchises as of 2019.

| Team | 2017 | 2019 | Change | Trajectory |
|------|------|------|--------|------------|
| Colorado Avalanche | 41.83% | 53.00% | +11.17pp | Rising |
| Tampa Bay Lightning | 58.17% | 67.33% | +9.16pp | Rising |
| Carolina Hurricanes | 43.50% | 51.47% | +7.97pp | Rising |
| Toronto Maple Leafs | 47.17% | 54.73% | +7.56pp | Rising |
| Vancouver Canucks | 37.40% | 44.67% | +7.27pp | Rising |
| Boston Bruins | 54.00% | 59.30% | +5.30pp | Rising |
| Winnipeg Jets | 51.03% | 56.17% | +5.14pp | Rising |
| Arizona Coyotes | 38.23% | 43.27% | +5.04pp | Rising |
| Ottawa Senators | 44.97% | 34.90% | -10.07pp | Falling |
| Anaheim Ducks | 54.30% | 44.90% | -9.40pp | Falling |
| Detroit Red Wings | 41.70% | 33.17% | -8.53pp | Falling |
| Chicago Blackhawks | 51.50% | 43.03% | -8.47pp | Falling |
| Los Angeles Kings | 52.07% | 43.83% | -8.24pp | Falling |
| New York Rangers | 50.97% | 43.90% | -7.07pp | Falling |
| Washington Capitals | 64.20% | 58.13% | -6.07pp | Falling |
| Vegas Golden Knights | 62.70% | 56.80% | -5.90pp | Falling |
| San Jose Sharks | 55.50% | 50.57% | -4.93pp | Falling |
| Pittsburgh Penguins | 59.50% | 54.77% | -4.73pp | Falling |

**Validation against real outcomes (verified June 2026):**
Tampa Bay Lightning (+9.16pp) → Won back-to-back Stanley Cups 2020-21 ✅
Colorado Avalanche (+11.17pp, largest gain) → Won Stanley Cup 2022 ✅
Boston Bruins (+5.30pp) → Set NHL all-time regular season wins record 2022-23 ✅
Carolina Hurricanes (+7.97pp) → 7 consecutive playoff appearances through 2025 ✅
Detroit Red Wings (-8.53pp) → 10 consecutive seasons without playoffs through 2025-26 ✅
Washington Capitals (-6.07pp) → Have not won since 2018; entering rebuild ✅
Pittsburgh Penguins (-4.73pp) → Have not won since 2017; entering rebuild ✅
Vegas Golden Knights (-5.90pp) → Won Stanley Cup 2023 despite falling classification ❌
New York Rangers (-7.07pp) → Rebounded to Conference Finals 2024 ❌

**Recommendation:**
> *"Buy into rising franchises before the market corrects — Tampa Bay Lightning and
> Colorado Avalanche both won championships within 3 years of being flagged rising.
> Sell falling veterans at peak value — Washington Capitals and Pittsburgh Penguins
> both confirmed their declines. Two misses (Vegas Golden Knights, New York Rangers)
> show the metric identifies trends not certainties. The pipeline is a compass, not a
> crystal ball — but in 2019 it was pointing in the right direction for most of the
> league."*

---

*All queries verified against nhl_raw.duckdb (Group_NHL_Pipeline).
Real-world outcomes cross-checked June 2026.*
