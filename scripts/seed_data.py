#!/usr/bin/env python3
"""
Seed Data Script for sales_dw
Populates:
  - dim_date (24 consecutive months ending last month)
  - dim_product (~200 products across 6 categories)
  - dim_customer (~1000 customers across segments and regions)
  - dim_store (~15 stores)
  - fact_sales (500,000+ realistic rows in batches of 10,000)

Features:
  - Fixed seed for reproducible results
  - Realistic seasonal peaks (November/December uplift)
  - Weekend uplift
  - Pareto/Zipf-like distribution for top-selling products
  - Data integrity validation (verifies counts & checks for orphaned foreign keys)
"""

import os
import sys
import random
import datetime
from decimal import Decimal, ROUND_HALF_UP
from dotenv import load_dotenv
import mysql.connector
from faker import Faker

# Load environment variables
load_dotenv()

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "sales_dw")

# Set random seed for reproducibility
RANDOM_SEED = 42
random.seed(RANDOM_SEED)
fake = Faker()
Faker.seed(RANDOM_SEED)

TOTAL_FACT_ROWS = 500000
BATCH_SIZE = 10000


def get_connection():
    try:
        conn = mysql.connector.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            autocommit=False
        )
        return conn
    except mysql.connector.Error as err:
        print(f"❌ Database connection failed: {err}")
        print("Please verify your .env file credentials and MySQL server status.")
        sys.exit(1)


def seed_date_dimension(cursor):
    print("⏳ Populating dim_date (24 months)...")
    today = datetime.date.today()
    # End date: Last day of the previous month
    first_of_this_month = today.replace(day=1)
    end_date = first_of_this_month - datetime.timedelta(days=1)
    
    # Start date: 24 full months prior (approx 730 days)
    # 24 months back from first_of_this_month
    year = first_of_this_month.year - 2
    month = first_of_this_month.month
    start_date = datetime.date(year, month, 1)

    dates = []
    curr = start_date
    while curr <= end_date:
        date_key = int(curr.strftime("%Y%m%d"))
        day_of_week = curr.isoweekday() % 7 + 1  # 1=Sunday, 7=Saturday (MySQL standard DAYOFWEEK)
        day_name = curr.strftime("%A")
        week_of_year = int(curr.strftime("%V"))
        month_num = curr.month
        month_name = curr.strftime("%B")
        quarter = (curr.month - 1) // 3 + 1
        year_num = curr.year
        is_weekend = 1 if curr.weekday() in (5, 6) else 0  # Saturday/Sunday

        dates.append((
            date_key, curr, day_of_week, day_name, week_of_year,
            month_num, month_name, quarter, year_num, is_weekend
        ))
        curr += datetime.timedelta(days=1)

    insert_query = """
    INSERT INTO dim_date (
        date_key, full_date, day_of_week, day_name, week_of_year,
        month_num, month_name, quarter, year, is_weekend
    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(insert_query, dates)
    print(f"✅ Loaded {len(dates)} days into dim_date ({start_date} to {end_date}).")
    return dates


def seed_product_dimension(cursor):
    print("⏳ Populating dim_product (~200 products across 6 categories)...")
    categories_schema = {
        "Electronics": ["Audio", "Laptops", "Smartphones", "Accessories", "Wearables"],
        "Home & Kitchen": ["Cookware", "Small Appliances", "Storage", "Bedding", "Furniture"],
        "Apparel": ["Men's Clothing", "Women's Clothing", "Footwear", "Activewear"],
        "Office Supplies": ["Stationery", "Desk Accessories", "Paper Products", "Binders"],
        "Sports & Outdoors": ["Fitness Gear", "Camping", "Cycling", "Team Sports"],
        "Health & Beauty": ["Personal Care", "Skincare", "Vitamins", "Haircare"]
    }

    brands = [
        "Apex", "Nova", "Zenith", "Quantum", "Vanguard", 
        "Echo", "Lumina", "Aero", "Summit", "Pulse", "Titan", "Solstice"
    ]

    products = []
    prod_id = 1
    for category, subcategories in categories_schema.items():
        # ~33-35 products per category to reach ~200
        for subcat in subcategories:
            num_items = random.randint(6, 8)
            for _ in range(num_items):
                brand = random.choice(brands)
                name = f"{brand} {fake.color_name().capitalize()} {subcat[:-1] if subcat.endswith('s') else subcat} {prod_id}"
                unit_cost = round(random.uniform(5.0, 450.0), 2)
                # Markup 25% to 85%
                markup = random.uniform(1.25, 1.85)
                unit_price = round(unit_cost * markup, 2)

                products.append((
                    f"PROD-{prod_id:04d}",
                    name,
                    category,
                    subcat,
                    brand,
                    unit_cost,
                    unit_price
                ))
                prod_id += 1

    insert_query = """
    INSERT INTO dim_product (
        product_id, product_name, category, subcategory, brand, unit_cost, unit_price
    ) VALUES (%s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(insert_query, products)
    print(f"✅ Loaded {len(products)} products into dim_product.")


def seed_customer_dimension(cursor):
    print("⏳ Populating dim_customer (~1000 customers)...")
    segments = ["Consumer", "Corporate", "Home Office"]
    segment_weights = [0.60, 0.25, 0.15]
    regions = ["East", "West", "Central", "South", "North"]

    customers = []
    for i in range(1, 1001):
        segment = random.choices(segments, weights=segment_weights)[0]
        region = random.choice(regions)
        cust_id = f"CUST-{i:05d}"
        name = fake.name()
        city = fake.city()
        state = fake.state_abbr()

        customers.append((
            cust_id, name, segment, city, state, region
        ))

    insert_query = """
    INSERT INTO dim_customer (
        customer_id, customer_name, segment, city, state, region
    ) VALUES (%s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(insert_query, customers)
    print(f"✅ Loaded {len(customers)} customers into dim_customer.")


def seed_store_dimension(cursor):
    print("⏳ Populating dim_store (~15 stores)...")
    store_types = ["Online", "Mall", "Outlet"]
    regions = ["East", "West", "Central", "South", "North"]
    
    stores = []
    # 2 flagship Online stores
    stores.append(("Global Online Store", "Online", "Seattle", "West", fake.name()))
    stores.append(("Direct Web Portal", "Online", "New York", "East", fake.name()))

    # 13 Physical stores
    for i in range(1, 14):
        stype = random.choice(["Mall", "Outlet"])
        sregion = random.choice(regions)
        name = f"{fake.city()} {stype} #{i}"
        stores.append((name, stype, fake.city(), sregion, fake.name()))

    insert_query = """
    INSERT INTO dim_store (
        store_name, store_type, city, region, manager
    ) VALUES (%s, %s, %s, %s, %s)
    """
    cursor.executemany(insert_query, stores)
    print(f"✅ Loaded {len(stores)} stores into dim_store.")


def seed_fact_sales(cursor, date_rows):
    print(f"⏳ Generating and inserting {TOTAL_FACT_ROWS:,} rows into fact_sales (batches of {BATCH_SIZE:,})...")

    # Fetch dimension surrogate keys and product pricing
    cursor.execute("SELECT product_key, unit_cost, unit_price FROM dim_product")
    products = cursor.fetchall()  # list of (key, cost, price)
    product_keys = [p[0] for p in products]
    product_cost_map = {p[0]: Decimal(str(p[1])) for p in products}
    product_price_map = {p[0]: Decimal(str(p[2])) for p in products}

    # Zipf weights: top products sell far more frequently
    weights = [1.0 / (i + 1) ** 0.85 for i in range(len(product_keys))]

    cursor.execute("SELECT customer_key FROM dim_customer")
    customer_keys = [c[0] for c in cursor.fetchall()]

    cursor.execute("SELECT store_key FROM dim_store")
    store_keys = [s[0] for s in cursor.fetchall()]

    # Extract date info: (date_key, month_num, is_weekend)
    date_info_list = [(d[0], d[5], d[9]) for d in date_rows]
    # Calculate seasonal and weekend weights for dates
    date_weights = []
    for d_key, month_num, is_weekend in date_info_list:
        base_weight = 1.0
        # Holiday uplift (November & December)
        if month_num in (11, 12):
            base_weight *= 2.2
        elif month_num in (7, 8):  # Summer bump
            base_weight *= 1.3
        # Weekend uplift
        if is_weekend == 1:
            base_weight *= 1.5
        date_weights.append(base_weight)

    discount_choices = [
        Decimal("0.00"), Decimal("0.05"), Decimal("0.10"), 
        Decimal("0.15"), Decimal("0.20"), Decimal("0.25"), Decimal("0.30")
    ]
    discount_weights = [0.45, 0.20, 0.15, 0.10, 0.05, 0.03, 0.02]

    insert_query = """
    INSERT INTO fact_sales (
        date_key, product_key, customer_key, store_key,
        quantity, unit_price, discount_pct, sales_amount, cost_amount, profit_amount
    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """

    total_inserted = 0
    while total_inserted < TOTAL_FACT_ROWS:
        batch = []
        batch_count = min(BATCH_SIZE, TOTAL_FACT_ROWS - total_inserted)

        chosen_dates = random.choices(date_info_list, weights=date_weights, k=batch_count)
        chosen_products = random.choices(product_keys, weights=weights, k=batch_count)
        chosen_customers = random.choices(customer_keys, k=batch_count)
        chosen_stores = random.choices(store_keys, k=batch_count)
        chosen_discounts = random.choices(discount_choices, weights=discount_weights, k=batch_count)
        chosen_quantities = random.choices([1, 2, 3, 4, 5, 6, 8, 10], weights=[0.4, 0.25, 0.15, 0.08, 0.05, 0.03, 0.02, 0.02], k=batch_count)

        for i in range(batch_count):
            d_key = chosen_dates[i][0]
            p_key = chosen_products[i]
            c_key = chosen_customers[i]
            s_key = chosen_stores[i]
            qty = chosen_quantities[i]
            disc = chosen_discounts[i]

            u_cost = product_cost_map[p_key]
            u_price = product_price_map[p_key]

            # Calculations
            # sales_amount = quantity * unit_price * (1 - discount_pct)
            # profit_amount = sales_amount - cost_amount
            cost_amount = (Decimal(qty) * u_cost).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            gross_sales = Decimal(qty) * u_price
            sales_amount = (gross_sales * (Decimal("1.00") - disc)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            profit_amount = (sales_amount - cost_amount).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

            batch.append((
                d_key, p_key, c_key, s_key,
                qty, float(u_price), float(disc),
                float(sales_amount), float(cost_amount), float(profit_amount)
            ))

        cursor.executemany(insert_query, batch)
        total_inserted += batch_count
        print(f"   -> Inserted {total_inserted:,} / {TOTAL_FACT_ROWS:,} fact rows...")

    print("✅ Completed fact_sales loading.")


def verify_integrity(cursor):
    print("\n🔍 ================= DATA INTEGRITY & AUDIT REPORT =================")
    tables = ["dim_date", "dim_product", "dim_customer", "dim_store", "fact_sales"]
    for tbl in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {tbl}")
        count = cursor.fetchone()[0]
        print(f"  • {tbl:15}: {count:>10,} rows")

    # Orphan foreign key checks
    checks = [
        ("dim_date (date_key)", "SELECT COUNT(*) FROM fact_sales f LEFT JOIN dim_date d ON f.date_key = d.date_key WHERE d.date_key IS NULL"),
        ("dim_product (product_key)", "SELECT COUNT(*) FROM fact_sales f LEFT JOIN dim_product p ON f.product_key = p.product_key WHERE p.product_key IS NULL"),
        ("dim_customer (customer_key)", "SELECT COUNT(*) FROM fact_sales f LEFT JOIN dim_customer c ON f.customer_key = c.customer_key WHERE c.customer_key IS NULL"),
        ("dim_store (store_key)", "SELECT COUNT(*) FROM fact_sales f LEFT JOIN dim_store s ON f.store_key = s.store_key WHERE s.store_key IS NULL"),
    ]

    print("\n🔗 Foreign Key Integrity Check:")
    has_orphans = False
    for label, query in checks:
        cursor.execute(query)
        orphaned = cursor.fetchone()[0]
        if orphaned > 0:
            print(f"  ❌ ORPHAN DETECTED in {label}: {orphaned} rows!")
            has_orphans = True
        else:
            print(f"  ✅ {label:30}: 0 orphaned records (Clean)")

    if has_orphans:
        raise ValueError("Critical foreign key constraint violation detected in fact_sales!")

    # Min/Max dates check
    cursor.execute("SELECT MIN(date_key), MAX(date_key), MIN(sales_amount), MAX(sales_amount), SUM(sales_amount) FROM fact_sales")
    min_date, max_date, min_sale, max_sale, total_sales = cursor.fetchone()
    print(f"\n📊 Summary Stats:")
    print(f"  • Date Range: {min_date} to {max_date}")
    print(f"  • Sales Amount Range: ${float(min_sale):,.2f} to ${float(max_sale):,.2f}")
    print(f"  • Total Grand Sales: ${float(total_sales):,.2f}")
    print("===================================================================\n")


def main():
    conn = get_connection()
    cursor = conn.cursor()

    try:
        print("🚀 Starting sales_dw Data Generation...")

        # Disable foreign key checks & autocommit temporarily for faster bulk load
        cursor.execute("SET FOREIGN_KEY_CHECKS = 0;")
        cursor.execute("TRUNCATE TABLE fact_sales;")
        cursor.execute("TRUNCATE TABLE dim_date;")
        cursor.execute("TRUNCATE TABLE dim_product;")
        cursor.execute("TRUNCATE TABLE dim_customer;")
        cursor.execute("TRUNCATE TABLE dim_store;")
        cursor.execute("SET FOREIGN_KEY_CHECKS = 1;")

        # Seed dimensions
        date_rows = seed_date_dimension(cursor)
        seed_product_dimension(cursor)
        seed_customer_dimension(cursor)
        seed_store_dimension(cursor)

        conn.commit()

        # Seed fact table
        seed_fact_sales(cursor, date_rows)
        conn.commit()

        # Verify integrity
        verify_integrity(cursor)

        print("🎉 Data generation finished successfully!")

    except Exception as e:
        conn.rollback()
        print(f"❌ Error occurred during data generation: {e}")
        raise
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    main()
