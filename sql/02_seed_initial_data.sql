-- ============================================================================
-- Script: 02_seed_initial_data.sql
-- Description: Generates Date dimension values and initial baseline data.
-- ============================================================================

-- 1. Populate Date Dimension (2025 to 2026)
INSERT INTO dim_date
SELECT 
    TO_CHAR(datum, 'YYYYMMDD')::INT AS date_id,
    datum AS calendar_date,
    EXTRACT(YEAR FROM datum)::INT AS year,
    EXTRACT(QUARTER FROM datum)::INT AS quarter,
    EXTRACT(MONTH FROM datum)::INT AS month,
    TO_CHAR(datum, 'Month') AS month_name,
    EXTRACT(DAY FROM datum)::INT AS day_of_month,
    EXTRACT(DOW FROM datum)::INT AS day_of_week,
    TO_CHAR(datum, 'Day') AS day_name,
    CASE WHEN EXTRACT(DOW FROM datum) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend
FROM GENERATE_SERIES('2025-01-01'::DATE, '2026-12-31'::DATE, '1 day'::INTERVAL) AS datum;

-- 2. Populate Products
INSERT INTO dim_product (product_id, product_name, category, unit_cost) VALUES
(101, '4K Mechanical Display', 'Electronics', 280.00),
(102, 'Ergonomic Desk Chair', 'Furniture', 120.00),
(103, 'Noise-Canceling Headphones', 'Electronics', 150.00),
(104, 'Bamboo Standing Desk', 'Furniture', 320.00);

-- 3. Populate Initial Customers directly into Staging
INSERT INTO stg_customers (customer_id, customer_name, email, tier, region, extracted_at) VALUES
(1001, 'Alice Smith', 'alice@example.com', 'Standard', 'North America', '2025-01-01 08:00:00'),
(1002, 'Bob Jones', 'bob@example.com', 'Gold', 'Europe', '2025-01-01 08:00:00'),
(1003, 'Charlie Brown', 'charlie@example.com', 'Silver', 'APAC', '2025-01-01 08:00:00');

-- 4. Initial Load into Customer Dimension (Baseline Seed)
INSERT INTO dim_customer (customer_id, customer_name, email, tier, region, effective_start_date, effective_end_date, is_current)
SELECT 
    customer_id,
    customer_name,
    email,
    tier,
    region,
    '2025-01-01 00:00:00'::TIMESTAMP,
    '9999-12-31 23:59:59'::TIMESTAMP,
    TRUE
FROM stg_customers;

-- 5. Seed Historical Orders (Q1 2025)
INSERT INTO stg_orders (order_id, customer_id, product_id, order_timestamp, quantity, unit_price) VALUES
(5001, 1001, 101, '2025-01-15 10:30:00', 1, 350.00),
(5002, 1002, 103, '2025-02-10 14:15:00', 2, 199.99),
(5003, 1003, 102, '2025-03-01 09:00:00', 1, 180.00);

-- 6. Load Fact Table with Historical Orders
INSERT INTO fact_sales (date_id, customer_sk, product_sk, order_id, quantity, unit_price, total_amount)
SELECT 
    d.date_id,
    c.customer_sk,
    p.product_sk,
    s.order_id,
    s.quantity,
    s.unit_price,
    (s.quantity * s.unit_price) AS total_amount
FROM stg_orders s
JOIN dim_customer c 
  ON s.customer_id = c.customer_id 
 AND s.order_timestamp >= c.effective_start_date 
 AND s.order_timestamp < c.effective_end_date
JOIN dim_product p 
  ON s.product_id = p.product_id
JOIN dim_date d 
  ON d.calendar_date = s.order_timestamp::DATE;

TRUNCATE TABLE stg_orders;
TRUNCATE TABLE stg_customers;
