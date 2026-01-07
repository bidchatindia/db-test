-- Stripped down schema for data engineering interview test
-- Based on SaaS e-commerce and quick commerce platform structure
-- Simplified but maintains core relationships for complex query testing

CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;

-- Tenants (multi-tenant SaaS structure - replaces domains)
CREATE TABLE tenants (
    tenant_id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_name VARCHAR(255) NOT NULL,
    tenant_code VARCHAR(50) UNIQUE NOT NULL,
    status TINYINT(1) DEFAULT 1 COMMENT '1=active, 0=inactive',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_tenant_status (status),
    INDEX idx_tenant_code (tenant_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Stores (physical locations/warehouses - replaces locations)
CREATE TABLE stores (
    store_id INT AUTO_INCREMENT PRIMARY KEY,
    store_name VARCHAR(255) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    status TINYINT(1) DEFAULT 1 COMMENT '1=active, 0=inactive',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_store_status (status),
    INDEX idx_store_location (latitude, longitude)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tenant-Store mapping (many-to-many relationship)
CREATE TABLE tenant_stores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id INT NOT NULL,
    store_id INT NOT NULL,
    is_default TINYINT(1) DEFAULT 0,
    status TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_tenant_store (tenant_id, store_id),
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    FOREIGN KEY (store_id) REFERENCES stores(store_id) ON DELETE CASCADE,
    INDEX idx_tenant_id (tenant_id),
    INDEX idx_store_id (store_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Users (customers - replaces oc_customer)
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id INT NOT NULL,
    store_id INT NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    user_type TINYINT(1) DEFAULT 1 COMMENT '1=customer, 2=driver, 3=employee',
    status TINYINT(1) DEFAULT 1 COMMENT '1=active, 0=inactive',
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    total_orders INT DEFAULT 0,
    total_spent DECIMAL(15, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    INDEX idx_user_tenant (tenant_id),
    INDEX idx_user_store (store_id),
    INDEX idx_user_email (email),
    INDEX idx_user_phone (phone),
    INDEX idx_user_status (status),
    INDEX idx_user_type (user_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Product Categories (replaces categories)
CREATE TABLE product_categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    parent_category_id INT NULL,
    sort_order INT DEFAULT 0,
    status TINYINT(1) DEFAULT 1 COMMENT '1=active, 0=inactive',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_category_id) REFERENCES product_categories(category_id) ON DELETE SET NULL,
    INDEX idx_category_status (status),
    INDEX idx_category_slug (slug),
    INDEX idx_parent_category (parent_category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Products (product catalog)
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    sku VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    base_price DECIMAL(10, 2) NOT NULL,
    weight DECIMAL(8, 2),
    weight_unit VARCHAR(10) DEFAULT 'g',
    status TINYINT(1) DEFAULT 1 COMMENT '1=active, 0=inactive',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES product_categories(category_id),
    INDEX idx_product_category (category_id),
    INDEX idx_product_sku (sku),
    INDEX idx_product_status (status),
    INDEX idx_product_name (product_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Product-Store mapping (products available at specific stores with store-specific pricing)
CREATE TABLE product_store_pricing (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    store_id INT NOT NULL,
    tenant_id INT NOT NULL,
    selling_price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    min_order_quantity INT DEFAULT 1,
    max_order_quantity INT DEFAULT 100,
    status TINYINT(1) DEFAULT 1 COMMENT '1=available, 0=unavailable',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (store_id) REFERENCES stores(store_id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    UNIQUE KEY unique_product_store_tenant (product_id, store_id, tenant_id),
    INDEX idx_product_store (product_id, store_id),
    INDEX idx_store_tenant (store_id, tenant_id),
    INDEX idx_product_status (product_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Orders (replaces oc_order)
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    tenant_id INT NOT NULL,
    store_id INT NOT NULL,
    user_id INT NOT NULL,
    order_status TINYINT(1) DEFAULT 1 COMMENT '1=pending, 2=confirmed, 3=processing, 4=shipped, 5=delivered, 6=cancelled',
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivery_date TIMESTAMP NULL,
    subtotal DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    tax_amount DECIMAL(15, 2) DEFAULT 0.00,
    discount_amount DECIMAL(15, 2) DEFAULT 0.00,
    shipping_fee DECIMAL(10, 2) DEFAULT 0.00,
    total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    payment_method VARCHAR(50),
    payment_status TINYINT(1) DEFAULT 0 COMMENT '0=pending, 1=paid, 2=failed',
    delivery_address TEXT,
    delivery_city VARCHAR(100),
    delivery_state VARCHAR(50),
    delivery_zip VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_order_tenant (tenant_id),
    INDEX idx_order_store (store_id),
    INDEX idx_order_user (user_id),
    INDEX idx_order_status (order_status),
    INDEX idx_order_date (order_date),
    INDEX idx_order_number (order_number),
    INDEX idx_order_user_status (user_id, order_status),
    INDEX idx_order_store_status (store_id, order_status),
    INDEX idx_order_tenant_store_status (tenant_id, store_id, order_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Order Items (replaces oc_order_product)
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10, 2) NOT NULL,
    discount_amount DECIMAL(10, 2) DEFAULT 0.00,
    tax_amount DECIMAL(10, 2) DEFAULT 0.00,
    line_total DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    INDEX idx_order_item_order (order_id),
    INDEX idx_order_item_product (product_id),
    INDEX idx_order_item_composite (order_id, product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Order Status History (for tracking order status changes)
CREATE TABLE order_status_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    old_status TINYINT(1),
    new_status TINYINT(1) NOT NULL,
    changed_by INT NULL COMMENT 'user_id who made the change',
    change_reason TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_status_history_order (order_id),
    INDEX idx_status_history_date (changed_at),
    INDEX idx_status_history_status (new_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Promotions/Coupons (complex discount rules)
CREATE TABLE promotions (
    promotion_id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id INT NOT NULL,
    promotion_code VARCHAR(50) UNIQUE,
    promotion_name VARCHAR(255) NOT NULL,
    description TEXT,
    discount_type ENUM('percentage', 'fixed_amount', 'buy_x_get_y', 'free_shipping') NOT NULL,
    discount_value DECIMAL(10, 2),
    min_order_amount DECIMAL(10, 2) DEFAULT 0.00,
    max_discount_amount DECIMAL(10, 2) NULL,
    applicable_to ENUM('all', 'category', 'product', 'user_segment') DEFAULT 'all',
    applicable_ids JSON COMMENT 'Array of category_ids, product_ids, or user segment IDs',
    start_date DATETIME NOT NULL,
    end_date DATETIME NOT NULL,
    max_uses_per_user INT DEFAULT 1,
    max_total_uses INT NULL,
    current_uses INT DEFAULT 0,
    status TINYINT(1) DEFAULT 1 COMMENT '1=active, 0=inactive',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id),
    INDEX idx_promotion_tenant (tenant_id),
    INDEX idx_promotion_code (promotion_code),
    INDEX idx_promotion_dates (start_date, end_date),
    INDEX idx_promotion_status (status),
    FULLTEXT INDEX idx_promotion_search (promotion_name, description)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Promotion Usage Tracking
CREATE TABLE promotion_usage (
    id INT AUTO_INCREMENT PRIMARY KEY,
    promotion_id INT NOT NULL,
    user_id INT NOT NULL,
    order_id INT NOT NULL,
    discount_amount DECIMAL(10, 2) NOT NULL,
    used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (promotion_id) REFERENCES promotions(promotion_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    INDEX idx_promotion_usage_promotion (promotion_id),
    INDEX idx_promotion_usage_user (user_id),
    INDEX idx_promotion_usage_order (order_id),
    INDEX idx_promotion_usage_date (used_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Inventory Movements (for tracking stock changes)
CREATE TABLE inventory_movements (
    movement_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    store_id INT NOT NULL,
    tenant_id INT NOT NULL,
    movement_type ENUM('purchase', 'sale', 'return', 'adjustment', 'transfer_in', 'transfer_out', 'damage', 'expiry') NOT NULL,
    quantity_change INT NOT NULL COMMENT 'Positive for additions, negative for removals',
    quantity_before INT NOT NULL,
    quantity_after INT NOT NULL,
    reference_type ENUM('order', 'purchase_order', 'adjustment', 'transfer', 'other') NULL,
    reference_id INT NULL COMMENT 'order_id, purchase_order_id, etc.',
    notes TEXT,
    created_by INT NULL COMMENT 'user_id who created this movement',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id),
    FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_inventory_product_store (product_id, store_id),
    INDEX idx_inventory_movement_type (movement_type),
    INDEX idx_inventory_date (created_at),
    INDEX idx_inventory_reference (reference_type, reference_id),
    INDEX idx_inventory_tenant_store (tenant_id, store_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Product Reviews and Ratings
CREATE TABLE product_reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    user_id INT NOT NULL,
    order_id INT NULL COMMENT 'Review associated with specific order',
    rating TINYINT NOT NULL COMMENT '1-5 stars',
    review_title VARCHAR(255),
    review_text TEXT,
    is_verified_purchase TINYINT(1) DEFAULT 0,
    is_approved TINYINT(1) DEFAULT 0 COMMENT '0=pending, 1=approved, 2=rejected',
    helpful_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE SET NULL,
    UNIQUE KEY unique_user_product_order (user_id, product_id, order_id),
    INDEX idx_review_product (product_id),
    INDEX idx_review_user (user_id),
    INDEX idx_review_rating (rating),
    INDEX idx_review_approved (is_approved),
    INDEX idx_review_date (created_at),
    FULLTEXT INDEX idx_review_text_search (review_title, review_text)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User Sessions and Activity (for analytics)
CREATE TABLE user_sessions (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL COMMENT 'NULL for anonymous users',
    tenant_id INT NOT NULL,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    device_type ENUM('mobile', 'tablet', 'desktop', 'unknown') DEFAULT 'unknown',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    last_activity_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    page_views INT DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id),
    INDEX idx_session_user (user_id),
    INDEX idx_session_tenant (tenant_id),
    INDEX idx_session_token (session_token),
    INDEX idx_session_dates (started_at, ended_at),
    INDEX idx_session_activity (last_activity_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User Activity Log (detailed activity tracking)
CREATE TABLE user_activity_log (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    session_id INT NULL,
    tenant_id INT NOT NULL,
    activity_type ENUM('page_view', 'product_view', 'add_to_cart', 'remove_from_cart', 'checkout_start', 'checkout_complete', 'search', 'filter', 'login', 'logout', 'profile_update') NOT NULL,
    entity_type ENUM('product', 'category', 'order', 'page', 'other') NULL,
    entity_id INT NULL,
    metadata JSON COMMENT 'Additional activity data',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (session_id) REFERENCES user_sessions(session_id) ON DELETE SET NULL,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id),
    INDEX idx_activity_user (user_id),
    INDEX idx_activity_session (session_id),
    INDEX idx_activity_type (activity_type),
    INDEX idx_activity_entity (entity_type, entity_id),
    INDEX idx_activity_date (created_at),
    INDEX idx_activity_tenant_date (tenant_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daily Sales Summary (pre-aggregated analytics table)
CREATE TABLE daily_sales_summary (
    id INT AUTO_INCREMENT PRIMARY KEY,
    summary_date DATE NOT NULL,
    tenant_id INT NOT NULL,
    store_id INT NOT NULL,
    total_orders INT DEFAULT 0,
    total_revenue DECIMAL(15, 2) DEFAULT 0.00,
    total_items_sold INT DEFAULT 0,
    avg_order_value DECIMAL(10, 2) DEFAULT 0.00,
    unique_customers INT DEFAULT 0,
    new_customers INT DEFAULT 0,
    cancelled_orders INT DEFAULT 0,
    refunded_amount DECIMAL(15, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    UNIQUE KEY unique_date_tenant_store (summary_date, tenant_id, store_id),
    INDEX idx_summary_date (summary_date),
    INDEX idx_summary_tenant (tenant_id),
    INDEX idx_summary_store (store_id),
    INDEX idx_summary_tenant_date (tenant_id, summary_date),
    INDEX idx_summary_store_date (store_id, summary_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Product Performance Metrics (aggregated product analytics)
CREATE TABLE product_performance (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    store_id INT NOT NULL,
    tenant_id INT NOT NULL,
    metric_date DATE NOT NULL,
    units_sold INT DEFAULT 0,
    revenue DECIMAL(15, 2) DEFAULT 0.00,
    views INT DEFAULT 0,
    add_to_cart_count INT DEFAULT 0,
    conversion_rate DECIMAL(5, 4) DEFAULT 0.0000 COMMENT 'add_to_cart_count / views',
    avg_rating DECIMAL(3, 2) DEFAULT 0.00,
    review_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id),
    UNIQUE KEY unique_product_store_date (product_id, store_id, tenant_id, metric_date),
    INDEX idx_performance_product (product_id),
    INDEX idx_performance_store (store_id),
    INDEX idx_performance_date (metric_date),
    INDEX idx_performance_tenant_date (tenant_id, metric_date),
    INDEX idx_performance_product_date (product_id, metric_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Refunds and Returns
CREATE TABLE refunds (
    refund_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    order_item_id INT NULL COMMENT 'NULL for full order refund',
    refund_type ENUM('full', 'partial', 'item') NOT NULL,
    refund_reason ENUM('defective', 'wrong_item', 'not_as_described', 'customer_request', 'other') NOT NULL,
    refund_amount DECIMAL(15, 2) NOT NULL,
    refund_status ENUM('pending', 'approved', 'rejected', 'processed') DEFAULT 'pending',
    processed_by INT NULL COMMENT 'user_id who processed',
    processed_at TIMESTAMP NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id) ON DELETE SET NULL,
    FOREIGN KEY (processed_by) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_refund_order (order_id),
    INDEX idx_refund_status (refund_status),
    INDEX idx_refund_date (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User Segments (for targeted marketing)
CREATE TABLE user_segments (
    segment_id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id INT NOT NULL,
    segment_name VARCHAR(255) NOT NULL,
    segment_criteria JSON NOT NULL COMMENT 'JSON defining segment rules',
    user_count INT DEFAULT 0,
    status TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id),
    INDEX idx_segment_tenant (tenant_id),
    INDEX idx_segment_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User Segment Membership
CREATE TABLE user_segment_membership (
    id INT AUTO_INCREMENT PRIMARY KEY,
    segment_id INT NOT NULL,
    user_id INT NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (segment_id) REFERENCES user_segments(segment_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_segment (user_id, segment_id),
    INDEX idx_membership_segment (segment_id),
    INDEX idx_membership_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Soft Delete Support: Add deleted_at to key tables
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP NULL AFTER updated_at;
ALTER TABLE products ADD COLUMN deleted_at TIMESTAMP NULL AFTER updated_at;
ALTER TABLE orders ADD COLUMN deleted_at TIMESTAMP NULL AFTER updated_at;
ALTER TABLE stores ADD COLUMN deleted_at TIMESTAMP NULL AFTER updated_at;

-- Add indexes for soft deletes
CREATE INDEX idx_user_deleted ON users(deleted_at);
CREATE INDEX idx_product_deleted ON products(deleted_at);
CREATE INDEX idx_order_deleted ON orders(deleted_at);
CREATE INDEX idx_store_deleted ON stores(deleted_at);

-- ============================================
-- TRIGGERS (for testing trigger knowledge)
-- ============================================

DELIMITER //

-- Trigger: Auto-update inventory when order item is created
CREATE TRIGGER trg_order_item_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_store_id INT;
    DECLARE v_tenant_id INT;
    DECLARE v_current_stock INT;
    
    -- Get store and tenant from order
    SELECT store_id, tenant_id INTO v_store_id, v_tenant_id
    FROM orders
    WHERE order_id = NEW.order_id;
    
    -- Get current stock
    SELECT stock_quantity INTO v_current_stock
    FROM product_store_pricing
    WHERE product_id = NEW.product_id
      AND store_id = v_store_id
      AND tenant_id = v_tenant_id;
    
    -- Update stock quantity
    UPDATE product_store_pricing
    SET stock_quantity = stock_quantity - NEW.quantity,
        updated_at = CURRENT_TIMESTAMP
    WHERE product_id = NEW.product_id
      AND store_id = v_store_id
      AND tenant_id = v_tenant_id;
    
    -- Log inventory movement
    INSERT INTO inventory_movements (
        product_id, store_id, tenant_id, movement_type,
        quantity_change, quantity_before, quantity_after,
        reference_type, reference_id, created_by
    ) VALUES (
        NEW.product_id, v_store_id, v_tenant_id, 'sale',
        -NEW.quantity, v_current_stock, v_current_stock - NEW.quantity,
        'order', NEW.order_id, NULL
    );
END//

-- Trigger: Auto-update order status history
CREATE TRIGGER trg_order_status_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF OLD.order_status != NEW.order_status THEN
        INSERT INTO order_status_history (
            order_id, old_status, new_status, changed_at
        ) VALUES (
            NEW.order_id, OLD.order_status, NEW.order_status, CURRENT_TIMESTAMP
        );
    END IF;
END//

-- Trigger: Update user stats when order is completed
CREATE TRIGGER trg_order_completed_update_user_stats
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.order_status = 5 AND OLD.order_status != 5 THEN
        -- Order just completed
        UPDATE users
        SET total_orders = total_orders + 1,
            total_spent = total_spent + NEW.total_amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = NEW.user_id;
    END IF;
END//

-- Trigger: Update promotion usage count
CREATE TRIGGER trg_promotion_usage_after_insert
AFTER INSERT ON promotion_usage
FOR EACH ROW
BEGIN
    UPDATE promotions
    SET current_uses = current_uses + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE promotion_id = NEW.promotion_id;
END//

DELIMITER ;

-- ============================================
-- STORED PROCEDURES (for testing procedure knowledge)
-- ============================================

DELIMITER //

-- Procedure: Get customer lifetime value
CREATE PROCEDURE sp_get_customer_lifetime_value(
    IN p_user_id INT,
    OUT p_total_revenue DECIMAL(15, 2),
    OUT p_total_orders INT,
    OUT p_avg_order_value DECIMAL(10, 2),
    OUT p_first_order_date TIMESTAMP,
    OUT p_last_order_date TIMESTAMP
)
BEGIN
    SELECT 
        COALESCE(SUM(total_amount), 0),
        COUNT(*),
        COALESCE(AVG(total_amount), 0),
        MIN(order_date),
        MAX(order_date)
    INTO 
        p_total_revenue,
        p_total_orders,
        p_avg_order_value,
        p_first_order_date,
        p_last_order_date
    FROM orders
    WHERE user_id = p_user_id
      AND order_status = 5
      AND deleted_at IS NULL;
END//

-- Procedure: Calculate daily sales summary for a date range
CREATE PROCEDURE sp_calculate_daily_sales_summary(
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_tenant_id INT,
    IN p_store_id INT
)
BEGIN
    INSERT INTO daily_sales_summary (
        summary_date, tenant_id, store_id,
        total_orders, total_revenue, total_items_sold,
        avg_order_value, unique_customers, new_customers,
        cancelled_orders, refunded_amount
    )
    SELECT 
        DATE(o.order_date) AS summary_date,
        o.tenant_id,
        o.store_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.total_amount) AS total_revenue,
        SUM(oi.quantity) AS total_items_sold,
        AVG(o.total_amount) AS avg_order_value,
        COUNT(DISTINCT o.user_id) AS unique_customers,
        COUNT(DISTINCT CASE 
            WHEN DATE(u.registration_date) = DATE(o.order_date) 
            THEN u.user_id 
        END) AS new_customers,
        SUM(CASE WHEN o.order_status = 6 THEN 1 ELSE 0 END) AS cancelled_orders,
        COALESCE(SUM(r.refund_amount), 0) AS refunded_amount
    FROM orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN users u ON o.user_id = u.user_id
    LEFT JOIN refunds r ON o.order_id = r.order_id AND r.refund_status = 'processed'
    WHERE DATE(o.order_date) BETWEEN p_start_date AND p_end_date
      AND o.tenant_id = p_tenant_id
      AND (p_store_id IS NULL OR o.store_id = p_store_id)
      AND o.deleted_at IS NULL
    GROUP BY DATE(o.order_date), o.tenant_id, o.store_id
    ON DUPLICATE KEY UPDATE
        total_orders = VALUES(total_orders),
        total_revenue = VALUES(total_revenue),
        total_items_sold = VALUES(total_items_sold),
        avg_order_value = VALUES(avg_order_value),
        unique_customers = VALUES(unique_customers),
        new_customers = VALUES(new_customers),
        cancelled_orders = VALUES(cancelled_orders),
        refunded_amount = VALUES(refunded_amount),
        updated_at = CURRENT_TIMESTAMP;
END//

-- Procedure: Get top products by revenue
CREATE PROCEDURE sp_get_top_products(
    IN p_limit INT,
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_tenant_id INT
)
BEGIN
    SELECT 
        p.product_id,
        p.product_name,
        pc.category_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.line_total) AS total_revenue,
        COUNT(DISTINCT oi.order_id) AS order_count,
        AVG(oi.unit_price) AS avg_price
    FROM products p
    INNER JOIN product_categories pc ON p.category_id = pc.category_id
    INNER JOIN order_items oi ON p.product_id = oi.product_id
    INNER JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_date BETWEEN p_start_date AND p_end_date
      AND (p_tenant_id IS NULL OR o.tenant_id = p_tenant_id)
      AND o.order_status = 5
      AND o.deleted_at IS NULL
      AND p.deleted_at IS NULL
    GROUP BY p.product_id, p.product_name, pc.category_name
    ORDER BY total_revenue DESC
    LIMIT p_limit;
END//

DELIMITER ;

