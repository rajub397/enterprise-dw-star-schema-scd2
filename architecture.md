# Dimensional Architecture & SCD Type 2 Strategy

## 1. Star Schema Model

```
        +-------------------+
        |     dim_date      |
        +-------------------+
        | PK  date_id       |
        |     calendar_date |
        |     year          |
        |     quarter       |
        |     month         |
        |     day_of_week   |
        +---------+---------+
                  |
                  | 1:N
                  |
+-----------------+-----------------+        +---------------------+
|            fact_sales             |        |    dim_customer     |
+-----------------------------------+        +---------------------+
| PK  sales_id                      |  N:1   | PK  customer_sk     |
| FK  date_id                       |--------|     customer_id     |
| FK  customer_sk                   |        |     customer_name   |
| FK  product_sk                    |        |     email           |
|     order_id                      |        |     tier            |
|     quantity                      |        |     region          |
|     unit_price                    |        |     effective_start |
|     total_amount                  |        |     effective_end   |
+-----------------+-----------------+        |     is_current      |
                  |                          +---------------------+
                  | N:1
                  |
        +---------+---------+
        |    dim_product    |
        +-------------------+
        | PK  product_sk    |
        |     product_id    |
        |     product_name  |
        |     category      |
        |     unit_cost     |
        |     is_current    |
        +-------------------+
```

---

## 2. SCD Type 2 Lifecycle Logic

When an operational record updates (e.g., Customer changes loyalty tier or delivery region):

1. **Detection:** Incoming record `customer_id` matches existing dimension record where `is_current = TRUE`, but one or more monitored attributes (`tier`, `region`, `address`) differ.
2. **Expiration:** Update the existing record:
   - `effective_end_date = CURRENT_TIMESTAMP`
   - `is_current = FALSE`
3. **Insertion:** Insert a new record:
   - Assign a new auto-incrementing `customer_sk`.
   - Maintain the original `customer_id`.
   - Set attributes to new incoming values.
   - `effective_start_date = CURRENT_TIMESTAMP`
   - `effective_end_date = '9999-12-31 23:59:59'`
   - `is_current = TRUE`

---

## 3. Fact Table Integrity & Point-in-Time Resolution

Historical transactions must reflect the state of the entity at the time of purchase. 

When loading sales facts:
```sql
SELECT 
    s.order_id,
    c.customer_sk,
    p.product_sk,
    d.date_id,
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
 AND p.is_current = TRUE
JOIN dim_date d 
  ON d.calendar_date = s.order_timestamp::DATE;
```
