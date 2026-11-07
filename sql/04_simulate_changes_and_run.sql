-- ============================================================================
-- Script: 04_simulate_changes_and_run.sql
-- Description: Simulates source mutations, executes SCD2, and loads new facts.
-- ============================================================================

-- 1. Ingest delta changes into staging
-- Alice moves from Standard to Platinum and shifts Region to Europe
-- Bob Jones updates email address
-- David Miller is a brand new customer
INSERT INTO stg_customers (customer_id, customer_name, email, tier, region) VALUES
(1001, 'Alice Smith', 'alice.smith@newwork.com', 'Platinum', 'Europe'),
(1002, 'Bob Jones', 'bob.jones@corporate.com', 'Gold', 'Europe'),
(1004, 'David Miller', 'david.m@example.com', 'Standard', 'North America');

-- 2. Execute SCD2 Staging Pipeline
CALL sp_process_scd2_customer();

-- 3. Verify SCD Type 2 versioning in dim_customer
-- Notice: Alice and Bob now have 2 rows each. Older rows have is_current = FALSE.
SELECT 
    customer_sk,
    customer_id,
    customer_name,
    tier,
    region,
    effective_start_date,
    effective_end_date,
    is_current
FROM dim_customer
ORDER BY customer_id, effective_start_date;

-- 4. Ingest new post-migration orders
INSERT INTO stg_orders (order_id, customer_id, product_id, order_timestamp, quantity, unit_price) VALUES
(5004, 1001, 104, CURRENT_TIMESTAMP, 1, 320.00), -- Alice orders as Platinum / Europe
(5005, 1004, 102, CURRENT_TIMESTAMP, 2, 180.00); -- David orders as new customer

-- 5. Load new facts with point-in-time dimensional alignment
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
