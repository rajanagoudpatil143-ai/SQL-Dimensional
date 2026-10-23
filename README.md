# 📊 SQL Dimensional Data Warehouse & Analytics (`sales_dw`)

A production-grade **Dimensional Data Warehouse** mini project demonstrating Star Schema modeling, realistic synthetic data generation (500,000+ rows), advanced SQL analytics (Window Functions, CTEs, ROLLUP), and query performance engineering using MySQL `EXPLAIN` and `EXPLAIN ANALYZE`.

---

## 🏗️ Architecture & Project Structure

```
SQL-Dimensional/
├── README.md                      # Project setup and guide
├── requirements.txt               # Python package dependencies
├── .env.example                   # Environment credentials template
├── sql/
│   ├── 01_schema.sql              # Star Schema DDL (4 dims + 1 fact)
│   ├── 02_dim_date_load.sql       # Recursive CTE Date Dimension loader
│   ├── 03_window_rankings.sql     # Window functions (RANK, NTILE, Moving Avg)
│   ├── 04_cte_mom_report.sql      # Chained CTEs Month-Over-Month trend report
│   ├── 05_rollup_report.sql       # Hierarchical aggregations with WITH ROLLUP
│   ├── 06_explain_before.sql      # Unindexed query plans & baseline profiling
│   ├── 07_indexes.sql             # Targeted composite & covering indexes
│   └── 08_explain_after.sql       # Post-indexing performance validation
├── scripts/
│   ├── seed_data.py               # Faker data generator (500K+ rows)
│   └── run_reports.py             # CLI report runner & CSV exporter
├── docs/
│   ├── star_schema.md             # Mermaid ERD & analytical design rationale
│   └── optimization_notes.md      # Before/after EXPLAIN performance benchmarks
└── output/                        # Exported report CSVs
```

---

## ⚡ Prerequisites

1. **MySQL Server 8.0+** running locally or via Docker.
2. **Python 3.10+**
3. Create an empty database:
   ```bash
   mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS sales_dw;"
   ```

---

## 🚀 Quickstart & Execution Guide

### Step 1: Environment Setup
```bash
# Clone or navigate to the directory
cd SQL-Dimensional

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure .env credentials
cp .env.example .env
# Edit .env with your MySQL password
```

### Step 2: Initialize Star Schema (Phase 1)
```bash
mysql -u root -p sales_dw < sql/01_schema.sql
```

### Step 3: Populate 500,000+ Fact Rows (Phase 2)
```bash
python scripts/seed_data.py
```
*Generates 24 consecutive months, 200 products, 1,000 customers, 15 stores, and 500,000 fact rows with seasonal and weekend uplift.*

### Step 4: Run Analytics & Export CSVs (Phases 3–5)
```bash
# Run all reports and export CSVs to output/
python scripts/run_reports.py

# Or run specific reports:
python scripts/run_reports.py --report mom
python scripts/run_reports.py --report rollup
python scripts/run_reports.py --report top_products
```

### Step 5: Query Optimization & EXPLAIN Profiling (Phase 6)
```bash
# 1. Profile baseline queries before indexing
mysql -u root -p sales_dw < sql/06_explain_before.sql

# 2. Apply targeted composite and covering indexes
mysql -u root -p sales_dw < sql/07_indexes.sql

# 3. Profile queries after indexing and compare
mysql -u root -p sales_dw < sql/08_explain_after.sql
```

---

## 📋 Expected Table Row Counts

| Table | Grain / Description | Expected Rows |
|---|---|---|
| `dim_date` | 1 row per calendar day (24 full months) | ~730 |
| `dim_product` | 1 row per product (~6 categories) | ~200 |
| `dim_customer` | 1 row per unique customer | 1,000 |
| `dim_store` | 1 row per retail/online store | 15 |
| `fact_sales` | 1 row per product per order line | **500,000** |

---

## 🔍 Analytical Features Demonstrated

1. **Window Functions**:
   - `ROW_NUMBER()`, `RANK()`, and `DENSE_RANK()` side-by-side tie analysis.
   - `NTILE(4)` store performance quartiles.
   - Running cumulative revenue using `SUM() OVER (PARTITION BY ... ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`.
   - Percentage share of category revenue: `SUM() OVER (PARTITION BY category)`.
   - 3-Month moving average: `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`.

2. **Chained CTEs & MoM Trends**:
   - `monthly_sales` CTE aggregates volume and revenue.
   - `mom_calc` CTE applies `LAG()` for prior month comparison.
   - Guarded division by zero with `NULLIF(prev, 0)`.
   - Categorical trend flag (`Up`, `Down`, `Flat`) with 1% deadband.

3. **Hierarchical ROLLUP**:
   - `GROUP BY d.year, d.quarter, p.category WITH ROLLUP`
   - Clean labels using `GROUPING()` for subtotals and grand totals (`All Quarters`, `All Categories`, `GRAND TOTAL`).
