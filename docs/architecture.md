# Architecture

## Overview
This project follows a medallion architecture:
Raw CSV → Staging → Marts → Power BI

## Data Flow
1. Raw CSV files are ingested using Polars
2. Data is stored in DuckDB
3. dbt transforms data through staging and mart layers
4. Power BI connects to DuckDB for visualisation

## Layers
- **Bronze/Raw:** 6 original CSV files
- **Silver/Staging:** Cleaned and typed tables
- **Gold/Marts:** Business-ready tables for dashboard

## Tools
- Polars — fast data ingestion
- DuckDB — local analytical database
- dbt — data transformation
- Soda Core — data quality checks
- Power BI — dashboard
- GitHub Actions — automated testing