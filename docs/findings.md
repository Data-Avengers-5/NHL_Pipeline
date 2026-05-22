# Data Quality Findings

## Key Finding: Missing Coordinate Data

### What We Found
41% of goal records are missing x/y coordinate data.
This means we cannot plot shot locations for nearly half of all goals.

### How We Found It
Our dbt test suite and Soda Core checks flagged null values
in the x and y coordinate columns of the game_plays table.

### Impact
- Business Question 4 (shot zone analysis) is affected
- Heatmap visualisations will be incomplete
- Any distance/angle calculations will exclude 41% of goals

### Recommendation
- Flag affected records clearly in the dashboard
- Use available 59% of coordinate data for shot zone analysis
- Note the limitation in all related Power BI visuals

### Numbers
- Total goal records: 148,992
- Records missing coordinates: ~61,087 (41%)
- Records with coordinates: ~87,905 (59%)