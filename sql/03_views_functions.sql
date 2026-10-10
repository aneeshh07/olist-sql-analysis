/* =====================================================================
   03_views_functions.sql
   Reusable building blocks used by the analysis queries.

   v_order_summary : one clean row per order with revenue, delivery
                     time, late flag and review score already computed.
                     This avoids repeating the same joins in every query.
   fn_category_performance(start, end) : category KPIs for any date range.
   fn_seller_scorecard(seller_id)      : one-row KPI card for a seller.
   ===================================================================== */

DROP VIEW IF EXISTS v_order_summary CASCADE;

CREATE VIEW v_order_summary AS
WITH items AS (
    SELECT order_id,
           COUNT(*)           AS n_items,
           SUM(price)         AS items_value,
           SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
),
reviews AS (
    -- a few orders have more than one review: average them
    SELECT order_id, ROUND(AVG(review_score), 2) AS review_score
    FROM order_reviews
    GROUP BY order_id
),
payments AS (
    SELECT order_id, SUM(payment_value) AS payment_value
    FROM order_payments
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month,
    i.n_items,
    i.items_value,
    i.freight_value,
    i.items_value + i.freight_value                      AS order_revenue,
    p.payment_value,
    r.review_score,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    ROUND((EXTRACT(EPOCH FROM (o.order_delivered_customer_date
                              - o.order_purchase_timestamp)) / 86400)::numeric, 1)
                                                         AS delivery_days,
    -- positive = days late, negative = days early (calendar days)
    o.order_delivered_customer_date::date
        - o.order_estimated_delivery_date::date          AS days_vs_estimate,
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN o.order_delivered_customer_date::date
             > o.order_estimated_delivery_date::date THEN TRUE
        ELSE FALSE
    END                                                  AS is_late
FROM orders o
JOIN customers c  ON c.customer_id = o.customer_id
LEFT JOIN items i    ON i.order_id = o.order_id
LEFT JOIN reviews r  ON r.order_id = o.order_id
LEFT JOIN payments p ON p.order_id = o.order_id;


-- ---------------------------------------------------------------------
-- Category KPIs for any date range (delivered orders only)
-- Usage: SELECT * FROM fn_category_performance('2018-01-01', '2018-06-30');
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_category_performance(p_start DATE, p_end DATE)
RETURNS TABLE (
    category_name    TEXT,
    n_orders         BIGINT,
    items_sold       BIGINT,
    revenue          NUMERIC,
    avg_item_price   NUMERIC,
    avg_review_score NUMERIC
)
LANGUAGE sql STABLE AS
$$
    SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown'),
           COUNT(DISTINCT oi.order_id),
           COUNT(*),
           SUM(oi.price),
           ROUND(AVG(oi.price), 2),
           ROUND(AVG(v.review_score), 2)
    FROM order_items oi
    JOIN v_order_summary v ON v.order_id = oi.order_id
    JOIN products p        ON p.product_id = oi.product_id
    LEFT JOIN product_category_translation t
           ON t.product_category_name = p.product_category_name
    WHERE v.order_status = 'delivered'
      AND v.order_purchase_timestamp >= p_start
      AND v.order_purchase_timestamp <  p_end + 1
    GROUP BY 1
    ORDER BY 4 DESC;
$$;


-- ---------------------------------------------------------------------
-- One-row scorecard for a seller
-- Usage: SELECT * FROM fn_seller_scorecard('<seller_id>');
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_seller_scorecard(p_seller_id VARCHAR)
RETURNS TABLE (
    seller_id          VARCHAR,
    seller_state       CHAR(2),
    n_orders           BIGINT,
    revenue            NUMERIC,
    avg_review_score   NUMERIC,
    late_delivery_pct  NUMERIC,
    first_sale         TIMESTAMP,
    last_sale          TIMESTAMP
)
LANGUAGE sql STABLE AS
$$
    WITH seller_orders AS (
        SELECT oi.order_id, SUM(oi.price) AS seller_revenue
        FROM order_items oi
        WHERE oi.seller_id = p_seller_id
        GROUP BY oi.order_id
    )
    SELECT s.seller_id,
           s.seller_state,
           COUNT(*),
           SUM(so.seller_revenue),
           ROUND(AVG(v.review_score), 2),
           ROUND(100.0 * AVG(v.is_late::int), 2),
           MIN(v.order_purchase_timestamp),
           MAX(v.order_purchase_timestamp)
    FROM seller_orders so
    JOIN v_order_summary v ON v.order_id = so.order_id
    JOIN sellers s         ON s.seller_id = p_seller_id
    WHERE v.order_status = 'delivered'
    GROUP BY s.seller_id, s.seller_state;
$$;
