-- ============================================================================
-- Step 2 (SQL alternative / Date Dimension loader):
-- Populate dim_date with 24 consecutive months using recursive CTE
-- ============================================================================

USE sales_dw;

-- Ensure date dimension is cleared if reloading
DELETE FROM dim_date;

INSERT INTO dim_date (
    date_key,
    full_date,
    day_of_week,
    day_name,
    week_of_year,
    month_num,
    month_name,
    quarter,
    year,
    is_weekend
)
WITH RECURSIVE date_series AS (
    -- Start date: 1st of month 24 months ago ending at the end of last month
    SELECT 
        DATE_SUB(DATE_SUB(LAST_DAY(CURRENT_DATE - INTERVAL 1 MONTH), INTERVAL 24 MONTH), INTERVAL -1 DAY) AS full_date
    UNION ALL
    SELECT 
        full_date + INTERVAL 1 DAY
    FROM date_series
    WHERE full_date + INTERVAL 1 DAY <= LAST_DAY(CURRENT_DATE - INTERVAL 1 MONTH)
)
SELECT 
    CAST(DATE_FORMAT(full_date, '%Y%m%d') AS UNSIGNED) AS date_key,
    full_date,
    DAYOFWEEK(full_date) AS day_of_week,       -- 1=Sunday, 7=Saturday
    DAYNAME(full_date) AS day_name,
    WEEKOFYEAR(full_date) AS week_of_year,
    MONTH(full_date) AS month_num,
    MONTHNAME(full_date) AS month_name,
    QUARTER(full_date) AS quarter,
    YEAR(full_date) AS year,
    CASE WHEN DAYOFWEEK(full_date) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM date_series;
