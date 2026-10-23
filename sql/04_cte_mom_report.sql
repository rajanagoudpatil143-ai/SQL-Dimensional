-- ============================================================================
-- Step 4: CTE Month-Over-Month (MoM) Growth & Trend Report
-- Description: Chained Common Table Expressions (CTEs) calculating revenue,
-- profit, order counts, previous month lag, MoM % change, and trend direction.
-- Database: sales_dw
-- ============================================================================

USE sales_dw;

-- ============================================================================
-- DESIGN NOTE: When is a CTE preferable to a Subquery or Temp Table?
-- ----------------------------------------------------------------------------
-- 1. CTE vs Nested Subquery:
--    - Readability & Maintainability: CTEs read top-to-bottom in logical sequence
--      rather than inside-out.
--    - Reusability: A named CTE can be referenced multiple times within the same
--      statement without repeating code or duplicating joins.
--    - Self-referencing: CTEs can be RECURSIVE (e.g. hierarchical org trees, date generators).
--
-- 2. CTE vs Temporary Table:
--    - Lifecycle & Overhead: CTEs exist only during query execution and don't require
--      explicit table creation, disk writes (unless materialized), or DROP TABLE cleanups.
--    - When Temp Tables Win: For massive multi-step ETL pipelines where intermediate results
--      need manual indexing (e.g., CREATE INDEX on temp_table) or are reused across multiple
--      distinct transactions.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Version 1: Overall Monthly MoM Growth Report
-- ----------------------------------------------------------------------------
WITH monthly_sales AS (
    -- CTE 1: Aggregated revenue, profit, and order-line count per year and month
    SELECT 
        d.year,
        d.month_num,
        d.month_name,
        ROUND(SUM(f.sales_amount), 2)  AS current_revenue,
        ROUND(SUM(f.profit_amount), 2) AS current_profit,
        COUNT(f.sales_key)             AS order_line_count
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month_num, d.month_name
),
mom_calc AS (
    -- CTE 2: Look back to previous month using LAG()
    SELECT 
        year,
        month_num,
        month_name,
        current_revenue,
        current_profit,
        order_line_count,
        LAG(current_revenue, 1) OVER (ORDER BY year, month_num) AS prev_month_revenue,
        LAG(current_profit, 1)  OVER (ORDER BY year, month_num) AS prev_month_profit
    FROM monthly_sales
)
-- Final SELECT: Calculate absolute change, % change, and categorical trend flag
SELECT 
    year,
    month_num,
    month_name,
    order_line_count,
    current_revenue,
    prev_month_revenue,
    ROUND(current_revenue - prev_month_revenue, 2) AS absolute_revenue_change,
    -- Guard against division by zero using NULLIF
    ROUND(
        100.0 * (current_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0), 
        2
    ) AS mom_revenue_growth_pct,
    current_profit,
    prev_month_profit,
    CASE 
        WHEN prev_month_revenue IS NULL THEN 'Baseline'
        WHEN current_revenue > prev_month_revenue * 1.01 THEN 'Up'
        WHEN current_revenue < prev_month_revenue * 0.99 THEN 'Down'
        ELSE 'Flat'
    END AS trend_flag
FROM mom_calc
ORDER BY year, month_num;


-- ----------------------------------------------------------------------------
-- Version 2: Category-Level Month-Over-Month Report
-- Partitioning the LAG window by product category
-- ----------------------------------------------------------------------------
WITH category_monthly_sales AS (
    SELECT 
        p.category,
        d.year,
        d.month_num,
        d.month_name,
        ROUND(SUM(f.sales_amount), 2) AS category_revenue,
        ROUND(SUM(f.profit_amount), 2) AS category_profit,
        COUNT(f.sales_key) AS line_items
    FROM fact_sales f
    JOIN dim_date d    ON f.date_key    = d.date_key
    JOIN dim_product p ON f.product_key = p.product_key
    GROUP BY p.category, d.year, d.month_num, d.month_name
),
category_mom_calc AS (
    SELECT 
        category,
        year,
        month_num,
        month_name,
        category_revenue,
        category_profit,
        line_items,
        LAG(category_revenue, 1) OVER (
            PARTITION BY category 
            ORDER BY year, month_num
        ) AS prev_category_revenue
    FROM category_monthly_sales
)
SELECT 
    category,
    year,
    month_num,
    month_name,
    category_revenue,
    prev_category_revenue,
    ROUND(category_revenue - prev_category_revenue, 2) AS abs_change,
    ROUND(
        100.0 * (category_revenue - prev_category_revenue) / NULLIF(prev_category_revenue, 0),
        2
    ) AS mom_growth_pct,
    CASE 
        WHEN prev_category_revenue IS NULL THEN 'Baseline'
        WHEN category_revenue > prev_category_revenue * 1.01 THEN 'Up'
        WHEN category_revenue < prev_category_revenue * 0.99 THEN 'Down'
        ELSE 'Flat'
    END AS category_trend
FROM category_mom_calc
ORDER BY category, year, month_num;
