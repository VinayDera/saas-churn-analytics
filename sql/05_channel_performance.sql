-- ============================================
-- Query 5: Channel Performance Analysis
-- Business Question: Which acquisition channel
-- brings the best customers?
-- Author: Vinay
-- Date: May 2026
-- ============================================

-- PART A: Channel Overview
-- Volume, Revenue, Churn by Channel
SELECT
    ch.channel_name,
    ch.channel_type,
    COUNT(*)                                    AS total_customers,
    SUM(CASE WHEN s.status = 'active'
             THEN 1 ELSE 0 END)                AS active_customers,
    SUM(CASE WHEN s.status = 'churned'
             THEN 1 ELSE 0 END)                AS churned_customers,
    ROUND(SUM(CASE WHEN s.status = 'churned'
                   THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 2)               AS churn_rate_pct,
    ROUND(AVG(s.mrr_amount), 2)                AS avg_mrr,
    SUM(CASE WHEN s.status = 'active'
             THEN s.mrr_amount ELSE 0 END)     AS active_mrr,
    SUM(CASE WHEN s.status = 'active'
             THEN s.mrr_amount ELSE 0 END) * 12 AS active_arr
FROM fact_subscriptions s
JOIN dim_channels ch
    ON s.channel_id = ch.channel_id
GROUP BY ch.channel_name, ch.channel_type
ORDER BY churn_rate_pct ASC;

-- ============================================

-- PART B: Channel Quality Score
-- Best channel = low churn + high MRR + high retention
WITH channel_stats AS (
    SELECT
        ch.channel_name,
        ch.channel_type,
        COUNT(*)                                AS total_customers,
        ROUND(SUM(CASE WHEN s.status = 'churned'
                       THEN 1 ELSE 0 END)
              * 100.0 / COUNT(*), 2)            AS churn_rate,
        ROUND(AVG(s.mrr_amount), 2)             AS avg_mrr,
        SUM(CASE WHEN s.status = 'active'
                 THEN s.mrr_amount ELSE 0 END)  AS total_active_mrr
    FROM fact_subscriptions s
    JOIN dim_channels ch ON s.channel_id = ch.channel_id
    GROUP BY ch.channel_name, ch.channel_type
)
SELECT
    channel_name,
    channel_type,
    total_customers,
    churn_rate,
    avg_mrr,
    total_active_mrr,
    -- Quality Score: reward low churn + high MRR
    ROUND(
        (avg_mrr * 0.5)
        + (total_customers * 0.3)
        - (churn_rate * 10)
    , 2)                                        AS channel_quality_score
FROM channel_stats
ORDER BY channel_quality_score DESC;

-- ============================================

-- PART C: Channel + Segment Cross Analysis
-- Which channel brings best customers
-- by company size?
SELECT
    ch.channel_name,
    c.company_size,
    COUNT(*)                                    AS customers,
    ROUND(SUM(CASE WHEN s.status = 'churned'
                   THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 2)               AS churn_rate,
    ROUND(AVG(s.mrr_amount), 2)                AS avg_mrr,
    SUM(CASE WHEN s.status = 'active'
             THEN s.mrr_amount ELSE 0 END)     AS active_mrr
FROM fact_subscriptions s
JOIN dim_channels ch ON s.channel_id = ch.channel_id
JOIN dim_customers c  ON s.customer_id = c.customer_id
GROUP BY ch.channel_name, c.company_size
ORDER BY ch.channel_name, churn_rate ASC;

-- ============================================

-- PART D: Channel Tenure Analysis
-- How long do customers from each
-- channel stay before churning?
SELECT
    ch.channel_name,
    COUNT(*)                                    AS churned_customers,
    ROUND(AVG(
        s.end_date - s.start_date
    ), 0)                                       AS avg_tenure_days,
    ROUND(AVG(
        s.end_date - s.start_date
    ) / 30.0, 1)                                AS avg_tenure_months,
    MIN(s.end_date - s.start_date)              AS min_tenure_days,
    MAX(s.end_date - s.start_date)              AS max_tenure_days,
    ROUND(AVG(s.mrr_amount), 2)                 AS avg_mrr,
    -- Estimated LTV per churned customer
    ROUND(AVG(s.mrr_amount) *
          AVG(s.end_date - s.start_date)
          / 30.0, 2)                            AS estimated_ltv
FROM fact_subscriptions s
JOIN dim_channels ch ON s.channel_id = ch.channel_id
WHERE s.status = 'churned'
AND s.end_date IS NOT NULL
GROUP BY ch.channel_name
ORDER BY avg_tenure_days DESC;