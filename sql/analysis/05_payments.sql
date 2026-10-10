/* =====================================================================
   05_payments.sql
   Business question: How do customers pay, and does paying in
   instalments let customers buy more expensive orders?
   ===================================================================== */


-- Q5.1 Payment method share by number of orders and by value
SELECT p.payment_type,
       COUNT(DISTINCT p.order_id)                                         AS orders,
       ROUND(100.0 * COUNT(DISTINCT p.order_id)
             / (SELECT COUNT(DISTINCT order_id) FROM order_payments), 2)   AS pct_orders,
       ROUND(SUM(p.payment_value), 0)                                     AS total_value,
       ROUND(100.0 * SUM(p.payment_value) / SUM(SUM(p.payment_value)) OVER (), 2) AS pct_value,
       ROUND(AVG(p.payment_value), 2)                                     AS avg_payment
FROM order_payments p
GROUP BY p.payment_type
ORDER BY total_value DESC;


-- Q5.2 Credit card instalments vs order value
-- Expect bigger orders to be split into more instalments.
SELECT CASE
           WHEN payment_installments <= 1  THEN '01) 1 (paid in full)'
           WHEN payment_installments <= 3  THEN '02) 2-3'
           WHEN payment_installments <= 6  THEN '03) 4-6'
           WHEN payment_installments <= 10 THEN '04) 7-10'
           ELSE                                 '05) 11+'
       END                                                  AS installment_bucket,
       COUNT(*)                                             AS payments,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)   AS pct_payments,
       ROUND(AVG(payment_value), 2)                         AS avg_payment_value,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY payment_value)::numeric, 2) AS median_payment_value
FROM order_payments
WHERE payment_type = 'credit_card'
GROUP BY 1
ORDER BY 1;


-- Q5.3 Orders paid with more than one method (e.g. card + voucher)
WITH methods AS (
    SELECT order_id,
           COUNT(DISTINCT payment_type)        AS n_methods,
           BOOL_OR(payment_type = 'voucher')   AS used_voucher,
           SUM(payment_value)                  AS order_paid
    FROM order_payments
    GROUP BY order_id
)
SELECT CASE WHEN n_methods > 1 THEN 'Multiple methods' ELSE 'Single method' END AS payment_mix,
       COUNT(*)                                          AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_orders,
       ROUND(100.0 * AVG(used_voucher::int), 2)          AS pct_using_voucher,
       ROUND(AVG(order_paid), 2)                         AS avg_order_paid
FROM methods
GROUP BY 1;


-- Q5.4 Does payment method relate to review score or cancellation?
WITH main_method AS (
    -- the method with the largest amount in each order
    SELECT DISTINCT ON (order_id) order_id, payment_type
    FROM order_payments
    ORDER BY order_id, payment_value DESC
)
SELECT m.payment_type,
       COUNT(*)                                                    AS orders,
       ROUND(100.0 * AVG((v.order_status = 'canceled')::int), 2)   AS pct_canceled,
       ROUND(AVG(v.review_score), 2)                               AS avg_review_score
FROM main_method m
JOIN v_order_summary v ON v.order_id = m.order_id
GROUP BY m.payment_type
ORDER BY orders DESC;
