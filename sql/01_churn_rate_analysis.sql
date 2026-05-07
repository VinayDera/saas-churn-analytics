-- ============================================
-- Query 1: Churn Rate by Customer Segment
-- Business Question: Which customer segment
-- churns the most?
-- Author: Vinay
-- Date: May 2026
-- ============================================

-- PART A: Overall Churn Rate
SELECT
    status,
    COUNT(*)                                    AS total_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*))
          OVER (), 2)                           AS percentage
FROM fact_subscriptions
GROUP BY status
ORDER BY total_customers DESC;

-- ============================================

-- PART B: Churn Rate by Company Size
SELECT
    c.company_size,
    COUNT(*)                                    AS total_customers,
    SUM(CASE WHEN s.status = 'churned'
             THEN 1 ELSE 0 END)                AS churned_customers,
    SUM(CASE WHEN s.status = 'active'
             THEN 1 ELSE 0 END)                AS active_customers,
    ROUND(SUM(CASE WHEN s.status = 'churned'
                   THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 2)               AS churn_rate_pct
FROM fact_subscriptions s
JOIN dim_customers c
    ON s.customer_id = c.customer_id
GROUP BY c.company_size
ORDER BY churn_rate_pct DESC;

-- ============================================

-- PART C: Churn Rate by Industry
SELECT
    c.industry,
    COUNT(*)                                    AS total_customers,
    SUM(CASE WHEN s.status = 'churned'
             THEN 1 ELSE 0 END)                AS churned,
    ROUND(SUM(CASE WHEN s.status = 'churned'
                   THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 2)               AS churn_rate_pct
FROM fact_subscriptions s
JOIN dim_customers c
    ON s.customer_id = c.customer_id
GROUP BY c.industry
ORDER BY churn_rate_pct DESC;

-- ============================================

-- PART D: Churn Rate by Plan Type
SELECT
    p.plan_name,
    p.billing_cycle,
    COUNT(*)                                    AS total_customers,
    SUM(CASE WHEN s.status = 'churned'
             THEN 1 ELSE 0 END)                AS churned,
    ROUND(SUM(CASE WHEN s.status = 'churned'
                   THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 2)               AS churn_rate_pct,
    ROUND(AVG(s.mrr_amount), 2)                AS avg_mrr
FROM fact_subscriptions s
JOIN dim_plans p
    ON s.plan_id = p.plan_id
GROUP BY p.plan_name, p.billing_cycle
ORDER BY churn_rate_pct DESC;