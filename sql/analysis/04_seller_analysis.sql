/* =====================================================================
   04_seller_analysis.sql
   Business questions: Who are the top sellers? Is revenue concentrated
   in a few sellers (Pareto)? Which sellers are hurting the platform?

   Seller revenue = item price only. Freight is passed through to the
   logistics partner, so it isn't counted as the seller's revenue.
   ===================================================================== */


-- Q4.1 Top 10 sellers by revenue, with rating and late %
WITH seller_orders AS (
    SELECT oi.seller_id,
           oi.order_id,
           SUM(oi.price) AS seller_revenue
    FROM order_items oi
    GROUP BY oi.seller_id, oi.order_id
),
seller_kpis AS (
    SELECT so.seller_id,
           COUNT(*)                              AS orders,
           SUM(so.seller_revenue)                AS revenue,
           ROUND(AVG(v.review_score), 2)         AS avg_review_score,
           ROUND(100.0 * AVG(v.is_late::int), 2) AS late_pct
    FROM seller_orders so
    JOIN v_order_summary v ON v.order_id = so.order_id
    WHERE v.order_status = 'delivered'
    GROUP BY so.seller_id
)
SELECT RANK() OVER (ORDER BY k.revenue DESC) AS revenue_rank,
       k.seller_id,
       s.seller_state,
       k.orders,
       k.revenue,
       k.avg_review_score,
       k.late_pct
FROM seller_kpis k
JOIN sellers s ON s.seller_id = k.seller_id
ORDER BY revenue_rank
LIMIT 10;


-- Q4.2 Pareto check: what % of sellers generate 80% of revenue?
-- Skills: running total with window frame, share of total
WITH seller_revenue AS (
    SELECT oi.seller_id, SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
),
ranked AS (
    SELECT seller_id,
           revenue,
           ROW_NUMBER() OVER (ORDER BY revenue DESC) AS seller_rank,
           COUNT(*)     OVER ()                      AS total_sellers,
           SUM(revenue) OVER (ORDER BY revenue DESC
                              ROWS UNBOUNDED PRECEDING)
             / SUM(revenue) OVER ()                  AS cumulative_share
    FROM seller_revenue
)
SELECT MIN(seller_rank)                                           AS sellers_needed_for_80pct_revenue,
       MAX(total_sellers)                                         AS total_sellers,
       ROUND(100.0 * MIN(seller_rank) / MAX(total_sellers), 1)    AS pct_of_sellers
FROM ranked
WHERE cumulative_share >= 0.80;


-- Q4.3 Revenue share by seller decile (top 10% vs the rest)
WITH seller_revenue AS (
    SELECT oi.seller_id, SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
),
deciles AS (
    SELECT seller_id, revenue, NTILE(10) OVER (ORDER BY revenue DESC) AS decile
    FROM seller_revenue
)
SELECT decile,
       COUNT(*)                                                  AS sellers,
       ROUND(SUM(revenue), 0)                                    AS revenue,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS pct_revenue
FROM deciles
GROUP BY decile
ORDER BY decile;


-- Q4.4 Risk list: high-volume sellers with poor ratings (min 50 orders)
-- Action: these sellers need quality review or support
WITH seller_orders AS (
    SELECT DISTINCT seller_id, order_id FROM order_items
)
SELECT so.seller_id,
       s.seller_state,
       COUNT(*)                              AS orders,
       ROUND(AVG(v.review_score), 2)         AS avg_review_score,
       ROUND(100.0 * AVG(v.is_late::int), 2) AS late_pct,
       ROUND(100.0 * AVG((v.review_score <= 2)::int), 2) AS pct_negative_reviews
FROM seller_orders so
JOIN v_order_summary v ON v.order_id = so.order_id
JOIN sellers s         ON s.seller_id = so.seller_id
WHERE v.order_status = 'delivered'
GROUP BY so.seller_id, s.seller_state
HAVING COUNT(*) >= 50
   AND AVG(v.review_score) < 3.5
ORDER BY avg_review_score;


-- Q4.5 Where are sellers located vs where are customers?
WITH seller_states AS (
    SELECT seller_state AS state, COUNT(*) AS sellers
    FROM sellers GROUP BY seller_state
),
customer_states AS (
    SELECT customer_state AS state, COUNT(DISTINCT customer_unique_id) AS customers
    FROM customers GROUP BY customer_state
)
SELECT COALESCE(c.state, s.state)                                   AS state,
       COALESCE(s.sellers, 0)                                       AS sellers,
       COALESCE(c.customers, 0)                                     AS customers,
       ROUND(100.0 * COALESCE(s.sellers, 0)   / SUM(COALESCE(s.sellers, 0))   OVER (), 2) AS pct_sellers,
       ROUND(100.0 * COALESCE(c.customers, 0) / SUM(COALESCE(c.customers, 0)) OVER (), 2) AS pct_customers
FROM customer_states c
FULL OUTER JOIN seller_states s ON s.state = c.state
ORDER BY customers DESC;


-- Q4.6 Example use of the stored function: scorecard for the #1 seller
SELECT *
FROM fn_seller_scorecard((
    SELECT oi.seller_id
    FROM order_items oi
    GROUP BY oi.seller_id
    ORDER BY SUM(oi.price) DESC
    LIMIT 1
));
