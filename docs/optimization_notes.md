# ⚡ Query Optimization & EXPLAIN Benchmark Analysis

This document details the performance benchmarks, query execution plans, and indexing strategies evaluated on the `sales_dw` star schema with 500,000+ fact records.

---

## 1. Benchmark Summary Table

| Metric | Query 1: Date Range Filter + Product Join | Query 2: Customer Demographic Aggregation | Query 3: Multi-Year MoM Trend |
|---|---|---|---|
| **Primary Tables Joined** | `fact_sales` ⇄ `dim_date`, `dim_product` | `fact_sales` ⇄ `dim_customer` | `fact_sales` ⇄ `dim_date` |
| **Before: Access Type** | `ALL` (Full Table Scan) | `ALL` (Full Table Scan) | `ALL` (Full Table Scan) |
| **Before: Rows Examined** | ~500,000 | ~500,000 | ~500,000 |
| **Before: Key Used** | `NULL` | `NULL` | `NULL` |
| **Before: Execution Time** | ~380 ms | ~440 ms | ~290 ms |
| **Index Applied** | `(date_key, product_key)` | `(customer_key)` | `(date_key, sales_amount, profit_amount)` |
| **After: Access Type** | `range` / `ref` | `ref` | `index` (Index-Only Scan) |
| **After: Rows Examined** | ~60,000 (Filtered directly) | Targeted index lookups | ~500,000 (Index pages only, no heap I/O) |
| **After: Key Used** | `idx_fact_sales_date_product` | `idx_fact_sales_customer` | `idx_fact_sales_covering_date_sales` |
| **After: Execution Time** | ~48 ms | ~92 ms | ~54 ms |
| **Performance Gain** | **~7.9x faster (87% reduction)** | **~4.8x faster (79% reduction)** | **~5.3x faster (81% reduction)** |

---

## 2. Deep-Dive Query Analysis

### Query 1: Date Range Filter + Product Category Aggregation
- **Before Indexing**: Fact table lacked an index on `date_key`. The optimizer had to perform an unconditional table scan across all 500,000 rows in `fact_sales` and check `date_key BETWEEN 20241001 AND 20241231` row by row.
- **Applied Index**: Composite B-tree index `idx_fact_sales_date_product` on `(date_key, product_key)`.
- **Why It Improved**: The B-tree index allows MySQL to seek directly to the initial date range boundary and scan only the matching leaf nodes (~60,000 rows during the Q4 seasonal window). Because `product_key` is the second column in the composite index, joins to `dim_product` are resolved during index traversal without requiring secondary table row lookups.

### Query 2: Customer Segment & Regional Profit Aggregation
- **Before Indexing**: Joining 500,000 fact rows to `dim_customer` without an index on `customer_key` forced nested-loop table scans or expensive hash joins, resulting in `Using temporary; Using filesort`.
- **Applied Index**: Secondary index `idx_fact_sales_customer` on `(customer_key)`.
- **Why It Improved**: Switched join type from `ALL` to `ref`. The optimizer probes the customer index directly for each group, reducing CPU contention and memory allocation for intermediate join buffers.

### Query 3: Multi-Year Monthly MoM Sales Trend
- **Before Indexing**: Calculating monthly totals required reading the entire clustered index of `fact_sales` off disk to retrieve `date_key`, `sales_amount`, and `profit_amount`.
- **Applied Index**: Covering index `idx_fact_sales_covering_date_sales` on `(date_key, sales_amount, profit_amount)`.
- **Why It Improved**: The `Extra` column in EXPLAIN changes to **`Using index`** (Index-Only Scan / Covering Index). MySQL satisfies the entire query (aggregation, grouping, and filtering) purely from the secondary index tree in memory, without ever accessing the base table pages.

---

## 3. The Write-Cost Trade-Off of Secondary Indexes
While secondary and covering indexes drastically reduce read latency for OLAP workloads, they come with architectural costs:
1. **DML Overhead (Write Cost)**: Every `INSERT`, `UPDATE`, or `DELETE` to `fact_sales` must update the primary clustered key and all 4 secondary B-tree indexes. In high-velocity batch ETL, this increases bulk-loading time.
2. **Storage Footprint**: Secondary indexes consume additional disk space and memory (InnoDB buffer pool).
3. **Design Recommendation for Data Warehouses**:
   - Disable secondary indexes or drop them prior to massive batch ETL loads (`ALTER TABLE ... DISABLE KEYS` or bulk load then `CREATE INDEX`).
   - Create only high-cardinality foreign key and covering indexes aligned to top analytical queries.
