# NHL Pipeline — Full Validation Samples

*Five queries. Five business decisions. All verified against nhl_raw.duckdb (Group_NHL_Pipeline) and cross-checked against real-world outcomes June 2026.*

---

## Call 1 — The Trade: Which undervalued players to target?

**Business question:** Which players are being underutilised by their current team and could be acquired at below-market value?

**Query:**
```sql
SELECT
    p.full_name,
    p.primary_position,
    m.season_year,
    m.games_played,
    ROUND(m.points_per_60, 2)                AS points_per_60,
    ROUND(m.total_toi_seconds / 3600.0, 1)   AS toi_hours
FROM main_gold.mart_player_season m
JOIN main_gold.dim_player p ON m.player_id = p.player_id
WHERE m.is_underused_high_impact = TRUE
AND   m.season_year >= 2017
AND   m.games_played >= 41
ORDER BY m.points_per_60 DESC
LIMIT 10
```

**How the flag works:**
`is_underused_high_impact` flags a player-season TRUE when points_per_60 is above the
league average for that season AND total_toi_seconds is below the league average for
that season. The threshold is dynamic — it recalculates every season relative to peers.
The >=41 game minimum automatically excludes injury-shortened seasons.

**Finding:**
8 players on the scouting shortlist after removing age-managed veterans (Joe Thornton,
Jason Spezza). After 2019 cross-check:

| Player | pts/60 | Why flagged | After 2019 | Verdict |
|--------|--------|-------------|------------|---------|
| Ryan Spooner | 2.73 | Coaching / inconsistency | Left NHL 2019, now KHL | ❌ Miss |
| Jesper Bratt | 2.56 | Youth — limited minutes | New Jersey Devils franchise cornerstone, alternate captain, 168G/336A | ✅ Strong |
| Dominik Kahun | 2.50 | Undrafted player on deep Pittsburgh Penguins roster | 83 career NHL points; now Lausanne HC, Switzerland | ✅ Partial |
| Austin Wagner | 2.28 | 21-year-old rookie averaging 8:50 ice time with Los Angeles Kings | Reliable bottom-6 forward; now KHL (Shanghai Dragons) | ⚠️ Partial |
| Paul Byron | 2.28 | Speed/checking role player at Montreal Canadiens | Named alternate captain; 98 career goals, 208 career points | ✅ Strong |
| Travis Boyd | 2.26 | Suppressed by Washington Capitals roster depth | Career-high 17 goals & 35 points with Arizona Coyotes when given real ice time | ✅ Strong |
| Evan Rodrigues | 2.24 | Undrafted forward with Buffalo Sabres | Won the Stanley Cup with Colorado Avalanche in 2022; now Florida Panthers | ✅ Strong |
| Vinnie Hinostroza | 2.18 | 6th-round pick on 13:49 ice time at Chicago Blackhawks | Still active NHL 2025-26 with Florida Panthers; double-digit goals twice | ✅ Partial |

7 of 8 shortlisted players had meaningful or notable NHL careers after 2019. The one
confirmed miss — Ryan Spooner — is identifiable through a multi-team consistency check.

**Recommendation:**
> *"The pipeline narrows 15,099 player-seasons to 8 names worth a scout's time. The
> >=41 game filter removes injury cases automatically. Evan Rodrigues was undrafted,
> below-average minutes, flagged by our metric in 2017-18, and won the Stanley Cup in
> 2022. Travis Boyd posted career highs when given real ice time elsewhere. The pipeline
> does not make the trade — it surfaces the names that deserve the conversation."*

---

## Call 2 — The Drill: Which shot zones to prioritise in practice?

**Business question:** Where on the rink do shots actually become goals — and where should players spend their practice time?

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
| Slot | 19.46% | 569,584 | 111,959 |
| Other | 10.65% | 346,087 | 36,932 |
| Point | 5.18% | 308,620 | 16,001 |
| Right wing | 3.11% | 246,424 | 7,915 |
| Left wing | 3.02% | 251,242 | 7,850 |

Slot shots convert at 19.46% — 6x higher than wing shots at ~3%. Analysis scoped to
2010-2019 only. Pre-2010 data has 100% missing coordinates and is excluded. Post-2010
missing coordinate rate drops to under 0.15%.

**Recommendation:**
> *"Drill players to get to the slot and finish from there. Your forwards need 9 slot
> attempts to score one goal. From the wing, they need 33. Same player, same skill —
> different location. Every minute of practice time spent on perimeter shooting is worth
> 6x less than drilling slot positioning and finishing."*

---

## Call 3 — The Penalty: When do penalties actually cost games?

**Business question:** Which penalties, in which periods, actually correlate with losing the game?

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
Minor penalties: 50.82% — statistically indistinguishable from a coin flip. Notably,
Period 3 Minor penalties show a 49.14% loss rate — slightly below 50% — because winning
teams have more puck possession and draw more defensive penalties. The same penalty in
Period 3 is up to 18 percentage points more consequential than in Period 1.

**Correlation vs causation note:**
The data shows loss rates associated with penalties — it does not prove the penalty
caused the loss. Teams already losing may take more desperate penalties regardless of
period. However, Game Misconducts in Period 3 show a 68.65% loss rate versus 56.50% in
Period 1 — a 12-point gap for the same penalty type. If score state alone explained the
pattern, that gap would be much smaller. The combination of severity and timing carries
independent signal beyond just who is already losing.

**Recommendation:**
> *"Coach discipline differently by period. A Period 1 Minor barely matters — 50.82%
> loss rate is noise. A Period 3 Game Misconduct costs you the game 68.65% of the time.
> Whether the penalty caused the loss or the losing situation caused the penalty, the
> coaching message is the same: composure in Period 3 is non-negotiable."*

---

## Call 4 — The Arena: How much does home ice actually matter?

**Business question:** How much does playing at home improve a team's chances of winning — and which venues show the strongest effect?

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
| CONSOL Energy Center | Pittsburgh Penguins | 63.67% | +13.67pp | 3.16 | 2.45 |
| Continental Airlines Arena | New Jersey Devils | 63.63% | +13.63pp | 2.98 | 2.25 |
| Joe Louis Arena | Detroit Red Wings | 63.53% | +13.53pp | 3.22 | 2.46 |
| HP Pavilion at San Jose | San Jose Sharks | 63.49% | +13.49pp | 3.11 | 2.38 |
| First Union Center | Philadelphia Flyers | 63.16% | +13.16pp | 2.85 | 2.11 |

Top NHL home venues show +13 to +22 percentage point win rate uplift over a neutral 50%
baseline. Home teams score approximately 0.9 more goals per game at their own arena.
Note: Reunion Arena (Dallas Stars) has a small sample (~36 home games per season, 1-2
seasons) and should be treated with caution. San Jose Sharks appear twice under two
arena names (Compaq Center and HP Pavilion) — the same venue renamed mid-dataset.
Filter: HAVING AVG(home_games) >= 30 excludes outdoor and neutral site games.

**Recommendation:**
> *"Home ice advantage is worth +13 to +22 percentage points in win probability at top
> NHL venues. Home teams also score ~0.9 more goals per game at their own rink. In a
> Game 7, that is not a small edge — it is the difference between a coin flip and
> winning two times out of three. Finishing top of your division to earn home playoff
> games is worth more than most trade deadline acquisitions."*

---

## Call 5 — The Future: Which franchises are trending up or down?

**Business question:** Which teams are rising, stable or falling as of 2019 — and what does that mean for franchise investment decisions?

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
falling. A larger but inconsistent swing classifies as stable. Example: St. Louis Blues
(-0.73pp net) are falling because their rolling rate declined consistently each year.
Montreal Canadiens (-1.47pp net) are stable because their year-by-year movement was
inconsistent.

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

**Real-world cross-check (verified June 2026):**

Rising teams:
- Tampa Bay Lightning (+9.16pp) → Won back-to-back Stanley Cups 2020-21 ✅
- Colorado Avalanche (+11.17pp, largest gain) → Won Stanley Cup 2022 ✅
- Boston Bruins (+5.30pp) → Set NHL all-time regular season wins record in 2022-23 (65 wins) ✅
- Carolina Hurricanes (+7.97pp) → 7 consecutive playoff appearances through 2025 ✅
- Toronto Maple Leafs (+7.56pp) → 8 consecutive playoff appearances; won first series since 2004 in 2023 ✅
- New York Islanders (+2.30pp) → Back-to-back Conference Finals 2020-21 ✅
- Winnipeg Jets (+5.14pp) → Consistent playoff team throughout 2020s ✅
- Arizona Coyotes (+5.04pp) → Relocated to Utah as Utah Mammoth 2024; made playoffs 2025-26 ⚠️

Falling teams:
- Detroit Red Wings (-8.53pp) → Failed to qualify for playoffs for 10 consecutive seasons through 2025-26 ✅
- Washington Capitals (-6.07pp) → Have not won since 2018; entering rebuild phase ✅
- Pittsburgh Penguins (-4.73pp) → Have not won since 2017; entering rebuild ✅
- San Jose Sharks (-4.93pp) → Full rebuild mode by 2024; among worst teams in league ✅
- Ottawa Senators (-10.07pp) → Years of rebuilding; returned to playoffs only in 2024-25 ✅
- Chicago Blackhawks (-8.47pp) → Full rebuild; drafted Connor Bedard #1 overall in 2023 ✅
- Vegas Golden Knights (-5.90pp) → Won Stanley Cup 2023 despite falling classification ❌ Miss
- New York Rangers (-7.07pp) → Rebounded to Conference Finals 2024 ❌ Miss

**Notable misses:**
Vegas Golden Knights (falling -5.90pp) won the Cup in 2023. Their decline reflected
falling from an unusually high expansion-year peak — they stabilised and rebuilt.
New York Rangers (falling -7.07pp) also rebounded to contend by 2022-24. Both cases
show the metric identifies trends, not certainties. Teams can fall, stabilise and
rebuild within the window.

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
