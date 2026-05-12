-- ============================================
-- Query 4: Revenue at Risk Analysis
-- Business Question: Exactly how much revenue
-- are we about to lose and from where?
-- Author: Vinay
-- Date: May 2026
-- ============================================

-- PART A: Revenue at Risk by Segment
WITH customer_activity AS (
    SELECT
        e.customer_id,
        COUNT(DISTINCT DATE(e.event_ts))        AS active_days,
        COUNT(DISTINCT e.feature_used)          AS feature_variety,
        COUNT(DISTINCT e.session_id)            AS total_sessions,
        EXTRACT(DAY FROM
            NOW() - MAX(e.event_ts))            AS days_since_active,
        COUNT(CASE WHEN e.feature_used = 'api'
                   THEN 1 END)                  AS api_usage_count
    FROM fact_events e
    WHERE e.event_ts >= NOW() - INTERVAL '90 days'
    GROUP BY e.customer_id
),
health_scores AS (
    SELECT
        ca.customer_id,
        LEAST(100, ROUND(
            (ca.active_days * 2)
            + (ca.feature_variety * 5)
            + (ca.total_sessions * 0.5)
            + (ca.api_usage_count * 3)
            - (ca.days_since_active * 1.5)
        , 0))                                   AS health_score
    FROM customer_activity ca
),
risk_classified AS (
    SELECT
        hs.customer_id,
        s.mrr_amount,
        c.company_size,
        c.industry,
        p.plan_name,
        p.billing_cycle,
        hs.health_score,
        CASE
            WHEN hs.health_score >= 70 THEN 'Healthy'
            WHEN hs.health_score >= 40 THEN 'At Risk'
            WHEN hs.health_score >= 0  THEN 'Critical'
            ELSE 'Dormant'
        END                                     AS risk_category
    FROM health_scores hs
    JOIN fact_subscriptions s
        ON hs.customer_id = s.customer_id
    JOIN dim_customers c
        ON hs.customer_id = c.customer_id
    JOIN dim_plans p
        ON s.plan_id = p.plan_id
    WHERE s.status = 'active'
)
SELECT
    company_size,
    risk_category,
    COUNT(*)                                    AS customers,
    SUM(mrr_amount)                             AS mrr_at_risk,
    SUM(mrr_amount) * 12                        AS arr_at_risk,
    ROUND(AVG(mrr_amount), 2)                   AS avg_mrr,
    ROUND(SUM(mrr_amount) * 100.0 /
          SUM(SUM(mrr_amount)) OVER(), 2)       AS pct_of_total_mrr
FROM risk_classified
WHERE risk_category IN ('Critical', 'At Risk', 'Dormant')
GROUP BY company_size, risk_category
ORDER BY arr_at_risk DESC;

-- ============================================

-- PART B: Top 20 Highest Value At-Risk Customers
-- These are the accounts CS must call THIS WEEK
WITH customer_activity AS (
    SELECT
        e.customer_id,
        COUNT(DISTINCT DATE(e.event_ts))        AS active_days,
        COUNT(DISTINCT e.feature_used)          AS feature_variety,
        COUNT(DISTINCT e.session_id)            AS total_sessions,
        EXTRACT(DAY FROM
            NOW() - MAX(e.event_ts))            AS days_since_active,
        COUNT(CASE WHEN e.feature_used = 'api'
                   THEN 1 END)                  AS api_usage_count
    FROM fact_events e
    WHERE e.event_ts >= NOW() - INTERVAL '90 days'
    GROUP BY e.customer_id
),
health_scores AS (
    SELECT
        ca.customer_id,
        ca.days_since_active,
        LEAST(100, ROUND(
            (ca.active_days * 2)
            + (ca.feature_variety * 5)
            + (ca.total_sessions * 0.5)
            + (ca.api_usage_count * 3)
            - (ca.days_since_active * 1.5)
        , 0))                                   AS health_score
    FROM customer_activity ca
)
SELECT
    c.company_name,
    c.company_size,
    c.industry,
    c.csm_owner,
    p.plan_name,
    s.mrr_amount,
    s.mrr_amount * 12                           AS arr_value,
    hs.health_score,
    hs.days_since_active,
    CASE
        WHEN hs.health_score >= 0  THEN 'Critical'
        ELSE 'Dormant'
    END                                         AS risk_category
FROM health_scores hs
JOIN fact_subscriptions s
    ON hs.customer_id = s.customer_id
JOIN dim_customers c
    ON hs.customer_id = c.customer_id
JOIN dim_plans p
    ON s.plan_id = p.plan_id
WHERE s.status = 'active'
AND hs.health_score < 40
ORDER BY s.mrr_amount DESC, hs.health_score ASC
LIMIT 20;

-- ============================================

-- PART C: Financial Impact Summary
-- The ONE number the CEO wants to see
WITH customer_activity AS (
    SELECT
        e.customer_id,
        COUNT(DISTINCT DATE(e.event_ts))        AS active_days,
        COUNT(DISTINCT e.feature_used)          AS feature_variety,
        COUNT(DISTINCT e.session_id)            AS total_sessions,
        EXTRACT(DAY FROM
            NOW() - MAX(e.event_ts))            AS days_since_active,
        COUNT(CASE WHEN e.feature_used = 'api'
                   THEN 1 END)                  AS api_usage_count
    FROM fact_events e
    WHERE e.event_ts >= NOW() - INTERVAL '90 days'
    GROUP BY e.customer_id
),
health_scores AS (
    SELECT
        ca.customer_id,
        LEAST(100, ROUND(
            (ca.active_days * 2)
            + (ca.feature_variety * 5)
            + (ca.total_sessions * 0.5)
            + (ca.api_usage_count * 3)
            - (ca.days_since_active * 1.5)
        , 0))                                   AS health_score
    FROM customer_activity ca
)
SELECT
    -- Total picture
    COUNT(DISTINCT s.customer_id)               AS total_active_customers,
    SUM(s.mrr_amount)                           AS total_mrr,
    SUM(s.mrr_amount) * 12                      AS total_arr,

    -- At risk picture
    SUM(CASE WHEN hs.health_score < 70
             THEN s.mrr_amount ELSE 0 END)      AS total_mrr_at_risk,
    SUM(CASE WHEN hs.health_score < 70
             THEN s.mrr_amount ELSE 0 END) * 12 AS total_arr_at_risk,

    -- Critical only
    SUM(CASE WHEN hs.health_score < 40
             THEN s.mrr_amount ELSE 0 END)      AS critical_mrr,
    SUM(CASE WHEN hs.health_score < 40
             THEN s.mrr_amount ELSE 0 END) * 12 AS critical_arr,

    -- % of revenue at risk
    ROUND(SUM(CASE WHEN hs.health_score < 70
                   THEN s.mrr_amount ELSE 0 END)
          * 100.0 / SUM(s.mrr_amount), 2)       AS pct_mrr_at_risk
FROM fact_subscriptions s
JOIN health_scores hs
    ON s.customer_id = hs.customer_id
WHERE s.status = 'active';