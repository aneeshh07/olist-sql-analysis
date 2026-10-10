/* =====================================================================
   02_customer_analysis.sql
   Business questions: Do customers come back? Who are the most valuable
   customers, and how should marketing treat each group?

   Important: customer_id changes with every order. A real person is
   customer_unique_id, so all customer-level analysis uses that column.
   ===================================================================== */


-- Q2.1 Purchase frequency: what share of customers ever buy again?
WITH customer_orders AS (
    SELECT customer_unique_id, COUNT(DISTINCT order_id) AS n_orders
    FROM v_order_summary
    WHERE order_status NOT IN ('canceled', 'unavailable')
    GROUP BY customer_unique_id
)
SELECT CASE WHEN n_orders = 1 THEN '1 order'
            WHEN n_orders = 2 THEN '2 orders'
            ELSE '3+ orders' END                             AS frequency_bucket,
       COUNT(*)                                              AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)    AS pct_of_customers
FROM customer_orders
GROUP BY 1
ORDER BY 1;


-- Q2.2 RFM segmentation (Recency, Frequency, Monetary)
-- Skills: multiple CTEs, NTILE(), CASE-based segmentation
-- Design choice to explain in interviews: almost every customer has
-- exactly 1 order, so NTILE on frequency would split identical values
-- into different scores at random. Frequency is scored with CASE instead.
WITH ref AS (
    SELECT MAX(order_purchase_timestamp)::date + 1 AS ref_date FROM orders
),
base AS (
    SELECT v.customer_unique_id,
           (SELECT ref_date FROM ref) - MAX(v.order_purchase_timestamp)::date AS recency_days,
           COUNT(DISTINCT v.order_id)                                         AS frequency,
           SUM(v.order_revenue)                                               AS monetary
    FROM v_order_summary v
    WHERE v.order_status = 'delivered'
    GROUP BY v.customer_unique_id
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score, -- 5 = most recent
           CASE WHEN frequency = 1 THEN 1
                WHEN frequency = 2 THEN 3
                ELSE 5 END                             AS f_score,
           NTILE(5) OVER (ORDER BY monetary)           AS m_score  -- 5 = highest spend
    FROM base
),
segmented AS (
    SELECT *,
           CASE
               WHEN f_score >= 3 AND r_score >= 4 AND m_score >= 4 THEN 'Champions'
               WHEN f_score >= 3                                   THEN 'Loyal / Repeat'
               WHEN r_score >= 4 AND m_score >= 4                  THEN 'New High-Value'
               WHEN r_score >= 4                                   THEN 'New / Recent'
               WHEN r_score <= 2 AND m_score >= 4                  THEN 'At Risk (High Value)'
               WHEN r_score <= 2                                   THEN 'Hibernating'
               ELSE                                                     'Needs Attention'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                                   AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)         AS pct_customers,
       ROUND(AVG(recency_days))                                   AS avg_recency_days,
       ROUND(AVG(frequency), 2)                                   AS avg_orders,
       ROUND(AVG(monetary), 2)                                    AS avg_spend,
       ROUND(SUM(monetary), 0)                                    AS total_revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS pct_revenue
FROM segmented
GROUP BY segment
ORDER BY total_revenue DESC;


-- Q2.3 Monthly cohort retention
-- Cohort = month of a customer's first purchase.
-- m1 = % of the cohort who bought again 1 month later, and so on.
-- Skills: cohort logic, AGE(), COUNT(DISTINCT) with FILTER
WITH customer_months AS (
    SELECT DISTINCT customer_unique_id, purchase_month
    FROM v_order_summary
    WHERE order_status NOT IN ('canceled', 'unavailable')
),
first_purchase AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM customer_months
    GROUP BY customer_unique_id
),
activity AS (
    SELECT f.cohort_month,
           cm.customer_unique_id,
           (EXTRACT(YEAR  FROM AGE(cm.purchase_month, f.cohort_month)) * 12
          + EXTRACT(MONTH FROM AGE(cm.purchase_month, f.cohort_month)))::int AS month_number
    FROM customer_months cm
    JOIN first_purchase f ON f.customer_unique_id = cm.customer_unique_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_customers
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT a.cohort_month,
       cs.cohort_customers,
       ROUND(100.0 * COUNT(DISTINCT a.customer_unique_id) FILTER (WHERE a.month_number = 1)  / cs.cohort_customers, 2) AS m1_pct,
       ROUND(100.0 * COUNT(DISTINCT a.customer_unique_id) FILTER (WHERE a.month_number = 2)  / cs.cohort_customers, 2) AS m2_pct,
       ROUND(100.0 * COUNT(DISTINCT a.customer_unique_id) FILTER (WHERE a.month_number = 3)  / cs.cohort_customers, 2) AS m3_pct,
       ROUND(100.0 * COUNT(DISTINCT a.customer_unique_id) FILTER (WHERE a.month_number = 6)  / cs.cohort_customers, 2) AS m6_pct,
       ROUND(100.0 * COUNT(DISTINCT a.customer_unique_id) FILTER (WHERE a.month_number = 12) / cs.cohort_customers, 2) AS m12_pct
FROM activity a
JOIN cohort_size cs ON cs.cohort_month = a.cohort_month
WHERE a.cohort_month BETWEEN '2017-01-01' AND '2018-06-01'
GROUP BY a.cohort_month, cs.cohort_customers
ORDER BY a.cohort_month;


-- Q2.4 Average time between 1st and 2nd purchase for repeat customers
-- Skills: ROW_NUMBER() and LEAD()
WITH ordered AS (
    SELECT customer_unique_id,
           order_purchase_timestamp,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS order_seq,
           LEAD(order_purchase_timestamp) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS next_order_ts
    FROM v_order_summary
    WHERE order_status NOT IN ('canceled', 'unavailable')
)
SELECT COUNT(*)                                                       AS repeat_customers,
       ROUND(AVG(next_order_ts::date - order_purchase_timestamp::date)) AS avg_days_to_2nd_order,
       PERCENTILE_CONT(0.5) WITHIN GROUP
           (ORDER BY next_order_ts::date - order_purchase_timestamp::date) AS median_days_to_2nd_order
FROM ordered
WHERE order_seq = 1 AND next_order_ts IS NOT NULL;


-- Q2.5 Customers and revenue by state (where is the demand?)
SELECT customer_state,
       COUNT(DISTINCT customer_unique_id)                               AS customers,
       COUNT(*)                                                         AS orders,
       ROUND(SUM(order_revenue), 0)                                     AS revenue,
       ROUND(100.0 * SUM(order_revenue) / SUM(SUM(order_revenue)) OVER (), 2) AS pct_revenue,
       ROUND(AVG(order_revenue), 2)                                     AS avg_order_value,
       RANK() OVER (ORDER BY SUM(order_revenue) DESC)                   AS revenue_rank
FROM v_order_summary
WHERE order_status NOT IN ('canceled', 'unavailable')
GROUP BY customer_state
ORDER BY revenue_rank;
