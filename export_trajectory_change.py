import pandas as pd
import os

df = pd.read_csv('data/exports/mart_team_traject_rolling.csv')

pivot = df[df.season_year.isin([2017, 2019])].pivot(
    index='team_name',
    columns='season_year',
    values='rolling_3yr_win_pct'
).reset_index()

pivot.columns = ['team_name', 'win_rate_2017', 'win_rate_2019']
pivot['change'] = (pivot['win_rate_2019'] - pivot['win_rate_2017']).round(2)

traj_2019 = df[df.season_year == 2019][['team_name', 'trajectory']]
pivot = pivot.merge(traj_2019, on='team_name')
pivot = pivot.sort_values('change', ascending=False)

pivot.to_csv('data/exports/mart_trajectory_change.csv', index=False)
print(f'Exported: {len(pivot)} rows')
print(pivot.to_string())