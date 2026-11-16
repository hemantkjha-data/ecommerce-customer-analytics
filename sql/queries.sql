-- ============================================================
-- E-Commerce Customer Analytics — key SQL queries (SQLite)
-- Dataset: 17,940 orders from 3,000 customers, 2024–2025
-- ============================================================

-- 1. Business KPIs
SELECT SUM(revenue) revenue, COUNT(*) orders,
       COUNT(DISTINCT customer_id) customers,
       ROUND(SUM(revenue)/COUNT(DISTINCT order_id),0) avg_order_value,
       ROUND(100.0*SUM(CASE WHEN status='Returned' THEN 1 ELSE 0 END)/COUNT(*),1) return_pct,
       ROUND(100.0*SUM(CASE WHEN status='Cancelled' THEN 1 ELSE 0 END)/COUNT(*),1) cancel_pct
FROM orders;

-- 2. Monthly revenue trend
SELECT substr(order_date,1,7) AS ym, COUNT(*) orders, SUM(revenue) revenue
FROM orders WHERE status='Delivered' GROUP BY ym ORDER BY ym;

-- 3. Category performance
SELECT category, COUNT(*) orders, SUM(revenue) revenue,
       ROUND(AVG(unit_price),0) avg_price
FROM orders WHERE status='Delivered' GROUP BY category ORDER BY revenue DESC;

-- 4. Purchase frequency segments (repeat behaviour)
WITH freq AS (
  SELECT customer_id, COUNT(*) n, SUM(revenue) rev,
         MIN(order_date) first_order, MAX(order_date) last_order
  FROM orders WHERE status='Delivered' GROUP BY customer_id
)
SELECT CASE WHEN n = 1 THEN 'One-time'
            WHEN n <= 3 THEN 'Occasional'
            WHEN n <= 10 THEN 'Regular'
            ELSE 'Loyal' END AS segment,
       COUNT(*) customers, SUM(rev) revenue, ROUND(AVG(n),1) avg_orders
FROM freq GROUP BY segment ORDER BY revenue DESC;

-- 5. ⭐ RFM segmentation with window functions (the showcase query)
-- Recency = days since last order; Frequency = order count; Monetary = total spend.
-- NTILE(5) converts each into a 1–5 quintile score.
WITH rfm AS (
  SELECT customer_id,
         julianday('2025-12-31') - julianday(MAX(order_date)) AS recency,
         COUNT(*) AS frequency,
         SUM(revenue) AS monetary,
         NTILE(5) OVER (ORDER BY julianday(MAX(order_date))) AS r_score,
         NTILE(5) OVER (ORDER BY COUNT(*)) AS f_score,
         NTILE(5) OVER (ORDER BY SUM(revenue)) AS m_score
  FROM orders WHERE status='Delivered' GROUP BY customer_id
)
SELECT CASE
         WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
         WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
         WHEN r_score >= 4 AND f_score <= 2 THEN 'New/Promising'
         WHEN r_score >= 3 AND m_score >= 4 THEN 'Big Spenders'
         WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
         WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
         ELSE 'Potential' END AS segment,
       COUNT(*) customers, SUM(monetary) revenue,
       ROUND(AVG(recency),0) avg_recency_days
FROM rfm GROUP BY segment ORDER BY revenue DESC;

-- 6. Dormant high-value customers — the revenue-leakage list
WITH rfm AS (
  SELECT customer_id,
         julianday('2025-12-31') - julianday(MAX(order_date)) AS recency,
         COUNT(*) AS frequency, SUM(revenue) AS monetary,
         NTILE(5) OVER (ORDER BY julianday(MAX(order_date))) AS r_score,
         NTILE(5) OVER (ORDER BY SUM(revenue)) AS m_score
  FROM orders WHERE status='Delivered' GROUP BY customer_id
)
SELECT customer_id, recency, frequency, monetary
FROM rfm
WHERE r_score <= 2 AND m_score >= 4
ORDER BY monetary DESC;

-- 7. Top products by revenue
SELECT product, category, SUM(qty) units, SUM(revenue) revenue
FROM orders WHERE status='Delivered' GROUP BY product ORDER BY revenue DESC LIMIT 10;

-- 8. Payment mix
SELECT payment, COUNT(*) orders, SUM(revenue) revenue,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM orders WHERE status='Delivered'),1) share_pct
FROM orders WHERE status='Delivered' GROUP BY payment;

-- 9. Geography view
SELECT city, COUNT(DISTINCT customer_id) customers, SUM(revenue) revenue
FROM orders WHERE status='Delivered' GROUP BY city ORDER BY revenue DESC;

-- 10. Fulfilment quality: returns & cancellations by category
SELECT category,
       ROUND(100.0*SUM(CASE WHEN status='Returned' THEN 1 ELSE 0 END)/COUNT(*),1) return_pct,
       ROUND(100.0*SUM(CASE WHEN status='Cancelled' THEN 1 ELSE 0 END)/COUNT(*),1) cancel_pct
FROM orders GROUP BY category;
