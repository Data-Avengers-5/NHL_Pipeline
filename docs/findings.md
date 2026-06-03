# Data Quality Findings

## Headline Finding: The 41% Coordinate Gap

### What We Found

Of **148,992 GOAL events** across 19 years of NHL data, **61,740 records (41.4%)** are missing x/y rink coordinate data. By contrast, SHOT events are only missing coordinates **0.34%** of the time.

This is not random noise. The gap between goals (41.4% missing) and shots (0.34% missing) is so large that it points to a **systematic upstream defect** in how the NHL tracking system recorded goal coordinates — undetected in nearly two decades of public data.

Most dashboards quietly filter these NULLs out. We don't. We surface them as a first-class finding.

---

### How We Found It

Our three-layer data quality system caught this at multiple independent checkpoints:

| Layer | Tool | Check |
|-------|------|-------|
| Bronze | Soda Core | NULL rate on x/y columns in raw `game_plays` table |
| Silver | dbt test | `has_coordinates` flag must exist on every staging row |
| Gold | Soda Core | `unknown` shot zone bucket must contain ~41% of GOAL events |

If anyone adds a `WHERE x IS NOT NULL` filter anywhere in the pipeline, at least one of these three checks fires before a wrong number reaches the dashboard.

---

### Why It Matters

This finding affects **Business Question 2 (Shot Quality vs Conversion)** and **Business Question 3 (Penalty Cost)** — both of which rely on rink coordinate data for shot zone analysis and heatmaps.

| Impact | Detail |
|--------|--------|
| Shot zone analysis | 41.4% of goals cannot be mapped to a rink zone |
| Heatmap visualisations | Will be incomplete for goal events |
| Distance/angle calculations | Can only use 59% of goal records |
| Coaching decisions | Missing data = coaching gap nobody has flagged before |

---

### The Numbers

| Metric | Value |
|--------|-------|
| Total GOAL records | 148,992 |
| GOAL records missing coordinates | 61,740 (41.4%) |
| GOAL records with coordinates | 87,252 (58.6%) |
| SHOT records missing coordinates | ~0.34% |

---

### How We Handle It in the Pipeline

We do **not** drop or fill the missing records. Instead:

1. **Bronze layer** — raw data loaded as-is, NULLs preserved
2. **Silver layer** — a `has_coordinates` boolean flag is added to every row in staging (`TRUE` if both x and y are present, `FALSE` if either is NULL)
3. **Gold layer** — shot zone is assigned as `unknown` for records missing coordinates
4. **Dashboard** — every chart using coordinate data carries a visible data quality note showing the 41.4% limitation

---

### Recommendation

- Flag affected records clearly on every Power BI visual that uses coordinate data
- Use the available 58.6% of goal records with coordinates for shot zone analysis
- Do not present shot zone heatmaps as complete — always show the data quality caveat
- Consider this finding as evidence of engineering maturity: we found what 19 years of public analysis missed

---

### What This Tells Us About the Source Data

The tracking system appears to fail **both coordinate axes together** when it fails — records are either fully located (both x and y present) or fully unlocated (both x and y NULL). This rules out partial recording errors and suggests the failure happens at the event capture stage, not during data export.
