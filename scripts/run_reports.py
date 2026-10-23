#!/usr/bin/env python3
"""
Report Runner & CSV Exporter for sales_dw
Executes report queries, prints formatted tables in terminal,
measures execution duration, and saves results to output/ directory as CSV.

Usage:
  python scripts/run_reports.py                 # Runs all reports
  python scripts/run_reports.py --report mom    # Runs MoM report only
  python scripts/run_reports.py --report rollup # Runs Rollup report only
  python scripts/run_reports.py --report window # Runs Window functions report
  python scripts/run_reports.py --report list   # Lists available reports
"""

import os
import sys
import time
import csv
import argparse
from dotenv import load_dotenv
import mysql.connector
from tabulate import tabulate

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "sales_dw")

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "output")
os.makedirs(OUTPUT_DIR, exist_ok=True)


REPORTS = {
    "top_products": {
        "name": "Top 5 Products by Revenue per Category (Window Functions)",
        "file": "top_5_products_by_category.csv",
        "sql": """
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
        """
    },
    "top_customers": {
        "name": "Top 3 Customers by Profit per Region",
        "file": "top_3_customers_by_region.csv",
        "sql": """
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
        """
    },
    "store_quartiles": {
        "name": "Store Revenue Quartiles (NTILE 4)",
        "file": "store_revenue_quartiles.csv",
        "sql": """
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
        """
    },
    "mom": {
        "name": "Month-Over-Month (MoM) Growth & Trend Report",
        "file": "mom_revenue_growth_report.csv",
        "sql": """
        WITH monthly_sales AS (
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
        SELECT 
            year,
            month_num,
            month_name,
            order_line_count,
            current_revenue,
            prev_month_revenue,
            ROUND(current_revenue - prev_month_revenue, 2) AS absolute_revenue_change,
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
        """
    },
    "rollup": {
        "name": "Hierarchical ROLLUP: Year -> Quarter -> Category",
        "file": "rollup_year_quarter_category.csv",
        "sql": """
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
        """
    },
    "moving_avg": {
        "name": "3-Month Moving Average of Monthly Revenue",
        "file": "moving_avg_3_month_report.csv",
        "sql": """
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
            ), 2) AS moving_avg_3_month
        FROM monthly_total_sales
        ORDER BY year, month_num;
        """
    }
}


def get_connection():
    return mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME
    )


def execute_report(cursor, key, config):
    print(f"\n{'='*80}")
    print(f"📊 REPORT: {config['name']}")
    print(f"{'='*80}")

    start_time = time.time()
    cursor.execute(config["sql"])
    columns = [col[0] for col in cursor.description]
    rows = cursor.fetchall()
    elapsed_ms = (time.time() - start_time) * 1000

    # Print formatted table (first 25 rows if large)
    display_rows = rows[:25]
    print(tabulate(display_rows, headers=columns, tablefmt="psql"))
    if len(rows) > 25:
        print(f"   ... and {len(rows) - 25} more rows ({len(rows)} total rows).")

    print(f"\n⏱️  Execution Time: {elapsed_ms:.2f} ms | Rows Returned: {len(rows)}")

    # Export to CSV
    csv_path = os.path.join(OUTPUT_DIR, config["file"])
    with open(csv_path, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        writer.writerows(rows)
    print(f"💾 Exported CSV to: {os.path.relpath(csv_path)}")


def main():
    parser = argparse.ArgumentParser(description="Run SQL Dimensional Reports")
    parser.add_argument(
        "--report",
        choices=list(REPORTS.keys()) + ["all", "list"],
        default="all",
        help="Specify report to run or 'list' to see choices"
    )
    args = parser.parse_args()

    if args.report == "list":
        print("\nAvailable Reports:")
        for k, v in REPORTS.items():
            print(f"  • {k:15}: {v['name']}")
        return

    try:
        conn = get_connection()
        cursor = conn.cursor()

        if args.report == "all":
            for key, config in REPORTS.items():
                execute_report(cursor, key, config)
        else:
            execute_report(cursor, args.report, REPORTS[args.report])

        cursor.close()
        conn.close()
        print("\n🎉 All requested reports finished successfully!")

    except mysql.connector.Error as err:
        print(f"\n❌ Database error: {err}")
        sys.exit(1)


if __name__ == "__main__":
    main()
