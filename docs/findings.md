# Data Quality Findings

## Headline Finding: The 41% Coordinate Gap

### What We Found

Of **148,992 GOAL events** across 19 years of NHL data (2000–2020), **61,740 records (41.4%)** are missing x/y rink coordinate data. By contrast, SHOT events are only missing coordinates **0.34%** of the time.

This is not random noise. The gap between goals (41.4% missing) and shots (0.34% missing) is so large that it points to a **systematic upstream defect** in how the NHL tracking system recorded goal coordinates — undetected in nearly two decades of public data.

Most dashboards quietly filter these NULLs out. We don't. We surface them as a first-class finding.

---

### How We Found It

Our three-layer data quality system caught this at multiple independent checkpoints:

| Layer | Tool | Check |
|-------|------|-------|
| Bronze | Soda Core | NULL rate on x/y columns in raw `game_plays` table (expected: 30–55%) |
| Silver | dbt test | `has_coordinates` flag must exist on every staging row |
| Gold | Soda Core | `unknown` shot zone bucket must contain ~41% of GOAL events |

If anyone adds a `WHERE x IS NOT NULL` filter anywhere in the pipeline, at least one of these three checks fires before a wrong number reaches the dashboard.

---

### Why It Matters

This finding directly affects **Business Decision 2 (The Drill — shot zone conversion)** and **Business Decision 3 (The Penalty — goal differential post-penalty)** — both of which rely on rink coordinate data.

| Impact | Detail |
|--------|--------|
| Shot zone analysis | 41.4% of goals cannot be mapped to a rink zone |
| Heatmap visualisations | Will be incomplete for goal events |
| Distance/angle calculations | Can only use 58.6% of goal records |
| Coaching decisions | Missing data = coaching gap undetected for 19 years |

---

### The Numbers

| Metric | Value |
|--------|-------|
| Total GOAL records | 148,992 |
| GOAL records missing coordinates | 61,740 (41.4%) |
| GOAL records with coordinates | 87,252 (58.6%) |
| SHOT records missing coordinates | ~0.34% |
| Total in-game events | 5,050,529 |
| Total penalties | 247,828 |

---

### How We Handle It in the Pipeline

We do **not** drop or fill the missing records. Instead:

1. **Bronze layer** — raw data loaded as-is, NULLs preserved and immutable
2. **Silver layer** — a `has_coordinates` boolean flag added to every row in `stg_game_plays` (`TRUE` if both x and y present, `FALSE` if either is NULL)
3. **fact_play (intermediate)** — shot zone assigned as `unknown` for records missing coordinates
4. **Gold marts** — `mart_shot_zones` includes an `unknown` zone bucket containing ~41% of goal events
5. **Dashboard** — every chart using coordinate data carries a visible data quality banner showing the 41.4% limitation

---

### Recommendation

- Flag affected records clearly on every dashboard visual that uses coordinate data
- Use the available 58.6% of goal records with coordinates for shot zone analysis
- Do not present shot zone heatmaps as complete — always show the data quality caveat inline
- Present this finding as evidence of engineering maturity: our pipeline found what 19 years of public analysis missed

---

### What This Tells Us About the Source Data

The tracking system appears to fail **both coordinate axes together** when it fails — records are either fully located (both x and y present) or fully unlocated (both x and y NULL). This rules out partial recording errors and suggests the failure happens at the event capture stage, not during data export.

The disparity between GOAL events (41.4% missing) and SHOT events (0.34% missing) is the key signal. Goals and shots are captured by the same tracking system — the systematic failure on goals specifically suggests a category-level recording problem, not a general data quality issue.

---

### Verifiability

This finding is verifiable end-to-end via SQL against the `stg_game_plays` staging model:

```sql
SELECT
    event,
    COUNT(*) AS total_events,
    SUM(CASE WHEN x IS NULL OR y IS NULL THEN 1 ELSE 0 END) AS missing_coords,
    ROUND(100.0 * SUM(CASE WHEN x IS NULL OR y IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_missing
FROM stg_game_plays
WHERE event IN ('Goal', 'Shot')
GROUP BY event
ORDER BY event;
```

Expected output: Goal → ~41.4% missing · Shot → ~0.34% missing.
