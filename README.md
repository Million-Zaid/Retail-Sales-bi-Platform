# Retail Sales BI — Cloud Data Warehouse & Dashboard

An end-to-end business intelligence project built on a modern cloud data stack. I designed and loaded a cloud data warehouse from raw CSV sources, modeled it dimensionally, and built an interactive Tableau dashboard that answers real business questions for a fictional retail chain.

---

## Overview

This project simulates a real-world BI engagement for a retail company. The pipeline ingests raw data from cloud storage, transforms it into a dimensional model, and surfaces insights through an interactive dashboard. The business asked four strategic questions; the dashboard and analysis deliver the answers.

**What makes this project cloud-based:** the data warehouse (Snowflake) and source storage (Azure Blob Storage) both run entirely in the cloud. Data moves cloud-to-cloud through Snowflake external stages, so no local processing is involved in the pipeline itself.

---

## Architecture

```mermaid
flowchart TD
    subgraph CLOUD_SOURCE["Cloud Source"]
        A["Azure Blob Storage<br/>12 CSV files"]
    end

    subgraph SNOWFLAKE["Snowflake Cloud Data Warehouse"]
        B["External Stages<br/>12 cloud stages"]
        C["Staging Layer<br/>Raw CSV mirrors"]

        subgraph WAREHOUSE["Warehouse Layer - Star Schema"]
            D1["Dim_Product"]
            D2["Dim_Store"]
            D3["Dim_Customer"]
            D4["Dim_Reseller"]
            D5["Dim_Channel"]
            D6["Dim_Location"]
            D7["DIM_DATE"]
            F1["Fact_SalesActual"]
            F2["Fact_ProductSalesTarget"]
            F3["Fact_SRCSalesTarget"]
        end

        subgraph VIEWS["Access Layer - Secure Views"]
            V1["10 Pass-through Views"]
            V2["3 Analytical Views"]
        end
    end

    subgraph REPORTING["Reporting"]
        T["Tableau Desktop<br/>Interactive Dashboard"]
    end

    A -->|COPY INTO| B
    B --> C
    C --> D1
    C --> D2
    C --> D3
    C --> D4
    C --> D5
    C --> D6
    C --> D7
    C --> F1
    C --> F2
    C --> F3
    D1 -.FK.-> F1
    D2 -.FK.-> F1
    D7 -.FK.-> F1
    D7 -.FK.-> F2
    D7 -.FK.-> F3
    D1 --> V1
    D2 --> V1
    F1 --> V1
    F1 --> V2
    F2 --> V2
    F3 --> V2
    V1 --> T
    V2 --> T

    classDef source fill:#E8F4FD,stroke:#0366D6,color:#000
    classDef stage fill:#FFF4E5,stroke:#F66A0A,color:#000
    classDef dim fill:#E6FFED,stroke:#28A745,color:#000
    classDef fact fill:#FFE8EC,stroke:#D73A49,color:#000
    classDef view fill:#F3E8FF,stroke:#6F42C1,color:#000
    classDef report fill:#FFF5B4,stroke:#B08800,color:#000

    class A source
    class B,C stage
    class D1,D2,D3,D4,D5,D6,D7 dim
    class F1,F2,F3 fact
    class V1,V2 view
    class T report
```

---

## Business Questions Answered

1. How are stores 10 and 21 performing against their targets, and will they hit 2014 goals?
2. How should a $2 million bonus pool be split across stores based on 2013 performance?
3. What day-of-week product sales trends exist at stores 10 and 21?
4. Should any new stores be opened? If so, where?

---

## Tech Stack

| Layer | Technology |
|---|---|
| Cloud data warehouse | Snowflake |
| Cloud source storage | Azure Blob Storage |
| ETL & modeling | SQL |
| Visualization | Tableau Desktop |

---

## What I Built

- A cloud data warehouse in Snowflake with staging, dimension, fact, and views layers
- Seven dimension tables and three fact tables modeled as a star schema with surrogate keys, foreign-key constraints, and unknown-member rows
- A SQL-based ETL pipeline that loads 12 raw CSVs from Azure Blob Storage into staging, then into dimensions, then into fact tables
- Thirteen secure views (ten pass-through views plus three analytical views) that insulate the dashboard from base-table changes
- A Tableau dashboard with four visualizations, a global year filter, and a click-to-filter interaction

---

## Key Findings

- Five of six stores declined in percent-of-target between 2013 and 2014, pointing to a portfolio-wide trend rather than isolated underperformance
- Atlanta is the strongest market by a wide margin, generating more than double the profit of the average Arkansas store
- My recommendation on new store expansion: delay until underperformers are addressed, then target Atlanta-style metros such as Nashville, Charlotte, or Birmingham

---

## Dashboard Preview

### Full Dashboard
![Dashboard Overview](screenshots/dashboard.png)

### Actual vs Target Sales by Store
![Actual vs Target Sales](screenshots/actual_vs_target.png)

### % of Target Achieved by Store
![Percent of Target Achieved](screenshots/percent_of_target.png)

### % of Target Achieved Trajectory by Year
![Percent of Target Trajectory from 2013 to 2014](screenshots/percent_of_target.png)

### Product Category Sales by Day of Week
![Product Sales by Day of Week](screenshots/percent_of_target_trajectory.png)

### Profit by State
![Profit by State Map](screenshots/map.png)

---

## Repository Contents

| File | Purpose |
|---|---|
| `RetailSalesBI_STAGING.sql` | Creates the database, warehouse, Azure cloud stages, file format, and staging tables; loads raw CSV data |
| `RetailSalesBI_DIMENSION_LOADS.sql` | Creates and populates all dimension tables with surrogate keys and unknown-member rows |
| `RetailSalesBI_FACT_TABLE_LOADING.sql` | Creates fact tables with foreign-key constraints and loads them with null handling |
| `RetailSaleBI_VIEWS.sql` | Builds the secure views layer (pass-through + analytical) |
| `IMT577_Final_Visualizations.twbx` | Tableau workbook with the dashboard |
| `ERD.png` | Dimensional model diagram |
| `TECHNICAL.md` | Deep dive into architecture, ETL design, and key decisions |

---

## Technical Details

For a full walkthrough of the architecture, ETL approach, and design decisions, see [TECHNICAL.md](./TECHNICAL.md).

---

## About

Built as the capstone project for IMT 577 (Data Management for Business Intelligence) at the University of Washington Information School. The business scenario and source data were provided; the warehouse design, ETL implementation, analytical views, dashboard, and recommendations are my own work. I was responsible for the full data warehouse build and the new-store-expansion analysis.
