-- This query calculates key performance indicators (KPIs) from AWS WAF logs.
-- To run this, you need to load partitions first, for example:
-- MSCK REPAIR TABLE waf_logs;

WITH waf_data AS (
    SELECT
        from_unixtime(timestamp / 1000) as event_time,
        action,
        (CASE
            WHEN terminatingruleid = 'Default_Action' THEN 'Default_Action'
            ELSE terminatingruleid
        END) as matched_rule,
        json_extract_scalar(labels, '$[0].name') as rule_label
    FROM
        waf_logs
    -- Specify the date range you want to query
    -- WHERE date = 'YYYY/MM/DD'
)
SELECT
    COUNT(*) AS total_requests,
    SUM(CASE WHEN action = 'BLOCK' THEN 1 ELSE 0 END) AS blocked_requests,
    (CAST(SUM(CASE WHEN action = 'BLOCK' THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*)) * 100 AS percent_blocked,
    multimap_agg(COALESCE(rule_label, matched_rule), 1) as top_5_attack_vectors
FROM
    waf_data
WHERE
    action = 'BLOCK'
GROUP BY
    1,2,3
ORDER BY
    blocked_requests DESC
LIMIT 5;
