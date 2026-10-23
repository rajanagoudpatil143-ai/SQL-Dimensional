-- ============================================================================
-- Step 6B: Targeted Indexing Strategy for sales_dw
-- Description: Applies composite, covering, and foreign key secondary indexes
-- on fact_sales to optimize analytics and joins.
-- ============================================================================

USE sales_dw;

-- ----------------------------------------------------------------------------
-- Index 1: Composite Index on (date_key, product_key)
-- Justification:
-- Most data warehouse analytical queries filter on date ranges (e.g. BETWEEN,
-- year, month) and immediately join or aggregate by product or category.
-- Placing date_key first allows the B-tree index to seek directly to the date range,
-- then quickly satisfy the product join without visiting table pages.
-- ----------------------------------------------------------------------------
CREATE INDEX idx_fact_sales_date_product 
ON fact_sales (date_key, product_key);

-- ----------------------------------------------------------------------------
-- Index 2: Secondary Index on customer_key
-- Justification:
-- Accelerates customer demographic, segmentation, and regional RFM/profit queries.
-- Eliminates full table scans when joining fact_sales to dim_customer.
-- ----------------------------------------------------------------------------
CREATE INDEX idx_fact_sales_customer 
ON fact_sales (customer_key);

-- ----------------------------------------------------------------------------
-- Index 3: Secondary Index on store_key
-- Justification:
-- Optimizes store-level running totals, store performance quartiles, and regional
-- store aggregations by enabling index lookups on store keys.
-- ----------------------------------------------------------------------------
CREATE INDEX idx_fact_sales_store 
ON fact_sales (store_key);

-- ----------------------------------------------------------------------------
-- Index 4: Covering / Compound Composite Index for Date-Revenue Analytics
-- Columns: (date_key, sales_amount, profit_amount)
-- Justification:
-- High-frequency time-series queries (such as month-over-month trend and moving
-- averages) only require date_key, sales_amount, and profit_amount.
-- By storing sales_amount and profit_amount in the index, queries can be answered
-- purely from the index pages ("Using index" / Index-Only Scan), completely avoiding
-- the clustered index / base table lookup overhead.
-- ----------------------------------------------------------------------------
CREATE INDEX idx_fact_sales_covering_date_sales 
ON fact_sales (date_key, sales_amount, profit_amount);
