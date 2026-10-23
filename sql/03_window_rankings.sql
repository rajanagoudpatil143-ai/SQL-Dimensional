-- ============================================================================
-- Step 3: Window Function Rankings and Analytic Reports
-- Description: 6 advanced analytical SQL queries using window functions
-- Database: sales_dw
-- ============================================================================

USE sales_dw;

-- ----------------------------------------------------------------------------
-- Query 1: Top 5 products by revenue within each category
-- Business Question: What are the top 5 highest-grossing products in each category,
-- and how do RANK(), DENSE_RANK(), and ROW_NUMBER() evaluate potential ties?
--
-- Explanation of differences on ties:
-- - ROW_NUMBER(): Assigns a unique, consecutive integer to every row (e.g., 1, 2, 3, 4).
--   Ties are broken arbitrarily based on the physical ordering or engine tiebreaker.
-- - RANK(): Assigns the same rank to ties, but leaves gaps in the sequence afterward
--   (e.g., 1, 2, 2, 4 - skips rank 3).
-- - DENSE_RANK(): Assigns the same rank to ties without skipping subsequent numbers
--   (e.g., 1, 2, 2, 3 - dense sequence with no gaps).
-- ----------------------------------------------------------------------------
WITH product_category_revenue AS (
    SELECT 
        p.category,
        p.product_key,
        p.product_name,
        p.brand,
        ROUND(SUM(f.sales_amount), 2) AS total_revenue
    FROM fact_sales f
    JOIN dim_product p ON f.product_key = p.product_key
    GROUP BY p.category, p.product_key, p.product_name, p.brand
),
ranked_products AS (
    SELECT 
        category,
        product_key,
        product_name,
        brand,
        total_revenue,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS row_num,
        RANK()       OVER (PARTITION BY category ORDER BY total_revenue DESC) AS rank_pos,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS dense_rank_pos
    FROM product_category_revenue
)
SELECT 
    category,
    row_num,
    rank_pos,
    dense_rank_pos,
    product_name,
    brand,
    total_revenue
FROM ranked_products
WHERE dense_rank_pos <= 5
ORDER BY category, dense_rank_pos, product_name;


-- ----------------------------------------------------------------------------
-- Query 2: Top 3 customers by profit within each geographic region
-- Business Question: Who are the top 3 most profitable customers in each region?
-- Uses ROW_NUMBER() over PARTITION BY region to return exactly 3 top customers per region.
-- ----------------------------------------------------------------------------
WITH customer_regional_profit AS (
    SELECT 
        c.region,
        c.customer_key,
        c.customer_name,
        c.segment,
        c.city,
        c.state,
        ROUND(SUM(f.profit_amount), 2) AS total_profit,
        ROUND(SUM(f.sales_amount), 2)  AS total_sales,
        COUNT(f.sales_key)             AS total_orders
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_key = c.customer_key
    GROUP BY c.region, c.customer_key, c.customer_name, c.segment, c.city, c.state
),
ranked_customers AS (
    SELECT 
        region,
        customer_name,
        segment,
        city,
        state,
        total_profit,
        total_sales,
        total_orders,
        ROW_NUMBER() OVER (PARTITION BY region ORDER BY total_profit DESC) AS rank_in_region
    FROM customer_regional_profit
)
SELECT 
    region,
    rank_in_region,
    customer_name,
    segment,
    city,
    state,
    total_profit,
    total_sales,
    total_orders
FROM ranked_customers
WHERE rank_in_region <= 3
ORDER BY region, rank_in_region;


-- ----------------------------------------------------------------------------
-- Query 3: Store revenue quartiles using NTILE(4)
-- Business Question: How do our stores segment into 4 performance quartiles (Q1 Top 25%
-- to Q4 Bottom 25%) based on overall generated revenue?
-- ----------------------------------------------------------------------------
WITH store_revenues AS (
    SELECT 
        s.store_key,
        s.store_name,
        s.store_type,
        s.region,
        s.city,
        ROUND(SUM(f.sales_amount), 2)  AS total_revenue,
        ROUND(SUM(f.profit_amount), 2) AS total_profit,
        COUNT(f.sales_key)             AS transaction_count
    FROM fact_sales f
    JOIN dim_store s ON f.store_key = s.store_key
    GROUP BY s.store_key, s.store_name, s.store_type, s.region, s.city
)
SELECT 
    NTILE(4) OVER (ORDER BY total_revenue DESC) AS performance_quartile,
    store_name,
    store_type,
    region,
    city,
    total_revenue,
    total_profit,
    transaction_count
FROM store_revenues
ORDER BY performance_quartile ASC, total_revenue DESC;


-- ----------------------------------------------------------------------------
-- Query 4: Running total of monthly revenue per store
-- Business Question: What is the cumulative month-by-month revenue progression for
-- each store across the 24-month period?
-- Uses SUM() OVER (PARTITION BY store ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
-- ----------------------------------------------------------------------------
WITH monthly_store_sales AS (
    SELECT 
        s.store_key,
        s.store_name,
        d.year,
        d.month_num,
        d.month_name,
        ROUND(SUM(f.sales_amount), 2) AS monthly_revenue
    FROM fact_sales f
    JOIN dim_store s ON f.store_key = s.store_key
    JOIN dim_date d  ON f.date_key  = d.date_key
    GROUP BY s.store_key, s.store_name, d.year, d.month_num, d.month_name
)
SELECT 
    store_name,
    year,
    month_num,
    month_name,
    monthly_revenue,
    ROUND(SUM(monthly_revenue) OVER (
        PARTITION BY store_key 
        ORDER BY year, month_num 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS cumulative_running_revenue
FROM monthly_store_sales
ORDER BY store_name, year, month_num;


-- ----------------------------------------------------------------------------
-- Query 5: Each product's share of its category revenue
-- Business Question: What percentage contribution does each individual product make
-- toward its parent category's total sales volume?
-- Uses SUM() OVER (PARTITION BY category)
-- ----------------------------------------------------------------------------
WITH product_summary AS (
    SELECT 
        p.category,
        p.product_key,
        p.product_name,
        p.brand,
        ROUND(SUM(f.sales_amount), 2) AS product_revenue
    FROM fact_sales f
    JOIN dim_product p ON f.product_key = p.product_key
    GROUP BY p.category, p.product_key, p.product_name, p.brand
)
SELECT 
    category,
    product_name,
    brand,
    product_revenue,
    ROUND(SUM(product_revenue) OVER (PARTITION BY category), 2) AS category_total_revenue,
    ROUND(100.0 * product_revenue / SUM(product_revenue) OVER (PARTITION BY category), 2) AS revenue_share_pct
FROM product_summary
ORDER BY category, revenue_share_pct DESC;


-- ----------------------------------------------------------------------------
-- Query 6: 3-month moving average of monthly company revenue
-- Business Question: What is the smoothed 3-month moving average of overall revenue
-- across all stores to identify seasonal velocity trends?
-- Uses ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
-- ----------------------------------------------------------------------------
WITH monthly_total_sales AS (
    SELECT 
        d.year,
        d.month_num,
        d.month_name,
        ROUND(SUM(f.sales_amount), 2) AS total_monthly_revenue,
        COUNT(f.sales_key)            AS total_order_lines
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month_num, d.month_name
)
SELECT 
    year,
    month_num,
    month_name,
    total_monthly_revenue,
    ROUND(AVG(total_monthly_revenue) OVER (
        ORDER BY year, month_num
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3_month,
    ROW_NUMBER() OVER (ORDER BY year, month_num) AS month_index
FROM monthly_total_sales
ORDER BY year, month_num;
