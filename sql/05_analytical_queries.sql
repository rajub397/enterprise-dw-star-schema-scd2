-- ============================================================================
-- Script: 05_analytical_queries.sql
-- Description: Business Intelligence and OLAP reporting queries.
-- ============================================================================

-- Query 1: Point-in-Time Attribution vs Current Attribution Audit
-- Demonstrates why SCD Type 2 is critical: Alice's first order is historically 
-- attributed to 'Standard'/'North America', while her second order is 'Platinum'/'Europe'.
SELECT 
    f.order_id,
    d.calendar_date,
    c_hist.customer_name,
    c_hist.tier AS historical_tier_at_sale,
    c_curr.tier AS current_tier,
    c_hist.region AS historical_region_at_sale,
    c_curr.region AS current_region,
    f.total_amount
FROM fact_sales f
JOIN dim_date d ON f.date_id = d.date_id
JOIN dim_customer c_hist ON f.customer_sk = c_hist.customer_sk
JOIN dim_customer c_curr ON c_hist.customer_id = c_curr.customer_id AND c_curr.is_current = TRUE
ORDER BY f.order_id;

-- Query 2: Revenue and Volume by Product Category & Tier at Sale Time
SELECT 
    p.category,
    c.tier AS customer_tier_at_purchase,
    COUNT(f.order_id) AS total_orders,
    SUM(f.quantity) AS total_units_sold,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_product p ON f.product_sk = p.product_sk
JOIN dim_customer c ON f.customer_sk = c.customer_sk
GROUP BY p.category, c.tier
ORDER BY total_revenue DESC;

-- Query 3: Cumulative Customer Spend with Window Functions
SELECT 
    f.order_id,
    c.customer_id,
    c.customer_name,
    d.calendar_date,
    f.total_amount,
    SUM(f.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY d.calendar_date, f.order_id
    ) AS lifetime_running_spend
FROM fact_sales f
JOIN dim_customer c ON f.customer_sk = c.customer_sk
JOIN dim_date d ON f.date_id = d.date_id
ORDER BY c.customer_id, d.calendar_date;
