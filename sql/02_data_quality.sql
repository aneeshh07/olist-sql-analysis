/* =====================================================================
   02_data_quality.sql
   Sanity checks to run BEFORE analysis. Good analysts verify the data
   first; mention these checks in interviews.
   ===================================================================== */

-- DQ1. Row counts per table
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'geolocation',  COUNT(*) FROM geolocation
UNION ALL SELECT 'sellers',      COUNT(*) FROM sellers
UNION ALL SELECT 'products',     COUNT(*) FROM products
UNION ALL SELECT 'orders',       COUNT(*) FROM orders
UNION ALL SELECT 'order_items',  COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',  COUNT(*) FROM order_reviews
ORDER BY table_name;

-- DQ2. Date range covered and orders per year.
-- Expect very few orders at the start (2016) and end (Sep-Oct 2018),
-- which is why trend queries restrict the date window.
SELECT EXTRACT(YEAR FROM order_purchase_timestamp)::int AS year,
       MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order,
       COUNT(*)                      AS orders
FROM orders
GROUP BY 1
ORDER BY 1;

-- DQ3. Order status distribution
SELECT order_status,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- DQ4. Missing values in key order date columns
SELECT COUNT(*) FILTER (WHERE order_approved_at IS NULL)             AS missing_approved,
       COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL)  AS missing_carrier_date,
       COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing_delivered_date,
       COUNT(*) FILTER (WHERE order_status = 'delivered'
                          AND order_delivered_customer_date IS NULL) AS delivered_but_no_date
FROM orders;

-- DQ5. Orders that have no items (expected mostly for canceled/unavailable)
SELECT o.order_status, COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY 2 DESC;

-- DQ6. Logical errors: delivered before purchase
SELECT COUNT(*) AS delivered_before_purchase
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- DQ7. Duplicate review_ids (why review_pk was added in the schema)
SELECT COUNT(*) AS review_ids_used_more_than_once
FROM (SELECT review_id FROM order_reviews GROUP BY review_id HAVING COUNT(*) > 1) d;

-- DQ8. Does payment total match items + freight? (small gaps = vouchers/rounding)
WITH items AS (
    SELECT order_id, SUM(price + freight_value) AS items_total
    FROM order_items GROUP BY order_id
), pay AS (
    SELECT order_id, SUM(payment_value) AS paid_total
    FROM order_payments GROUP BY order_id
)
SELECT COUNT(*)                                                  AS orders_compared,
       COUNT(*) FILTER (WHERE ABS(i.items_total - p.paid_total) > 1) AS mismatch_over_1_unit
FROM items i
JOIN pay p ON p.order_id = i.order_id;

-- DQ9. People vs customer_ids: how many people have more than one customer_id?
SELECT COUNT(DISTINCT customer_id)        AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS unique_people
FROM customers;

-- DQ10. Products without a category
SELECT COUNT(*) AS products_without_category
FROM products
WHERE product_category_name IS NULL;
