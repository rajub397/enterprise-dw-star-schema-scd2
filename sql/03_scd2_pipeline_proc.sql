-- ============================================================================
-- Script: 03_scd2_pipeline_proc.sql
-- Description: Stored procedure handling automated SCD Type 2 merge logic.
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_process_scd2_customer()
LANGUAGE plpgsql
AS $$
DECLARE
    v_timestamp TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
    -- STEP 1: Expire old versions of updated customer records
    UPDATE dim_customer target
    SET 
        effective_end_date = v_timestamp,
        is_current = FALSE
    FROM stg_customers stage
    WHERE target.customer_id = stage.customer_id
      AND target.is_current = TRUE
      AND (
          target.customer_name != stage.customer_name OR
          target.email         != stage.email OR
          target.tier          != stage.tier OR
          target.region        != stage.region
      );

    -- STEP 2: Insert new versions for updated records AND brand new customers
    INSERT INTO dim_customer (
        customer_id,
        customer_name,
        email,
        tier,
        region,
        effective_start_date,
        effective_end_date,
        is_current
    )
    SELECT 
        stage.customer_id,
        stage.customer_name,
        stage.email,
        stage.tier,
        stage.region,
        v_timestamp,
        '9999-12-31 23:59:59'::TIMESTAMP,
        TRUE
    FROM stg_customers stage
    LEFT JOIN dim_customer existing
      ON stage.customer_id = existing.customer_id
     AND existing.is_current = TRUE
    WHERE existing.customer_id IS NULL -- Brand new customer
       OR (
          existing.customer_name != stage.customer_name OR
          existing.email         != stage.email OR
          existing.tier          != stage.tier OR
          existing.region        != stage.region
       );

    -- STEP 3: Clean up staging after successful ingestion
    TRUNCATE TABLE stg_customers;
    
    RAISE NOTICE 'SCD Type 2 processing completed successfully at %', v_timestamp;
END;
$$;
