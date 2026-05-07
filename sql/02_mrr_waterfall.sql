-- ============================================
-- Query 2: MRR Waterfall Analysis
-- Business Question: How is revenue moving
-- every month? Where is it growing/leaking?
-- Author: Vinay
-- Date: May 2026
-- ============================================

-- PART A: Total MRR Overview
SELECT
    SUM(CASE WHEN status = 'active'
             THEN mrr_amount ELSE 0 END)        AS current_mrr,
    SUM(CASE WHEN status = 'active'
             THEN mrr_amount ELSE 0 END) * 12   AS arr,
    COUNT(CASE WHEN status = 'active'
               THEN 1 END)                      AS active_customers,
    ROUND(AVG(CASE WHEN status = 'active'
                   THEN mrr_amount END), 2)     AS avg_mrr_per_customer
FROM fact_subscriptions;

-- ============================================

-- PART B: Monthly New MRR
-- (Revenue from brand new customers each month)
SELECT
    DATE_TRUNC('month', start_date)             AS month,
    COUNT(*)                                    AS new_customers,
    SUM(mrr_amount)                             AS new_mrr
FROM fact_subscriptions
GROUP BY DATE_TRUNC('month', start_date)
ORDER BY month DESC
LIMIT 12;

-- ============================================

-- PART C: Monthly Churned MRR
-- (Revenue lost from cancellations each month)
SELECT
    DATE_TRUNC('month', end_date)               AS churn_month,
    COUNT(*)                                    AS churned_customers,
    SUM(mrr_amount)                             AS churned_mrr,
    ROUND(AVG(mrr_amount), 2)                   AS avg_churned_mrr
FROM fact_subscriptions
WHERE status = 'churned'
AND end_date IS NOT NULL
GROUP BY DATE_TRUNC('month', end_date)
ORDER BY churn_month DESC
LIMIT 12;

-- ============================================

-- PART D: MRR by Plan
-- (Where is our revenue concentrated?)
SELECT
    p.plan_name,
    p.billing_cycle,
    COUNT(*)                                    AS customers,
    SUM(s.mrr_amount)                           AS total_mrr,
    ROUND(SUM(s.mrr_amount) * 100.0 /
          SUM(SUM(s.mrr_amount)) OVER(), 2)     AS mrr_pct,
    ROUND(AVG(s.mrr_amount), 2)                 AS avg_mrr
FROM fact_subscriptions s
JOIN dim_plans p ON s.plan_id = p.plan_id
WHERE s.status = 'active'
GROUP BY p.plan_name, p.billing_cycle
ORDER BY total_mrr DESC;

-- ============================================

-- PART E: MRR by Company Size
-- (Which segment drives most revenue?)
SELECT
    c.company_size,
    COUNT(*)                                    AS customers,
    SUM(s.mrr_amount)                           AS total_mrr,
    ROUND(AVG(s.mrr_amount), 2)                 AS avg_mrr,
    ROUND(SUM(s.mrr_amount) * 100.0 /
          SUM(SUM(s.mrr_amount)) OVER(), 2)     AS mrr_pct
FROM fact_subscriptions s
JOIN dim_customers c ON s.customer_id = c.customer_id
WHERE s.status = 'active'
GROUP BY c.company_size
ORDER BY total_mrr DESC;

-- ============================================

-- PART F: Net Revenue Retention (NRR)
-- Industry benchmark: >100% is healthy
-- Formula: (Starting MRR - Churned MRR) 
--          / Starting MRR * 100
WITH mrr_calc AS (
    SELECT
        SUM(mrr_amount)                         AS total_mrr,
        SUM(CASE WHEN status = 'churned'
                 THEN mrr_amount ELSE 0 END)    AS churned_mrr,
        SUM(CASE WHEN status = 'active'
                 THEN mrr_amount ELSE 0 END)    AS active_mrr
    FROM fact_subscriptions
)
SELECT
    ROUND(total_mrr, 2)                         AS total_mrr,
    ROUND(churned_mrr, 2)                       AS churned_mrr,
    ROUND(active_mrr, 2)                        AS active_mrr,
    ROUND((active_mrr / total_mrr) * 100, 2)    AS nrr_pct
FROM mrr_calc;