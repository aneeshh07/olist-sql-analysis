/* =====================================================================
   01_sales_trends.sql
   Business question: How is the marketplace growing over time?

   Revenue definition used throughout: item price + freight for orders
   that were not canceled or unavailable.
   Date window: Jan 2017 - Aug 2018. Months before and after this have
   very few orders (see 02_data_quality.sql, DQ2) and would distort trends.
   ===================================================================== */


-- Q1.1 Monthly orders, revenue, average order value and MoM growth
-- Skills: CTE, LAG() window function, NULLIF to avoid divide-by-zero
WITH monthly AS (
    SELECT purchase_month,
           COUNT(*)                     AS orders,
           SUM(order_revenue)           AS revenue,
           ROUND(AVG(order_revenue), 2) AS avg_order_value
    FROM v_order_summary
    WHERE order_status NOT IN ('canceled', 'unavailable')
      AND purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY purchase_month
)
SELECT purchase_month,
       orders,
       revenue,
       avg_order_value,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY purchase_month))
             / NULLIF(LAG(revenue) OVER (ORDER BY purchase_month), 0), 1) AS revenue_mom_growth_pct
FROM monthly
ORDER BY purchase_month;


-- Q1.2 Running year-to-date revenue and 3-month moving average
-- Skills: SUM() OVER (PARTITION BY ... ORDER BY ...), window frames
WITH monthly AS (
    SELECT purchase_month, SUM(order_revenue) AS revenue
    FROM v_order_summary
    WHERE order_status NOT IN ('canceled', 'unavailable')
      AND purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY purchase_month
)
SELECT purchase_month,
       revenue,
       SUM(revenue) OVER (PARTITION BY EXTRACT(YEAR FROM purchase_month)
                          ORDER BY purchase_month)                    AS ytd_revenue,
       ROUND(AVG(revenue) OVER (ORDER BY purchase_month
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m
FROM monthly
ORDER BY purchase_month;


-- Q1.3 Year-over-year: Jan-Aug 2017 vs Jan-Aug 2018 (like-for-like)
-- Skills: conditional aggregation with FILTER
SELECT
    SUM(order_revenue) FILTER (WHERE purchase_month BETWEEN '2017-01-01' AND '2017-08-01') AS revenue_2017_jan_aug,
    SUM(order_revenue) FILTER (WHERE purchase_month BETWEEN '2018-01-01' AND '2018-08-01') AS revenue_2018_jan_aug,
    COUNT(*) FILTER (WHERE purchase_month BETWEEN '2017-01-01' AND '2017-08-01')           AS orders_2017_jan_aug,
    COUNT(*) FILTER (WHERE purchase_month BETWEEN '2018-01-01' AND '2018-08-01')           AS orders_2018_jan_aug,
    ROUND(100.0 * (
        SUM(order_revenue) FILTER (WHERE purchase_month BETWEEN '2018-01-01' AND '2018-08-01')
      / NULLIF(SUM(order_revenue) FILTER (WHERE purchase_month BETWEEN '2017-01-01' AND '2017-08-01'), 0)
      - 1), 1)                                                                            AS revenue_yoy_growth_pct
FROM v_order_summary
WHERE order_status NOT IN ('canceled', 'unavailable');


-- Q1.4 When do customers shop? Orders by weekday and time of day
-- Skills: EXTRACT, TO_CHAR, pivoting with FILTER
SELECT EXTRACT(ISODOW FROM order_purchase_timestamp)::int AS weekday_num,
       TO_CHAR(order_purchase_timestamp, 'Dy')            AS weekday,
       COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 0  AND 5)  AS night_00_06,
       COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 6  AND 11) AS morning_06_12,
       COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 12 AND 17) AS afternoon_12_18,
       COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 18 AND 23) AS evening_18_24,
       COUNT(*)                                                                             AS total_orders
FROM v_order_summary
WHERE order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1, 2
ORDER BY 1;


-- Q1.5 Best and worst single days (e.g. Black Friday spike)
-- Skills: RANK() in both directions
WITH daily AS (
    SELECT order_purchase_timestamp::date AS order_date,
           COUNT(*)                       AS orders,
           SUM(order_revenue)             AS revenue
    FROM v_order_summary
    WHERE order_status NOT IN ('canceled', 'unavailable')
      AND purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY 1
), ranked AS (
    SELECT *,
           RANK() OVER (ORDER BY orders DESC) AS rank_best,
           RANK() OVER (ORDER BY orders ASC)  AS rank_worst
    FROM daily
)
SELECT CASE WHEN rank_best <= 5 THEN 'Top 5 day' ELSE 'Bottom 5 day' END AS day_type,
       order_date, TO_CHAR(order_date, 'Dy') AS weekday, orders, revenue
FROM ranked
WHERE rank_best <= 5 OR rank_worst <= 5
ORDER BY orders DESC;
