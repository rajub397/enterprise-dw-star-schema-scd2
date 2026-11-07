# Enterprise Data Warehouse: Star Schema with SCD Type 2

An end-to-end relational data warehouse implementation modeling an enterprise retail pipeline. This repository demonstrates dimensional modeling using Ralph Kimball's methodologies, automated Slowly Changing Dimension Type 2 (SCD2) history tracking via stored procedures, and complex OLAP analytics queries.

---

## Architecture Overview

The warehouse follows a classic **Star Schema** centered around transactional sales facts:

- **Fact Table:** `fact_sales` (Granularity: 1 row per order line item)
- **Dimensions:**
  - `dim_customer` (SCD Type 2 tracking address, tier, and region mutations)
  - `dim_product` (SCD Type 1/Type 2 tracking product categories and unit costs)
  - `dim_date` (Pre-generated role-playing date dimension)
- **Staging Layer:** `stg_customers`, `stg_orders` for raw, un-scrubbed delta ingestion

---

## Technical Features

1. **Surrogate Key Architecture:** Synthetic auto-incrementing surrogate keys isolate warehouse history from natural operational source keys.
2. **SCD Type 2 Implementation:**
   - Tracks operational attribute drift (`effective_start_date`, `effective_end_date`).
   - Maintains an atomic `is_current` boolean flag for low-cost filtering.
   - Handled via an automated PostgreSQL procedure (`sp_process_scd2_customer`) utilizing atomic transactions to close prior versions and insert updated records.
3. **Point-in-Time Fact Joins:** Sales facts join to dimensional records active at the specific instant the transaction occurred (`sale_date BETWEEN effective_start_date AND effective_end_date`).

---

## File Manifest

| File | Description |
|---|---|
| `sql/01_schema_ddl.sql` | DDL scripts creating staging schemas, dimensions, facts, and indexes. |
| `sql/02_seed_initial_data.sql` | Populates `dim_date`, initial dimension baselines, and initial staging. |
| `sql/03_scd2_pipeline_proc.sql` | Stored procedure encapsulating SCD Type 2 ingestion and delta detection. |
| `sql/04_simulate_changes_and_run.sql` | Ingests mutated source records and executes the SCD2 pipeline. |
| `sql/05_analytical_queries.sql` | OLAP queries: historical vs. current attribution, cohort analysis, and sales velocity. |
| `docs/architecture.md` | Data dictionary, lineage diagrams, and design trade-off documentation. |

---

## Execution Instructions

Run the scripts in sequence on PostgreSQL 13+ (or pgAdmin / DBeaver / psql):

```bash
psql -U postgres -d postgres -f sql/01_schema_ddl.sql
psql -U postgres -d postgres -f sql/02_seed_initial_data.sql
psql -U postgres -d postgres -f sql/03_scd2_pipeline_proc.sql
psql -U postgres -d postgres -f sql/04_simulate_changes_and_run.sql
psql -U postgres -d postgres -f sql/05_analytical_queries.sql
```
