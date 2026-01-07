#!/usr/bin/env python3
"""
Comprehensive data generation script for e-commerce database.
Generates large volumes of realistic test data using Faker.
"""

import mysql.connector
from faker import Faker
import time
import random
import json
import os
from datetime import datetime, timedelta
from decimal import Decimal
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables from .env file
# Try scripts directory first, then project root
env_path_scripts = Path(__file__).parent / '.env'
env_path_root = Path(__file__).parent.parent / '.env'
if env_path_scripts.exists():
    load_dotenv(dotenv_path=env_path_scripts)
elif env_path_root.exists():
    load_dotenv(dotenv_path=env_path_root)
else:
    # Try loading from current directory (for Docker container)
    load_dotenv()

# Initialize Faker
fake = Faker()

def get_required_env(key):
    """Get required environment variable or raise error."""
    value = os.getenv(key)
    if value is None:
        raise ValueError(f"Required environment variable '{key}' is not set. Please check your .env file.")
    return value

# Database connection configuration
DB_CONFIG = {
    'host': get_required_env('DB_HOST'),
    'user': get_required_env('DB_USER'),
    'password': get_required_env('DB_PASSWORD'),
    'database': get_required_env('DB_NAME'),
    'port': int(get_required_env('DB_PORT')),
    'autocommit': False
}

# Configuration for data volumes - loaded from .env file
CONFIG = {
    'tenants': int(get_required_env('TENANTS')),
    'stores_per_tenant': int(get_required_env('STORES_PER_TENANT')),
    'categories': int(get_required_env('CATEGORIES')),
    'products_per_category': int(get_required_env('PRODUCTS_PER_CATEGORY')),
    'users_per_tenant': int(get_required_env('USERS_PER_TENANT')),
    'max_orders_per_user': int(get_required_env('MAX_ORDERS_PER_USER')),
    'max_items_per_order': int(get_required_env('MAX_ITEMS_PER_ORDER')),
    'max_promotions_per_tenant': int(get_required_env('MAX_PROMOTIONS_PER_TENANT')),
    'max_reviews_per_product': int(get_required_env('MAX_REVIEWS_PER_PRODUCT')),
    'days_of_history': int(get_required_env('DAYS_OF_HISTORY'))
}

def wait_for_db(max_retries=30, retry_delay=2):
    """Wait for MySQL to be ready."""
    for i in range(max_retries):
        try:
            conn = mysql.connector.connect(**DB_CONFIG)
            conn.close()
            print("Database is ready!")
            return True
        except mysql.connector.Error:
            print(f"Waiting for database... ({i+1}/{max_retries})")
            time.sleep(retry_delay)
    return False

def execute_batch(cursor, query, data, batch_size=1000):
    """Execute batch insert for better performance."""
    total = len(data)
    for i in range(0, total, batch_size):
        batch = data[i:i + batch_size]
        cursor.executemany(query, batch)
        print(f"  Inserted batch {i//batch_size + 1}/{(total-1)//batch_size + 1} ({len(batch)} records)")

def generate_tenants(cursor, count):
    """Generate tenant data."""
    print(f"\nGenerating {count} tenants...")
    data = []
    for i in range(count):
        company_name = fake.company()
        tenant_code = company_name.lower().replace(' ', '').replace(',', '').replace('.', '')[:50]
        data.append((
            company_name,
            tenant_code,
            1  # status
        ))
    
    query = "INSERT INTO tenants (tenant_name, tenant_code, status) VALUES (%s, %s, %s)"
    execute_batch(cursor, query, data)
    cursor.execute("SELECT tenant_id FROM tenants ORDER BY tenant_id")
    return [row[0] for row in cursor.fetchall()]

def generate_stores(cursor, count):
    """Generate store data."""
    print(f"\nGenerating {count} stores...")
    data = []
    for i in range(count):
        store_name = f"{fake.company()} {fake.random_element(elements=('Store', 'Outlet', 'Location', 'Hub'))}"
        data.append((
            store_name,
            fake.address(),
            fake.city(),
            fake.state_abbr(),
            fake.zipcode(),
            float(fake.latitude()),
            float(fake.longitude()),
            1  # status
        ))
    
    query = """INSERT INTO stores (store_name, address, city, state, zip_code, latitude, longitude, status)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s)"""
    execute_batch(cursor, query, data)
    cursor.execute("SELECT store_id FROM stores ORDER BY store_id")
    return [row[0] for row in cursor.fetchall()]

def generate_tenant_stores(cursor, tenant_ids, store_ids):
    """Generate tenant-store mappings."""
    print(f"\nLinking tenants to stores...")
    data = []
    stores_per_tenant = len(store_ids) // len(tenant_ids)
    
    for i, tenant_id in enumerate(tenant_ids):
        start_idx = i * stores_per_tenant
        end_idx = start_idx + stores_per_tenant
        tenant_stores = store_ids[start_idx:end_idx]
        
        for j, store_id in enumerate(tenant_stores):
            data.append((
                tenant_id,
                store_id,
                1 if j == 0 else 0,  # First store is default
                1  # status
            ))
    
    query = "INSERT INTO tenant_stores (tenant_id, store_id, is_default, status) VALUES (%s, %s, %s, %s)"
    execute_batch(cursor, query, data)

def generate_categories(cursor, count):
    """Generate product categories with hierarchy."""
    print(f"\nGenerating {count} categories...")
    category_names = [
        'Electronics', 'Clothing', 'Food & Beverages', 'Home & Garden', 'Sports & Outdoors',
        'Books', 'Toys & Games', 'Health & Beauty', 'Automotive', 'Pet Supplies',
        'Office Supplies', 'Baby Products', 'Jewelry', 'Musical Instruments', 'Art & Crafts',
        'Tools & Hardware', 'Furniture', 'Kitchen & Dining', 'Outdoor Living', 'Gaming'
    ]
    
    # Generate parent categories
    parent_data = []
    parent_ids = []
    for i, name in enumerate(category_names[:count]):
        slug = name.lower().replace(' ', '-').replace('&', 'and')
        parent_data.append((
            name,
            slug,
            fake.text(max_nb_chars=200),
            None,  # parent_category_id
            i,  # sort_order
            1  # status
        ))
    
    query = """INSERT INTO product_categories (category_name, slug, description, parent_category_id, sort_order, status)
               VALUES (%s, %s, %s, %s, %s, %s)"""
    execute_batch(cursor, query, parent_data)
    cursor.execute("SELECT category_id FROM product_categories WHERE parent_category_id IS NULL ORDER BY category_id")
    parent_ids = [row[0] for row in cursor.fetchall()]
    
    return parent_ids

def generate_products(cursor, category_ids, count_per_category):
    """Generate products."""
    print(f"\nGenerating products ({len(category_ids)} categories × {count_per_category} products)...")
    data = []
    product_types = ['Premium', 'Standard', 'Basic', 'Deluxe', 'Pro', 'Classic', 'Modern', 'Vintage']
    
    for category_id in category_ids:
        for i in range(count_per_category):
            product_type = fake.random_element(elements=product_types)
            product_name = f"{product_type} {fake.word().capitalize()} {fake.word().capitalize()}"
            sku = f"SKU-{category_id:03d}-{i+1:04d}-{fake.random_int(min=1000, max=9999)}"
            base_price = round(fake.pydecimal(left_digits=3, right_digits=2, positive=True, min_value=5, max_value=500), 2)
            
            data.append((
                category_id,
                product_name,
                sku,
                fake.text(max_nb_chars=500),
                base_price,
                round(fake.pydecimal(left_digits=4, right_digits=2, positive=True, min_value=10, max_value=5000), 2),
                fake.random_element(elements=('g', 'kg', 'oz', 'lb')),
                1  # status
            ))
    
    query = """INSERT INTO products (category_id, product_name, sku, description, base_price, weight, weight_unit, status)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s)"""
    execute_batch(cursor, query, data)
    cursor.execute("SELECT product_id FROM products ORDER BY product_id")
    return [row[0] for row in cursor.fetchall()]

def generate_users(cursor, tenant_ids, store_ids, users_per_tenant):
    """Generate users."""
    print(f"\nGenerating users ({len(tenant_ids)} tenants × {users_per_tenant} users)...")
    data = []
    user_types = [1, 1, 1, 1, 2, 3]  # Mostly customers, some drivers and employees
    
    tenant_store_map = {}
    cursor.execute("SELECT tenant_id, store_id FROM tenant_stores WHERE status = 1")
    for tenant_id, store_id in cursor.fetchall():
        if tenant_id not in tenant_store_map:
            tenant_store_map[tenant_id] = []
        tenant_store_map[tenant_id].append(store_id)
    
    for tenant_id in tenant_ids:
        stores = tenant_store_map.get(tenant_id, [store_ids[0]])
        for i in range(users_per_tenant):
            store_id = fake.random_element(elements=stores)
            user_type = fake.random_element(elements=user_types)
            registration_date = fake.date_time_between(start_date=f'-{CONFIG["days_of_history"]}d', end_date='now')
            
            data.append((
                tenant_id,
                store_id,
                fake.first_name(),
                fake.last_name(),
                f"{fake.user_name()}{i}{tenant_id}@{fake.domain_name()}",
                fake.phone_number()[:20],
                user_type,
                1,  # status
                registration_date,
                fake.date_time_between(start_date=registration_date, end_date='now') if random.random() > 0.3 else None,
                0,  # total_orders (will be updated later)
                0.00  # total_spent (will be updated later)
            ))
    
    query = """INSERT INTO users (tenant_id, store_id, first_name, last_name, email, phone, user_type, status,
               registration_date, last_login, total_orders, total_spent)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"""
    execute_batch(cursor, query, data)
    cursor.execute("SELECT user_id, tenant_id, store_id FROM users WHERE user_type = 1 ORDER BY user_id")
    return cursor.fetchall()

def generate_product_store_pricing(cursor, product_ids, tenant_ids, store_ids):
    """Generate product-store pricing."""
    print(f"\nGenerating product-store pricing...")
    data = []
    
    # Get tenant-store mappings
    tenant_store_map = {}
    cursor.execute("SELECT tenant_id, store_id FROM tenant_stores WHERE status = 1")
    for tenant_id, store_id in cursor.fetchall():
        if tenant_id not in tenant_store_map:
            tenant_store_map[tenant_id] = []
        tenant_store_map[tenant_id].append(store_id)
    
    # Get base prices
    cursor.execute("SELECT product_id, base_price FROM products")
    product_prices = {row[0]: float(row[1]) for row in cursor.fetchall()}
    
    for product_id in product_ids:
        for tenant_id in tenant_ids:
            stores = tenant_store_map.get(tenant_id, [])
            # Not all products available at all stores
            if random.random() > 0.3:  # 70% availability
                selected_stores = random.sample(stores, min(len(stores), random.randint(1, len(stores))))
                for store_id in selected_stores:
                    base_price = product_prices[product_id]
                    # Store-specific pricing variation
                    selling_price = round(base_price * random.uniform(0.9, 1.1), 2)
                    stock_quantity = random.randint(0, 500)
                    
                    data.append((
                        product_id,
                        store_id,
                        tenant_id,
                        selling_price,
                        stock_quantity,
                        random.randint(1, 5),
                        random.randint(10, 100),
                        1  # status
                    ))
    
    query = """INSERT INTO product_store_pricing (product_id, store_id, tenant_id, selling_price, stock_quantity,
               min_order_quantity, max_order_quantity, status)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s)"""
    execute_batch(cursor, query, data)

def generate_orders(cursor, users, days_of_history):
    """Generate orders with realistic distribution."""
    print(f"\nGenerating orders...")
    order_statuses = [1, 2, 3, 4, 5, 5, 5, 6]  # More completed orders
    payment_methods = ['Credit Card', 'Debit Card', 'PayPal', 'Cash', 'Apple Pay', 'Google Pay']
    payment_statuses = [0, 1, 1, 1, 2]  # Mostly paid
    
    orders_data = []
    order_items_data = []
    status_history_data = []
    
    start_date = datetime.now() - timedelta(days=days_of_history)
    
    for user_id, tenant_id, store_id in users:
        num_orders = random.randint(1, CONFIG['max_orders_per_user'])
        
        for i in range(num_orders):
            order_date = fake.date_time_between(start_date=start_date, end_date='now')
            order_status = fake.random_element(elements=order_statuses)
            order_number = f"ORD-{tenant_id:03d}-{store_id:03d}-{int(order_date.timestamp())}-{random.randint(1000, 9999)}"
            
            # Calculate delivery date based on status
            delivery_date = None
            if order_status == 5:  # Delivered
                delivery_date = order_date + timedelta(hours=random.randint(1, 48))
            elif order_status >= 4:  # Shipped or delivered
                delivery_date = order_date + timedelta(hours=random.randint(1, 72))
            
            # Get products available at this store
            cursor.execute("""
                SELECT psp.product_id, psp.selling_price, p.product_name
                FROM product_store_pricing psp
                JOIN products p ON psp.product_id = p.product_id
                WHERE psp.store_id = %s AND psp.tenant_id = %s AND psp.status = 1
                LIMIT 50
            """, (store_id, tenant_id))
            available_products = cursor.fetchall()
            
            if not available_products:
                continue
            
            # Generate order items
            num_items = random.randint(1, CONFIG['max_items_per_order'])
            selected_products = random.sample(available_products, min(num_items, len(available_products)))
            
            subtotal = Decimal('0.00')
            items_for_order = []
            
            for product_id, selling_price, product_name in selected_products:
                quantity = random.randint(1, 5)
                unit_price = Decimal(str(selling_price))
                discount = Decimal(str(round(random.uniform(0, 0.2) * float(unit_price), 2))) if random.random() > 0.7 else Decimal('0.00')
                tax = Decimal(str(round(float(unit_price) * 0.08, 2)))  # 8% tax
                line_total = (unit_price - discount + tax) * quantity
                
                subtotal += line_total
                items_for_order.append((
                    product_id,
                    product_name,
                    quantity,
                    float(unit_price),
                    float(discount),
                    float(tax),
                    float(line_total)
                ))
            
            # Order totals
            discount_amount = Decimal(str(round(float(subtotal) * random.uniform(0, 0.15), 2))) if random.random() > 0.6 else Decimal('0.00')
            tax_amount = Decimal(str(round(float(subtotal - discount_amount) * 0.08, 2)))
            shipping_fee = Decimal(str(round(random.uniform(0, 15), 2))) if random.random() > 0.3 else Decimal('0.00')
            total_amount = subtotal - discount_amount + tax_amount + shipping_fee
            
            orders_data.append((
                order_number,
                tenant_id,
                store_id,
                user_id,
                order_status,
                order_date,
                delivery_date,
                float(subtotal),
                float(tax_amount),
                float(discount_amount),
                float(shipping_fee),
                float(total_amount),
                fake.random_element(elements=payment_methods),
                fake.random_element(elements=payment_statuses),
                fake.address(),
                fake.city(),
                fake.state_abbr(),
                fake.zipcode(),
                fake.text(max_nb_chars=200) if random.random() > 0.8 else None
            ))
            
            # Store order items (will insert after orders)
            order_items_data.append((items_for_order, len(orders_data)))  # Store index for order_id
            
            # Status history
            if order_status > 1:
                status_history_data.append((len(orders_data), 1, order_status))  # From pending to current
    
    # Insert orders
    query = """INSERT INTO orders (order_number, tenant_id, store_id, user_id, order_status, order_date, delivery_date,
               subtotal, tax_amount, discount_amount, shipping_fee, total_amount, payment_method, payment_status,
               delivery_address, delivery_city, delivery_state, delivery_zip, notes)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"""
    execute_batch(cursor, query, orders_data)
    
    # Get inserted order IDs
    cursor.execute("SELECT order_id FROM orders ORDER BY order_id DESC LIMIT %s", (len(orders_data),))
    order_ids = [row[0] for row in cursor.fetchall()][::-1]  # Reverse to match insertion order
    
    # Insert order items
    print(f"  Inserting order items...")
    items_insert_data = []
    for (items, order_idx) in order_items_data:
        order_id = order_ids[order_idx - 1]
        for product_id, product_name, quantity, unit_price, discount, tax, line_total in items:
            items_insert_data.append((
                order_id,
                product_id,
                product_name,
                quantity,
                unit_price,
                discount,
                tax,
                line_total
            ))
    
    query = """INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount,
               tax_amount, line_total)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s)"""
    execute_batch(cursor, query, items_insert_data)
    
    # Insert status history
    if status_history_data:
        print(f"  Inserting order status history...")
        history_insert_data = []
        for order_idx, old_status, new_status in status_history_data:
            order_id = order_ids[order_idx - 1]
            history_insert_data.append((order_id, old_status, new_status))
        
        query = "INSERT INTO order_status_history (order_id, old_status, new_status) VALUES (%s, %s, %s)"
        execute_batch(cursor, query, history_insert_data)
    
    print(f"  Generated {len(orders_data)} orders with {len(items_insert_data)} items")
    return len(orders_data)

def generate_promotions(cursor, tenant_ids):
    """Generate promotions."""
    print(f"\nGenerating promotions...")
    data = []
    discount_types = ['percentage', 'fixed_amount', 'buy_x_get_y', 'free_shipping']
    applicable_to_options = ['all', 'category', 'product', 'user_segment']
    
    for tenant_id in tenant_ids:
        num_promotions = random.randint(1, CONFIG['max_promotions_per_tenant'])
        for i in range(num_promotions):
            discount_type = fake.random_element(elements=discount_types)
            applicable_to = fake.random_element(elements=applicable_to_options)
            
            # Generate JSON for applicable_ids
            if applicable_to == 'category':
                cursor.execute("SELECT category_id FROM product_categories LIMIT 5")
                ids = [row[0] for row in cursor.fetchall()]
                applicable_ids = json.dumps(ids[:random.randint(1, 3)])
            elif applicable_to == 'product':
                cursor.execute("SELECT product_id FROM products LIMIT 10")
                ids = [row[0] for row in cursor.fetchall()]
                applicable_ids = json.dumps(ids[:random.randint(1, 5)])
            else:
                applicable_ids = json.dumps([])
            
            start_date = fake.date_time_between(start_date='-30d', end_date='+30d')
            end_date = start_date + timedelta(days=random.randint(7, 60))
            
            if discount_type == 'percentage':
                discount_value = round(random.uniform(5, 50), 2)
            elif discount_type == 'fixed_amount':
                discount_value = round(random.uniform(5, 100), 2)
            else:
                discount_value = 0.00
            
            data.append((
                tenant_id,
                f"PROMO-{tenant_id}-{i+1:03d}",
                f"{discount_type.replace('_', ' ').title()} Promotion",
                fake.text(max_nb_chars=200),
                discount_type,
                discount_value,
                round(random.uniform(20, 200), 2),
                round(random.uniform(10, 50), 2) if discount_type == 'percentage' else None,
                applicable_to,
                applicable_ids,
                start_date,
                end_date,
                random.randint(1, 5),
                random.randint(10, 1000) if random.random() > 0.5 else None,
                0,  # current_uses
                1  # status
            ))
    
    query = """INSERT INTO promotions (tenant_id, promotion_code, promotion_name, description, discount_type,
               discount_value, min_order_amount, max_discount_amount, applicable_to, applicable_ids,
               start_date, end_date, max_uses_per_user, max_total_uses, current_uses, status)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"""
    execute_batch(cursor, query, data)
    cursor.execute("SELECT promotion_id, tenant_id FROM promotions")
    return cursor.fetchall()

def generate_promotion_usage(cursor, promotions, orders_count):
    """Generate promotion usage."""
    print(f"\nGenerating promotion usage...")
    data = []
    
    # Get some orders that could have used promotions
    cursor.execute("SELECT order_id, tenant_id, user_id, discount_amount FROM orders WHERE discount_amount > 0 LIMIT %s", (min(orders_count // 10, 1000),))
    orders_with_discounts = cursor.fetchall()
    
    for order_id, tenant_id, user_id, discount_amount in orders_with_discounts:
        # Find a promotion for this tenant
        tenant_promotions = [p for p in promotions if p[1] == tenant_id]
        if tenant_promotions and random.random() > 0.5:
            promotion_id = fake.random_element(elements=[p[0] for p in tenant_promotions])
            data.append((
                promotion_id,
                user_id,
                order_id,
                float(discount_amount)
            ))
    
    if data:
        query = "INSERT INTO promotion_usage (promotion_id, user_id, order_id, discount_amount) VALUES (%s, %s, %s, %s)"
        execute_batch(cursor, query, data)
        print(f"  Generated {len(data)} promotion usages")

def generate_reviews(cursor, product_ids, user_ids):
    """Generate product reviews."""
    print(f"\nGenerating product reviews...")
    data = []
    
    # Get users who have ordered products, grouped by product
    cursor.execute("""
        SELECT oi.product_id, o.user_id, o.order_id
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.order_id
        WHERE o.order_status = 5
        ORDER BY oi.product_id
    """)
    order_product_user = cursor.fetchall()
    
    # Group by product_id
    product_orders = {}
    for product_id, user_id, order_id in order_product_user:
        if product_id not in product_orders:
            product_orders[product_id] = []
        product_orders[product_id].append((user_id, order_id))
    
    # Generate reviews for each product (1 to max_reviews_per_product)
    for product_id in product_ids:
        if product_id in product_orders:
            available_reviews = product_orders[product_id]
            num_reviews = random.randint(1, min(CONFIG['max_reviews_per_product'], len(available_reviews)))
            selected_reviews = random.sample(available_reviews, num_reviews)
            
            for user_id, order_id in selected_reviews:
                rating = random.randint(1, 5)
                data.append((
                    product_id,
                    user_id,
                    order_id,
                    rating,
                    fake.sentence()[:255] if random.random() > 0.3 else None,
                    fake.text(max_nb_chars=500) if random.random() > 0.5 else None,
                    1 if random.random() > 0.3 else 0,  # verified purchase
                    1 if random.random() > 0.1 else 0,  # approved
                    0  # helpful_count
                ))
    
    if data:
        query = """INSERT INTO product_reviews (product_id, user_id, order_id, rating, review_title, review_text,
                   is_verified_purchase, is_approved, helpful_count)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)"""
        execute_batch(cursor, query, data)
        print(f"  Generated {len(data)} reviews")

def generate_data():
    """Main data generation function."""
    if not wait_for_db():
        print("Failed to connect to database. Exiting.")
        return
    
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        print("\n" + "="*60)
        print("Starting Data Generation")
        print("="*60)
        
        start_time = time.time()
        
        # Generate in dependency order
        tenant_ids = generate_tenants(cursor, CONFIG['tenants'])
        conn.commit()
        
        total_stores = CONFIG['tenants'] * CONFIG['stores_per_tenant']
        store_ids = generate_stores(cursor, total_stores)
        conn.commit()
        
        generate_tenant_stores(cursor, tenant_ids, store_ids)
        conn.commit()
        
        category_ids = generate_categories(cursor, CONFIG['categories'])
        conn.commit()
        
        product_ids = generate_products(cursor, category_ids, CONFIG['products_per_category'])
        conn.commit()
        
        users = generate_users(cursor, tenant_ids, store_ids, CONFIG['users_per_tenant'])
        conn.commit()
        
        generate_product_store_pricing(cursor, product_ids, tenant_ids, store_ids)
        conn.commit()
        
        orders_count = generate_orders(cursor, users, CONFIG['days_of_history'])
        conn.commit()
        
        promotions = generate_promotions(cursor, tenant_ids)
        conn.commit()
        
        generate_promotion_usage(cursor, promotions, orders_count)
        conn.commit()
        
        user_ids = [u[0] for u in users]
        generate_reviews(cursor, product_ids, user_ids)
        conn.commit()
        
        elapsed = time.time() - start_time
        
        print("\n" + "="*60)
        print("Data Generation Complete!")
        print("="*60)
        print(f"Total time: {elapsed:.2f} seconds")
        print(f"Generated:")
        print(f"   - {len(tenant_ids)} tenants")
        print(f"   - {len(store_ids)} stores")
        print(f"   - {len(category_ids)} categories")
        print(f"   - {len(product_ids)} products")
        print(f"   - {len(users)} users")
        print(f"   - {orders_count} orders")
        print(f"   - {len(promotions)} promotions")
        print("="*60)
        
        cursor.close()
        conn.close()
        
    except mysql.connector.Error as e:
        print(f"Database error: {e}")
        if 'conn' in locals():
            conn.rollback()
        raise

if __name__ == "__main__":
    generate_data()
