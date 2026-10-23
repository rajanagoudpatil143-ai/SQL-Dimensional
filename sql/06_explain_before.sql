-- ============================================================================
-- Step 6A: Baseline Execution Plans (EXPLAIN BEFORE INDEXING)
-- Description: Analyzes 3 target queries on an unindexed fact_sales table
-- Database: sales_dw
-- ============================================================================

USE sales_dw;

-- ============================================================================
-- Query 1: Date Range Filter + Product Category Aggregation
-- Purpose: Evaluates scanning fact_sales for a specific 6-month holiday window
-- joins to dim_date and dim_product.
-- ============================================================================
EXPLAIN
SELECT 
    p.category,
    p.brand,
    COUNT(f.sales_key)            AS units_sold_count,
    ROUND(SUM(f.sales_amount), 2) AS total_revenue,
    ROUND(SUM(f.profit_amount), 2) AS total_profit
FROM fact_sales f
JOIN dim_date d    ON f.date_key    = d.date_key
JOIN dim_product p ON f.product_key = p.product_key
WHERE d.date_key BETWEEN 20241001 AND 20241231
GROUP BY p.category, p.brand
ORDER BY total_revenue DESC;

EXPLAIN ANALYZE
SELECT 
    p.category,
    p.brand,
    COUNT(f.sales_key)            AS units_sold_count,
    ROUND(SUM(f.sales_amount), 2) AS total_revenue,
    ROUND(SUM(f.profit_amount), 2) AS total_profit
FROM fact_sales f
JOIN dim_date d    ON f.date_key    = d.date_key
JOIN dim_product p ON f.product_key = p.product_key
WHERE d.date_key BETWEEN 20241001 AND 20241231
GROUP BY p.category, p.brand
ORDER BY total_revenue DESC;


-- ============================================================================
-- Query 2: Customer Segment & Regional Profit Aggregation
-- Purpose: Heavy aggregation joining 500,000 fact rows to dim_customer
-- ============================================================================
EXPLAIN
SELECT 
    c.region,
    c.segment,
    COUNT(DISTINCT c.customer_key) AS active_customers,
    COUNT(f.sales_key)             AS total_orders,
    ROUND(SUM(f.sales_amount), 2)  AS total_sales,
    ROUND(SUM(f.profit_amount), 2) AS total_profit
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.region, c.segment
ORDER BY total_profit DESC;

EXPLAIN ANALYZE
SELECT 
    c.region,
    c.segment,
    COUNT(DISTINCT c.customer_key) AS active_customers,
    COUNT(f.sales_key)             AS total_orders,
    ROUND(SUM(f.sales_amount), 2)  AS total_sales,
    ROUND(SUM(f.profit_amount), 2) AS total_profit
FROM fact_sales f
JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.region, c.segment
ORDER BY total_profit DESC;


-- ============================================================================
-- Query 3: Multi-Year Monthly MoM Sales Trend
-- Purpose: Aggregation across date and fact_sales with window functions
-- ============================================================================
EXPLAIN
WITH monthly_sales AS (
    SELECT 
        d.year,
        d.month_num,
        ROUND(SUM(f.sales_amount), 2) AS monthly_revenue
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month_num
)
SELECT 
    year,
    month_num,
    monthly_revenue,
    LAG(monthly_revenue, 1) OVER (ORDER BY year, month_num) AS prev_revenue
FROM monthly_sales;

EXPLAIN ANALYZE
WITH monthly_sales AS (
    SELECT 
        d.year,
        d.month_num,
        ROUND(SUM(f.sales_amount), 2) AS monthly_revenue
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month_num
)
SELECT 
    year,
    month_num,
    monthly_revenue,
    LAG(monthly_revenue, 1) OVER (ORDER BY year, month_num) AS prev_revenue
FROM monthly_sales;
