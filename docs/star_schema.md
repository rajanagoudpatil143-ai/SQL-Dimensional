# 🌟 Star Schema Architecture & Dimensional Design

## 1. Overview
The `sales_dw` database implements a classic dimensional Star Schema optimized for online analytical processing (OLAP), reporting, and decision-support systems.

At the core is the **`fact_sales`** table representing discrete transactional events (order line items), surrounded by four conformed dimension tables providing analytical context:
- **`dim_date`**: Time dimension covering 24 consecutive months down to daily grain with calendar hierarchies.
- **`dim_product`**: Product catalog across 6 major merchandising categories and brands.
- **`dim_customer`**: Customer demographic profiles, segments (Consumer, Corporate, Home Office), and geographic location.
- **`dim_store`**: Retail channel entities (Online portals, Mall locations, and Outlet venues).

---

## 2. Mermaid Entity Relationship Diagram (ERD)

```mermaid
erDiagram
    dim_date ||--o{ fact_sales : "recorded_on"
    dim_product ||--o{ fact_sales : "includes"
    dim_customer ||--o{ fact_sales : "purchased_by"
    dim_store ||--o{ fact_sales : "transacted_at"

    dim_date {
        INT date_key PK "YYYYMMDD"
        DATE full_date "Unique"
        INT day_of_week "1=Sun, 7=Sat"
        VARCHAR day_name
        INT week_of_year "1-53"
        INT month_num "1-12"
        VARCHAR month_name
        INT quarter "1-4"
        INT year "Calendar Year"
        TINYINT is_weekend "1 if Sat/Sun"
    }

    dim_product {
        INT product_key PK "Surrogate Key"
        VARCHAR product_id "Natural Key (Unique)"
        VARCHAR product_name
        VARCHAR category "6 major categories"
        VARCHAR subcategory
        VARCHAR brand
        DECIMAL unit_cost
        DECIMAL unit_price
    }

    dim_customer {
        INT customer_key PK "Surrogate Key"
        VARCHAR customer_id "Natural Key (Unique)"
        VARCHAR customer_name
        VARCHAR segment "Consumer, Corporate, Home Office"
        VARCHAR city
        VARCHAR state
        VARCHAR region "North, South, East, West, Central"
    }

    dim_store {
        INT store_key PK "Surrogate Key"
        VARCHAR store_name
        VARCHAR store_type "Online, Mall, Outlet"
        VARCHAR city
        VARCHAR region
        VARCHAR manager
    }

    fact_sales {
        BIGINT sales_key PK "Surrogate Fact Key"
        INT date_key FK "References dim_date"
        INT product_key FK "References dim_product"
        INT customer_key FK "References dim_customer"
        INT store_key FK "References dim_store"
        INT quantity "Units purchased"
        DECIMAL unit_price "Price at transaction"
        DECIMAL discount_pct "0.00 to 0.30"
        DECIMAL sales_amount "qty * price * (1 - disc)"
        DECIMAL cost_amount "qty * unit_cost"
        DECIMAL profit_amount "sales_amount - cost_amount"
    }
```

---

## 3. Grain of the Fact Table
- **Grain**: **One row per product per order line item.**
- Every row captures the sale of a specific product quantity sold to a customer at a given store location on a specific calendar date.
- Additive metrics: `quantity`, `sales_amount`, `cost_amount`, `profit_amount` can be aggregated across any dimension without double-counting.

---

## 4. Star Schema vs. 3NF (Normalized) OLTP Design

| Characteristic | Star Schema (OLAP) | Normalized 3NF (OLTP) |
|---|---|---|
| **Primary Goal** | High-speed analytical queries, aggregations, and business intelligence | Fast, transactional writes, concurrency, and eliminating update anomalies |
| **Number of Joins** | Minimal (typically 1 fact joined to 1-4 dimension tables) | High (joins across 10-25 tables to assemble an invoice or report) |
| **Query Complexity** | Simple, intuitive SQL with standard GROUP BY / Window functions | Complex queries with deep subqueries, self-joins, and junction tables |
| **Data Redundancy** | Controlled denormalization in dimensions (e.g. category name stored directly) | Zero redundancy (tables strictly normalized up to 3rd normal form) |
| **Indexing Strategy** | Fact foreign keys, composite range indexes, and covering indexes | B-tree indexes focused on single-row lookups and primary keys |
| **Optimizer Execution** | Predictable hash joins and star-join transformations | Complex nested loops and multi-table join trees |
