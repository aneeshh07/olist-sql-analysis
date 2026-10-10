/* =====================================================================
   06_product_analysis.sql
   Business questions: Which categories drive revenue and satisfaction?
   Which are growing fastest? Does freight cost hurt heavy products?
   ===================================================================== */


-- Q6.1 Top 15 categories by revenue (using the stored function)
SELECT category_name, n_orders, items_sold, revenue, avg_item_price, avg_review_score,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 2) AS pct_revenue
FROM fn_category_performance('2016-01-01', '2018-12-31')
ORDER BY revenue DESC
LIMIT 15;


-- Q6.2 Fastest-growing categories: Jan-Aug 2018 vs Jan-Aug 2017
-- Only categories with meaningful 2017 revenue, so growth % isn't
-- inflated by tiny starting values.
WITH y2017 AS (
    SELECT category_name, revenue
    FROM fn_category_performance('2017-01-01', '2017-08-31')
),
y2018 AS (
    SELECT category_name, revenue
    FROM fn_category_performance('2018-01-01', '2018-08-31')
)
SELECT a.category_name,
       ROUND(a.revenue, 0)                                 AS revenue_2017,
       ROUND(b.revenue, 0)                                 AS revenue_2018,
       ROUND(100.0 * (b.revenue - a.revenue) / a.revenue, 1) AS growth_pct
FROM y2017 a
JOIN y2018 b ON b.category_name = a.category_name
WHERE a.revenue >= 20000
ORDER BY growth_pct DESC
LIMIT 10;


-- Q6.3 Worst-rated categories (min 500 items sold)
SELECT category_name, items_sold, avg_review_score, revenue
FROM fn_category_performance('2016-01-01', '2018-12-31')
WHERE items_sold >= 500
ORDER BY avg_review_score ASC
LIMIT 10;


-- Q6.4 Freight cost as % of item price by product weight
SELECT CASE
           WHEN p.product_weight_g < 500   THEN '1) < 0.5 kg'
           WHEN p.product_weight_g < 2000  THEN '2) 0.5-2 kg'
           WHEN p.product_weight_g < 5000  THEN '3) 2-5 kg'
           WHEN p.product_weight_g < 10000 THEN '4) 5-10 kg'
           ELSE                                 '5) 10+ kg'
       END                                                         AS weight_bucket,
       COUNT(*)                                                    AS items_sold,
       ROUND(AVG(oi.price), 2)                                     AS avg_price,
       ROUND(AVG(oi.freight_value), 2)                             AS avg_freight,
       ROUND(100.0 * SUM(oi.freight_value) / SUM(oi.price), 2)     AS freight_pct_of_price
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
WHERE p.product_weight_g IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- Q6.5 Do more product photos mean more sales per product?
WITH product_sales AS (
    SELECT p.product_id,
           p.product_photos_qty,
           COUNT(oi.order_id) AS units_sold
    FROM products p
    LEFT JOIN order_items oi ON oi.product_id = p.product_id
    WHERE p.product_photos_qty IS NOT NULL
    GROUP BY p.product_id, p.product_photos_qty
)
SELECT CASE WHEN product_photos_qty >= 5 THEN '5+' ELSE product_photos_qty::int::text END AS photos,
       COUNT(*)                     AS products,
       ROUND(AVG(units_sold), 2)    AS avg_units_sold_per_product
FROM product_sales
GROUP BY 1
ORDER BY 1;
