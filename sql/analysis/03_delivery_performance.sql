/* =====================================================================
   03_delivery_performance.sql
   Business question: How reliable is delivery, and does a late
   delivery hurt customer satisfaction?
   All queries use delivered orders that have a delivery date.
   ===================================================================== */


-- Q3.1 Overall delivery KPIs
SELECT COUNT(*)                                                     AS delivered_orders,
       ROUND(AVG(delivery_days), 1)                                 AS avg_delivery_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days)   AS median_delivery_days,
       ROUND(100.0 * AVG(is_late::int), 2)                          AS late_pct,
       ROUND(AVG(-days_vs_estimate), 1)                             AS avg_days_earlier_than_estimate
FROM v_order_summary
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- Q3.2 Delivery performance by customer state (min 300 orders)
-- Skills: HAVING, RANK()
SELECT customer_state,
       COUNT(*)                                       AS delivered_orders,
       ROUND(AVG(delivery_days), 1)                   AS avg_delivery_days,
       ROUND(100.0 * AVG(is_late::int), 2)            AS late_pct,
       RANK() OVER (ORDER BY AVG(is_late::int) DESC)  AS worst_late_rank
FROM v_order_summary
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY customer_state
HAVING COUNT(*) >= 300
ORDER BY late_pct DESC;


-- Q3.3 Late vs on-time: impact on review score
SELECT CASE WHEN is_late THEN 'Late' ELSE 'On time / early' END AS delivery_status,
       COUNT(*)                                                 AS orders,
       ROUND(AVG(review_score), 2)                              AS avg_review_score,
       ROUND(100.0 * AVG((review_score <= 2)::int), 2)          AS pct_negative_reviews,
       ROUND(100.0 * AVG((review_score = 5)::int), 2)           AS pct_5_star
FROM v_order_summary
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND review_score IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- Q3.4 How late is too late? Review score by delay bucket
SELECT CASE
           WHEN days_vs_estimate <= -10 THEN '1) 10+ days early'
           WHEN days_vs_estimate <= 0   THEN '2) 0-9 days early'
           WHEN days_vs_estimate <= 3   THEN '3) 1-3 days late'
           WHEN days_vs_estimate <= 7   THEN '4) 4-7 days late'
           WHEN days_vs_estimate <= 14  THEN '5) 8-14 days late'
           ELSE                              '6) 15+ days late'
       END                                              AS delay_bucket,
       COUNT(*)                                         AS orders,
       ROUND(AVG(review_score), 2)                      AS avg_review_score,
       ROUND(100.0 * AVG((review_score <= 2)::int), 2)  AS pct_negative_reviews
FROM v_order_summary
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND review_score IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- Q3.5 Same-state vs cross-state shipping: delivery time and freight
-- Skills: joining sellers to customers through order_items
-- Note: the rare orders with sellers in several states appear once per
-- seller state; this is a small share of orders and doesn't change the picture.
WITH order_route AS (
    SELECT DISTINCT oi.order_id,
           s.seller_state,
           v.customer_state,
           v.delivery_days,
           v.is_late,
           v.freight_value,
           v.items_value
    FROM order_items oi
    JOIN sellers s          ON s.seller_id = oi.seller_id
    JOIN v_order_summary v  ON v.order_id  = oi.order_id
    WHERE v.order_status = 'delivered'
      AND v.order_delivered_customer_date IS NOT NULL
)
SELECT CASE WHEN seller_state = customer_state THEN 'Same state' ELSE 'Cross-state' END AS route_type,
       COUNT(*)                                               AS orders,
       ROUND(AVG(delivery_days), 1)                           AS avg_delivery_days,
       ROUND(100.0 * AVG(is_late::int), 2)                    AS late_pct,
       ROUND(AVG(freight_value), 2)                           AS avg_freight,
       ROUND(100.0 * SUM(freight_value) / SUM(items_value), 2) AS freight_as_pct_of_item_value
FROM order_route
GROUP BY 1;


-- Q3.6 Is delivery getting better? Monthly late % trend
SELECT purchase_month,
       COUNT(*)                             AS delivered_orders,
       ROUND(AVG(delivery_days), 1)         AS avg_delivery_days,
       ROUND(100.0 * AVG(is_late::int), 2)  AS late_pct
FROM v_order_summary
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
GROUP BY purchase_month
ORDER BY purchase_month;
