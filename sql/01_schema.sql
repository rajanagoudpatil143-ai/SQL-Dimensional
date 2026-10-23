-- ============================================================================
-- Step 1: Star Schema DDL for sales_dw
-- Description: Creates database sales_dw with 1 central fact table and 4 dimensions.
-- Surrogate integer keys are used for all dimensions.
-- Grain of fact_sales: One row per product per order line.
-- Note: Foreign keys defined. No secondary indexes added to fact_sales yet (unoptimized baseline).
-- ============================================================================

CREATE DATABASE IF NOT EXISTS sales_dw;
USE sales_dw;

-- Drop tables if existing to support clean re-runs (fact table first due to FK constraints)
DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_store;

-- ----------------------------------------------------------------------------
-- 1. dim_date: 24 full consecutive months
-- ----------------------------------------------------------------------------
CREATE TABLE dim_date (
    date_key INT NOT NULL,                     -- Format: YYYYMMDD (e.g., 20240115)
    full_date DATE NOT NULL,
    day_of_week INT NOT NULL,                  -- 1 = Sunday/Monday depending on convention, 1-7
    day_name VARCHAR(10) NOT NULL,             -- 'Monday', 'Tuesday', etc.
    week_of_year INT NOT NULL,                 -- 1 to 53
    month_num INT NOT NULL,                    -- 1 to 12
    month_name VARCHAR(10) NOT NULL,           -- 'January', 'February', etc.
    quarter INT NOT NULL,                      -- 1 to 4
    year INT NOT NULL,                         -- e.g., 2024
    is_weekend TINYINT(1) NOT NULL DEFAULT 0,  -- 1 if Saturday or Sunday, else 0
    PRIMARY KEY (date_key),
    UNIQUE KEY uq_dim_date_full_date (full_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 2. dim_product: ~200 products across 6 categories
-- ----------------------------------------------------------------------------
CREATE TABLE dim_product (
    product_key INT AUTO_INCREMENT NOT NULL,   -- Surrogate Key
    product_id VARCHAR(50) NOT NULL,           -- Natural / Business Key
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL,             -- e.g., Electronics, Apparel, Home & Kitchen
    subcategory VARCHAR(50) NOT NULL,          -- e.g., Audio, Laptops, Cookware
    brand VARCHAR(50) NOT NULL,
    unit_cost DECIMAL(10, 2) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (product_key),
    UNIQUE KEY uq_dim_product_id (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 3. dim_customer: Segments, location details
-- ----------------------------------------------------------------------------
CREATE TABLE dim_customer (
    customer_key INT AUTO_INCREMENT NOT NULL,  -- Surrogate Key
    customer_id VARCHAR(50) NOT NULL,          -- Natural / Business Key
    customer_name VARCHAR(100) NOT NULL,
    segment VARCHAR(30) NOT NULL,              -- Consumer, Corporate, Home Office
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    region VARCHAR(30) NOT NULL,               -- North, South, East, West, Central
    PRIMARY KEY (customer_key),
    UNIQUE KEY uq_dim_customer_id (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 4. dim_store: ~15 stores
-- ----------------------------------------------------------------------------
CREATE TABLE dim_store (
    store_key INT AUTO_INCREMENT NOT NULL,     -- Surrogate Key
    store_name VARCHAR(100) NOT NULL,
    store_type VARCHAR(30) NOT NULL,           -- Online, Mall, Outlet
    city VARCHAR(50) NOT NULL,
    region VARCHAR(30) NOT NULL,
    manager VARCHAR(100) NOT NULL,
    PRIMARY KEY (store_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 5. fact_sales: Central fact table
-- Grain: One row per product per order line
-- ----------------------------------------------------------------------------
CREATE TABLE fact_sales (
    sales_key BIGINT AUTO_INCREMENT NOT NULL,  -- Surrogate PK for fact rows
    date_key INT NOT NULL,                     -- Foreign Key to dim_date
    product_key INT NOT NULL,                  -- Foreign Key to dim_product
    customer_key INT NOT NULL,                 -- Foreign Key to dim_customer
    store_key INT NOT NULL,                    -- Foreign Key to dim_store
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    discount_pct DECIMAL(4, 2) NOT NULL DEFAULT 0.00,
    sales_amount DECIMAL(12, 2) NOT NULL,      -- quantity * unit_price * (1 - discount_pct)
    cost_amount DECIMAL(12, 2) NOT NULL,       -- quantity * unit_cost
    profit_amount DECIMAL(12, 2) NOT NULL,     -- sales_amount - cost_amount
    PRIMARY KEY (sales_key),
    CONSTRAINT fk_sales_date FOREIGN KEY (date_key) REFERENCES dim_date (date_key),
    CONSTRAINT fk_sales_product FOREIGN KEY (product_key) REFERENCES dim_product (product_key),
    CONSTRAINT fk_sales_customer FOREIGN KEY (customer_key) REFERENCES dim_customer (customer_key),
    CONSTRAINT fk_sales_store FOREIGN KEY (store_key) REFERENCES dim_store (store_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
