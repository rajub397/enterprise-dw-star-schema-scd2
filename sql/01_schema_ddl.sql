-- ============================================================================
-- Script: 01_schema_ddl.sql
-- Description: Creates Staging, Dimensions, and Fact tables with constraints.
-- ============================================================================

DROP TABLE IF EXISTS fact_sales CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;
DROP TABLE IF EXISTS dim_product CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;
DROP TABLE IF EXISTS stg_customers CASCADE;
DROP TABLE IF EXISTS stg_orders CASCADE;

-- ----------------------------------------------------------------------------
-- 1. STAGING TABLES (Untyped / Source Layer)
-- ----------------------------------------------------------------------------
CREATE TABLE stg_customers (
    customer_id     INT,
    customer_name   VARCHAR(100),
    email           VARCHAR(100),
    tier            VARCHAR(20),
    region          VARCHAR(50),
    extracted_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stg_orders (
    order_id        INT,
    customer_id     INT,
    product_id      INT,
    order_timestamp TIMESTAMP,
    quantity        INT,
    unit_price      NUMERIC(10, 2)
);

-- ----------------------------------------------------------------------------
-- 2. DIMENSION TABLES
-- ----------------------------------------------------------------------------
-- Date Dimension
CREATE TABLE dim_date (
    date_id         INT PRIMARY KEY, -- YYYYMMDD
    calendar_date   DATE NOT NULL UNIQUE,
    year            INT NOT NULL,
    quarter         INT NOT NULL,
    month           INT NOT NULL,
    month_name      VARCHAR(10) NOT NULL,
    day_of_month    INT NOT NULL,
    day_of_week     INT NOT NULL,
    day_name        VARCHAR(10) NOT NULL,
    is_weekend      BOOLEAN NOT NULL
);

-- Customer Dimension (SCD Type 2)
CREATE TABLE dim_customer (
    customer_sk          SERIAL PRIMARY KEY,
    customer_id          INT NOT NULL,
    customer_name        VARCHAR(100) NOT NULL,
    email                VARCHAR(100) NOT NULL,
    tier                 VARCHAR(20) NOT NULL,
    region               VARCHAR(50) NOT NULL,
    effective_start_date TIMESTAMP NOT NULL,
    effective_end_date   TIMESTAMP NOT NULL DEFAULT '9999-12-31 23:59:59',
    is_current           BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_dim_cust_lookup ON dim_customer(customer_id, is_current);
CREATE INDEX idx_dim_cust_range ON dim_customer(customer_id, effective_start_date, effective_end_date);

-- Product Dimension (SCD Type 1 / Current State)
CREATE TABLE dim_product (
    product_sk           SERIAL PRIMARY KEY,
    product_id           INT NOT NULL UNIQUE,
    product_name         VARCHAR(100) NOT NULL,
    category             VARCHAR(50) NOT NULL,
    unit_cost            NUMERIC(10, 2) NOT NULL,
    is_current           BOOLEAN NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 3. FACT TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE fact_sales (
    sales_id            BIGSERIAL PRIMARY KEY,
    date_id             INT NOT NULL REFERENCES dim_date(date_id),
    customer_sk         INT NOT NULL REFERENCES dim_customer(customer_sk),
    product_sk          INT NOT NULL REFERENCES dim_product(product_sk),
    order_id            INT NOT NULL,
    quantity            INT NOT NULL CHECK (quantity > 0),
    unit_price          NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    total_amount        NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_fact_sales_date ON fact_sales(date_id);
CREATE INDEX idx_fact_sales_cust ON fact_sales(customer_sk);
CREATE INDEX idx_fact_sales_prod ON fact_sales(product_sk);
