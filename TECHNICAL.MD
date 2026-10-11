# Technical Documentation

A deeper walkthrough of the architecture, ETL approach, and key design decisions behind the Retail Sales BI project. This document is written for anyone reviewing the project in a technical interview context.

---

## Overview

The project is an end-to-end business intelligence pipeline for a fictional retail chain. Raw sales, customer, store, product, channel, and target data land as CSV files in Azure Blob Storage. A Snowflake cloud data warehouse ingests those files, transforms them into a star-schema dimensional model, and exposes the modeled data through a secure views layer that Tableau connects to for dashboard reporting.

---

## Architecture

The pipeline follows a four-layer design:

```
Azure Blob Storage (CSVs)
          |
          v
Staging Layer (Snowflake tables mirroring raw schema)
          |
          v
Warehouse Layer (Dimensions + Facts, star schema)
          |
          v
Access Layer (Secure Views for Tableau)
```

Each layer has a clear separation of concerns:

- Changes at the **source** do not ripple past the staging layer
- Changes to **warehouse tables** do not ripple past the views layer
- Downstream tools only ever touch **views**, never base tables

This is standard practice for a warehouse that supports multiple downstream consumers.

---

## Dimensional Model

The warehouse uses a Kimball-style star schema. Seven dimensions describe business entities and three fact tables record events and measures.

### Dimensions

| Dimension | Grain | Purpose |
|---|---|---|
| `Dim_Product` | One row per product | Pricing, cost, category hierarchy |
| `Dim_Store` | One row per store | Store number, manager, location reference |
| `Dim_Reseller` | One row per reseller | Reseller name, contact information |
| `Dim_Customer` | One row per customer | Customer name, demographics |
| `Dim_Channel` | One row per channel | Sales channel (in-store, online, reseller) |
| `Dim_Location` | One row per unique address | Shared location dim used by stores, customers, resellers |
| `DIM_DATE` | One row per day | Calendar + fiscal attributes |

Every dimension has:

- An `IDENTITY` surrogate primary key (`DimXxxID`) used by all fact tables
- The natural source key preserved as a column (e.g., `SourceStoreID`, `ProductID`)
- An **Unknown Member** row inserted at surrogate key `-1` so that any failed lookup from a fact maps to a known placeholder rather than NULL

### Fact Tables

| Fact Table | Grain | Measures |
|---|---|---|
| `Fact_SalesActual` | One row per sales detail line | Sale amount, quantity, unit price, extended cost, total profit |
| `Fact_ProductSalesTarget` | One row per product per day | Daily sales quantity target |
| `Fact_SRCSalesTarget` | One row per store/reseller/channel per day | Daily sales amount target |

Fact tables enforce `NOT NULL` on every foreign key and use inline `CONSTRAINT ... FOREIGN KEY REFERENCES` syntax so the relationships are documented in Snowflake metadata.

---

## ETL Approach

The pipeline runs in strict dependency order: **staging → dimensions → facts → views**.

### Staging Load

`COPY INTO` statements pull each CSV from its Azure external stage into a staging table using a shared CSV file format that skips the header row:

```sql
CREATE OR REPLACE FILE FORMAT CSV_SKIP_HEADER
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1;
```

Staging tables use permissive `VARCHAR` types to tolerate messy source data.

### Dimension Load

Each dimension follows a three-step pattern:

1. `CREATE OR REPLACE TABLE` with an `IDENTITY` surrogate key column
2. `INSERT` the Unknown Member row at `DimXxxID = -1` with sentinel values (`'Unknown'` for strings, `-1` for integer keys, `0` for numerics)
3. `INSERT ... SELECT FROM` to load real data from staging, joining lookup tables as needed

Dimensions that span multiple sources (notably `Dim_Location`) use `UNION` to deduplicate addresses across customer, store, and reseller staging. Dimensions that need a hierarchy join use chained `INNER JOIN`s between staging tables.

### Fact Load

Fact tables are created with inline foreign-key constraints referencing dimension primary keys:

```sql
CREATE OR REPLACE TABLE Fact_SalesActual (
    DimProductID  INT NOT NULL CONSTRAINT FK_DimProductID  FOREIGN KEY REFERENCES Dim_Product(DimProductID),
    DimStoreID    INT NOT NULL CONSTRAINT FK_DimStoreID    FOREIGN KEY REFERENCES Dim_Store(DimStoreID),
    ...
);
```

The INSERT uses `INNER JOIN` for required dimensions (Product) and `LEFT JOIN` for optional ones (Store, Reseller, Customer). Every surrogate-key lookup is wrapped in `NVL(..., -1)`:

```sql
NVL(ds.DimStoreID, -1)    AS DimStoreID,
NVL(dr.DimResellerID, -1) AS DimResellerID,
```

This routes any failed match to the dimension's Unknown Member row rather than letting a NULL violate the fact table's `NOT NULL` constraint.

### Daily-Grain Target Explosion

The source target data is **annual** (one row per entity per year), but the fact tables store targets at **daily grain** so they can compare row-for-row against daily actuals. During the load, each annual target row is cross-joined against every date in that year:

```sql
INNER JOIN DIM_DATE dd ON dd.YEAR = TO_NUMBER(stc.Year)
```

This expands:

- 49 product-target rows into **17,520** daily rows
- 23 channel-target rows into **8,030** daily rows

---

## Data Quality Challenges

### Two-Digit Year Parsing

Source sale dates arrived as two-digit years, which `TO_DATE()` interpreted as year 13 and 14 AD instead of 2013 and 2014. The fix was a `DATEADD` correction in the fact load:

```sql
LEFT JOIN DIM_DATE dd
    ON DATEADD(YEAR, 2000, TO_DATE(sh.Date)) = dd.DATE
```

Without this, every date lookup failed and all `DimSaleDateID` values collapsed to `-1`, breaking the dashboard.

### Target Aggregation Trap

Because annual targets are replicated daily (same value on every day of the year), summing them inflates the result by 365x. The analytical view `View_Store_Actual_Vs_Target` uses `MAX()` on the target column to correctly recover the annual value:

```sql
MAX(fst.SalesTargetAmount) AS TargetSalesAmount
```

Documented clearly so anyone writing ad-hoc queries against the fact tables knows to never `SUM` target columns across days.

---

## Views Layer

Thirteen secure views sit on top of the warehouse tables.

### Pass-Through Views (10)

One view per dimension and fact table. Each explicitly lists all columns (no `SELECT *`) so adding or renaming columns in base tables doesn't silently expose new fields through the API.

### Analytical Views (3)

Custom views that handle the joins, aggregations, and calculated columns Tableau would otherwise have to do itself:

- **`View_Store_Actual_Vs_Target`** — joins actuals and targets by store and year with calculated `PctOfTarget` and `VarianceToTarget` columns. Uses `MAX(SalesTargetAmount)` to correctly recover the annual target from daily-replicated rows.
- **`VW_PRODUCT_SALES_BY_DAYOFWEEK`** — pre-aggregates sales by store, day of week, and product category for the stores being analyzed.
- **`VW_STORE_LOCATION_SALES_SUMMARY`** — aggregates sales and profit by store, city, state, and year for geographic analysis.

All views use `CREATE OR REPLACE SECURE VIEW` so the underlying SQL is hidden from consumers and the views can be shared across environments without exposing table structure.

---

## Tableau Dashboard

The dashboard is backed by three separate Tableau data sources (one per analytical view) because the views sit at different grains and can't be meaningfully joined inside Tableau.

### Visualizations

| Chart | Purpose |
|---|---|
| Actual vs. Target by Store & Year | Compare performance against targets |
| Percent of Target Achieved | Highlight over/under performers |
| Product Sales by Day of Week | Spot day-of-week trends by product category |
| Profit by State (Choropleth) | Geographic performance for expansion analysis |

### Interactivity

- **Global year filter** wired across all four sheets using "Apply to Selected Worksheets" across data sources
- **Click-to-filter action** on the Actual vs. Target chart that filters the other three sheets to the clicked store

---

## Key Design Decisions

| Decision | Why |
|---|---|
| Surrogate keys everywhere | Insulates the warehouse from source system key changes; enables the Unknown Member pattern |
| Unknown Member in every dimension | Keeps `NOT NULL` fact constraints enforceable without dropping rows when a lookup fails |
| Daily-grain targets with `MAX` aggregation in views | Lets daily actuals compare directly against targets without inflating the target by 365x |
| Secure views layer | Downstream tools never touch base tables, so schema evolution doesn't break reports |
| Role-playing date dimension | One physical `DIM_DATE` referenced by both `DimSaleDateID` (actuals) and `DimTargetDateID` (targets) in different semantic roles |

---

## What I'd Do Differently

- Add an Unknown Member row (`DATE_PKEY = -1`) to `DIM_DATE` for full consistency with the other dimensions
- Automate the ETL with a stored procedure or orchestration tool (e.g., Snowflake Tasks, dbt, Airflow) rather than running SQL scripts manually
- Add data-quality tests between layers (row counts, null checks, referential integrity) that would catch issues like the year-13 parsing bug earlier
- Build a slowly-changing-dimension pattern (Type 2) on `Dim_Store` and `Dim_Product` to track attribute history over time

---

## Course Context

Built as the capstone project for IMT 577 (Data Management for Business Intelligence) at the University of Washington Information School. The business questions, source data, and schema framework were provided by the course; the implementation choices, analytical views, dashboard, and recommendations are my own work.
