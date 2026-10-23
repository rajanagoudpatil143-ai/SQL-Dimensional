-- ============================================================================
-- Step 5: Hierarchical ROLLUP Aggregation Reports
-- Description: Multi-level aggregation using GROUP BY ... WITH ROLLUP and GROUPING()
-- Database: sales_dw
-- ============================================================================

USE sales_dw;

-- ============================================================================
-- VERIFICATION NOTE:
-- The grand total calculated by the ROLLUP queries below must exactly equal:
-- SELECT ROUND(SUM(sales_amount), 2) AS grand_total FROM fact_sales;
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Report 1: Revenue and Profit by Year, Quarter, and Product Category
-- Hierarchy: Year -> Quarter -> Category -> Grand Total
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN GROUPING(d.year) = 1 THEN 'GRAND TOTAL'
        ELSE CAST(d.year AS CHAR)
    END AS report_year,
    
    CASE 
        WHEN GROUPING(d.quarter) = 1 AND GROUPING(d.year) = 0 THEN 'All Quarters'
        WHEN GROUPING(d.year) = 1 THEN '-'
        ELSE CONCAT('Q', d.quarter)
    END AS report_quarter,
    
    CASE 
        WHEN GROUPING(p.category) = 1 AND GROUPING(d.quarter) = 0 THEN 'All Categories'
        WHEN GROUPING(d.quarter) = 1 THEN '-'
        ELSE p.category
    END AS report_category,
    
    COUNT(f.sales_key)             AS total_order_lines,
    SUM(f.quantity)                AS total_units_sold,
    ROUND(SUM(f.sales_amount), 2)  AS total_sales_amount,
    ROUND(SUM(f.cost_amount), 2)   AS total_cost_amount,
    ROUND(SUM(f.profit_amount), 2) AS total_profit_amount,
    ROUND(100.0 * SUM(f.profit_amount) / NULLIF(SUM(f.sales_amount), 0), 2) AS profit_margin_pct
FROM fact_sales f
JOIN dim_date d    ON f.date_key    = d.date_key
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY d.year, d.quarter, p.category WITH ROLLUP;


-- ----------------------------------------------------------------------------
-- Report 2: Revenue and Profit by Region, Store, and Product Category
-- Hierarchy: Region -> Store -> Category -> Grand Total
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN GROUPING(s.region) = 1 THEN 'GRAND TOTAL'
        ELSE s.region
    END AS report_region,
    
    CASE 
        WHEN GROUPING(s.store_name) = 1 AND GROUPING(s.region) = 0 THEN 'All Stores'
        WHEN GROUPING(s.region) = 1 THEN '-'
        ELSE s.store_name
    END AS report_store,
    
    CASE 
        WHEN GROUPING(p.category) = 1 AND GROUPING(s.store_name) = 0 THEN 'All Categories'
        WHEN GROUPING(s.store_name) = 1 THEN '-'
        ELSE p.category
    END AS report_category,
    
    COUNT(f.sales_key)             AS total_order_lines,
    ROUND(SUM(f.sales_amount), 2)  AS total_revenue,
    ROUND(SUM(f.profit_amount), 2) AS total_profit
FROM fact_sales f
JOIN dim_store s   ON f.store_key   = s.store_key
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY s.region, s.store_name, p.category WITH ROLLUP;
