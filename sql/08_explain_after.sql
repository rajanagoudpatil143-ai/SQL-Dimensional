-- ============================================================================
-- Step 6C: Post-Optimization Execution Plans (EXPLAIN AFTER INDEXING)
-- Description: Re-evaluates the same 3 queries to measure index utilization,
-- reduction in rows examined, and elapsed execution time.
-- Database: sales_dw
-- ============================================================================

USE sales_dw;

-- ============================================================================
-- Query 1: Date Range Filter + Product Category Aggregation
-- Expected Benefit: Uses idx_fact_sales_date_product or idx_fact_sales_covering_date_sales.
-- Eliminates full table scan on fact_sales.
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
-- Expected Benefit: Uses idx_fact_sales_customer to eliminate unindexed scans.
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
-- Expected Benefit: Uses covering index idx_fact_sales_covering_date_sales.
-- Shows 'Using index' in Extra column (Index-Only Scan), minimizing disk I/O.
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
