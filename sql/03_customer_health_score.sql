-- ============================================
-- Query 3: Customer Health Scoring
-- Business Question: Which customers are most
-- at risk of churning in next 30 days?
-- Author: Vinay
-- Date: May 2026
-- ============================================

-- PART A: Calculate behavioral signals
-- per customer (last 90 days)
WITH customer_activity AS (
    SELECT
        e.customer_id,
        -- How many days were they active?
        COUNT(DISTINCT DATE(e.event_ts))        AS active_days,
        -- How many total actions did they take?
        COUNT(*)                                AS total_events,
        -- How many unique features did they use?
        COUNT(DISTINCT e.feature_used)          AS feature_variety,
        -- How many sessions did they have?
        COUNT(DISTINCT e.session_id)            AS total_sessions,
        -- When did they last use the product?
        MAX(e.event_ts)                         AS last_active_ts,
        -- How many days since last active?
        EXTRACT(DAY FROM
            NOW() - MAX(e.event_ts))            AS days_since_active,
        -- Did they use API? (strong retention signal)
        COUNT(CASE WHEN e.feature_used = 'api'
                   THEN 1 END)                  AS api_usage_count
    FROM fact_events e
    WHERE e.event_ts >= NOW() - INTERVAL '90 days'
    GROUP BY e.customer_id
),

-- PART B: Calculate health score
-- Higher score = healthier customer
health_scores AS (
    SELECT
        ca.customer_id,
        ca.active_days,
        ca.total_events,
        ca.feature_variety,
        ca.total_sessions,
        ca.days_since_active,
        ca.api_usage_count,
        -- Health Score Formula (max 100)
        LEAST(100, ROUND(
            (ca.active_days * 2)              -- active days weighted x2
            + (ca.feature_variety * 5)        -- feature variety weighted x5
            + (ca.total_sessions * 0.5)       -- sessions weighted x0.5
            + (ca.api_usage_count * 3)        -- API usage weighted x3
            - (ca.days_since_active * 1.5)    -- penalize inactivity
        , 0)) AS health_score
    FROM customer_activity ca
)

-- PART C: Final output with customer details
SELECT
    hs.customer_id,
    c.company_name,
    c.company_size,
    c.industry,
    c.csm_owner,
    p.plan_name,
    p.billing_cycle,
    s.mrr_amount,
    hs.active_days,
    hs.total_events,
    hs.feature_variety,
    hs.days_since_active,
    hs.api_usage_count,
    hs.health_score,
    -- Risk Category
    CASE
        WHEN hs.health_score >= 70 THEN 'Healthy'
        WHEN hs.health_score >= 40 THEN 'At Risk'
        WHEN hs.health_score >= 0  THEN 'Critical'
        ELSE 'Dormant'
    END                                         AS risk_category,
    -- Recommended Action
    CASE
        WHEN hs.health_score >= 70
            THEN 'No action needed'
        WHEN hs.health_score >= 40
            THEN 'Send check-in email'
        WHEN hs.health_score >= 0
            THEN 'Immediate CS call required'
        ELSE 'Win-back campaign'
    END                                         AS recommended_action
FROM health_scores hs
JOIN dim_customers c
    ON hs.customer_id = c.customer_id
JOIN fact_subscriptions s
    ON hs.customer_id = s.customer_id
JOIN dim_plans p
    ON s.plan_id = p.plan_id
WHERE s.status = 'active'
ORDER BY hs.health_score ASC;

-- ============================================

-- PART D: Risk Summary
-- How many customers in each risk category?
WITH customer_activity AS (
    SELECT
        e.customer_id,
        COUNT(DISTINCT DATE(e.event_ts))        AS active_days,
        COUNT(*)                                AS total_events,
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
        , 0)) AS health_score
    FROM customer_activity ca
),
risk_categories AS (
    SELECT
        hs.customer_id,
        s.mrr_amount,
        CASE
            WHEN hs.health_score >= 70 THEN 'Healthy'
            WHEN hs.health_score >= 40 THEN 'At Risk'
            WHEN hs.health_score >= 0  THEN 'Critical'
            ELSE 'Dormant'
        END AS risk_category
    FROM health_scores hs
    JOIN fact_subscriptions s
        ON hs.customer_id = s.customer_id
    WHERE s.status = 'active'
)
SELECT
    risk_category,
    COUNT(*)                                    AS total_customers,
    SUM(mrr_amount)                             AS mrr_at_risk,
    SUM(mrr_amount) * 12                        AS arr_at_risk,
    ROUND(AVG(mrr_amount), 2)                   AS avg_mrr
FROM risk_categories
GROUP BY risk_category
ORDER BY
    CASE risk_category
        WHEN 'Critical' THEN 1
        WHEN 'At Risk'  THEN 2
        WHEN 'Healthy'  THEN 3
        ELSE 4
    END;