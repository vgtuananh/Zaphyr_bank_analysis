USE zephyr;

-- What are the headline transaction, failure, fraud, value and fee metrics?
-- EXPORT: overall_kpis.csv
SELECT
  COUNT(*) AS transaction_count,
  COUNT(DISTINCT customer_id) AS customer_count,
  COUNT(DISTINCT transaction_type_id) AS transaction_type_count,
  SUM(transaction_status = 'Completed') AS completed_count,
  SUM(transaction_status = 'Declined') AS declined_count,
  SUM(transaction_status = 'Pending') AS pending_count,
  SUM(transaction_status = 'Reversed') AS reversed_count,
  ROUND(100.0 * SUM(is_failed) / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct,
  ROUND(100.0 * SUM(transaction_status = 'Declined') / NULLIF(COUNT(*), 0), 2) AS declined_rate_pct,
  ROUND(100.0 * SUM(transaction_status = 'Pending') / NULLIF(COUNT(*), 0), 2) AS pending_rate_pct,
  SUM(is_flagged_fraud) AS fraud_flagged_count,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp,
  ROUND(SUM(CASE WHEN transaction_status = 'Completed' THEN amount_gbp ELSE 0 END), 2) AS completed_value_gbp,
  ROUND(SUM(fee_charged_gbp), 2) AS fee_revenue_gbp,
  ROUND(SUM(CASE WHEN transaction_status = 'Completed' THEN fee_charged_gbp ELSE 0 END), 2) AS completed_fee_revenue_gbp,
  SUM(is_failed AND failed_reason IS NULL) AS failed_without_reason_count,
  SUM(is_failed) AS failed_count
FROM v_txn_master;

-- How do transaction outcomes, value, fees and fraud flags change by month?
-- EXPORT: by_month.csv
SELECT
  txn_month,
  COUNT(*) AS transaction_count,
  SUM(transaction_status = 'Completed') AS completed_count,
  SUM(transaction_status = 'Declined') AS declined_count,
  SUM(transaction_status = 'Pending') AS pending_count,
  SUM(transaction_status = 'Reversed') AS reversed_count,
  ROUND(100.0 * SUM(is_failed) / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct,
  ROUND(100.0 * SUM(transaction_status = 'Declined') / NULLIF(COUNT(*), 0), 2) AS declined_rate_pct,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp,
  ROUND(SUM(CASE WHEN transaction_status = 'Completed' THEN amount_gbp ELSE 0 END), 2) AS completed_value_gbp,
  ROUND(SUM(fee_charged_gbp), 2) AS fee_revenue_gbp
FROM v_txn_master
GROUP BY txn_month
ORDER BY txn_month;

-- Which transaction types contribute the most transactions, fees, value and failures?
-- EXPORT: by_transaction_type.csv
SELECT
  transaction_type_id,
  type_name,
  channel,
  CASE WHEN is_domestic THEN 'Domestic' ELSE 'International' END AS transaction_scope,
  COUNT(*) AS transaction_count,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp,
  ROUND(SUM(CASE WHEN transaction_status = 'Completed' THEN amount_gbp ELSE 0 END), 2) AS completed_value_gbp,
  ROUND(SUM(fee_charged_gbp), 2) AS fee_revenue_gbp,
  ROUND(MAX(typical_fee_gbp), 2) AS standard_fee_gbp,
  ROUND(100.0 * SUM(is_failed) / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct
FROM v_txn_master
GROUP BY transaction_type_id, type_name, channel, is_domestic
ORDER BY transaction_count DESC, transaction_type_id;

-- Which transaction types have fees below, at or above their stated standard fees?
-- EXPORT: fees_vs_standard.csv
SELECT
  transaction_type_id,
  type_name,
  channel,
  CASE WHEN is_domestic THEN 'Domestic' ELSE 'International' END AS transaction_scope,
  ROUND(typical_fee_gbp, 2) AS standard_fee_gbp,
  COUNT(*) AS transaction_count,
  SUM(fee_charged_gbp < typical_fee_gbp) AS under_charged_rows,
  SUM(fee_charged_gbp = typical_fee_gbp) AS exactly_charged_rows,
  SUM(fee_charged_gbp > typical_fee_gbp) AS over_charged_rows,
  SUM(fee_charged_gbp = 0) AS zero_fee_rows,
  ROUND(SUM(fee_charged_gbp), 2) AS actual_fee_total_gbp,
  ROUND(SUM(typical_fee_gbp), 2) AS standard_fee_total_gbp,
  ROUND(SUM(fee_charged_gbp - typical_fee_gbp), 2) AS fee_gap_total_gbp,
  ROUND(MIN(fee_charged_gbp), 2) AS minimum_actual_fee_gbp,
  ROUND(MAX(fee_charged_gbp), 2) AS maximum_actual_fee_gbp
FROM v_txn_master
GROUP BY transaction_type_id, type_name, channel, is_domestic, typical_fee_gbp
ORDER BY fee_gap_total_gbp, transaction_type_id;

-- Which channels have the highest declined and overall failure rates?
-- EXPORT: by_channel.csv
SELECT
  channel,
  COUNT(*) AS transaction_count,
  SUM(transaction_status = 'Declined') AS declined_count,
  SUM(is_failed) AS failed_count,
  ROUND(100.0 * SUM(transaction_status = 'Declined') / NULLIF(COUNT(*), 0), 2) AS declined_rate_pct,
  ROUND(100.0 * SUM(is_failed) / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp,
  ROUND(SUM(fee_charged_gbp), 2) AS fee_revenue_gbp
FROM v_txn_master
GROUP BY channel
ORDER BY failure_rate_pct DESC;

-- Which merchant categories have the highest fraud-flag rates relative to the overall rate?
-- EXPORT: fraud_by_merchant_category.csv
SELECT
  category_name AS merchant_category,
  COUNT(*) AS transaction_count,
  SUM(is_flagged_fraud) AS fraud_flagged_count,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct,
  ROUND(
    (SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0)) /
    (SELECT SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0) FROM v_txn_master), 2
  ) AS over_index_vs_overall,
  ROUND(SUM(CASE WHEN is_flagged_fraud THEN amount_gbp ELSE 0 END), 2) AS flagged_attempted_value_gbp
FROM v_txn_master
GROUP BY category_name
ORDER BY fraud_flag_rate_pct DESC, transaction_count DESC;

-- Does the merchant risk label distinguish transactions by fraud-flag rate?
-- EXPORT: fraud_by_merchant_risk_flag.csv
SELECT
  risk_flag AS merchant_risk_flag,
  COUNT(*) AS transaction_count,
  SUM(is_flagged_fraud) AS fraud_flagged_count,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct,
  ROUND(
    (SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0)) /
    (SELECT SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0) FROM v_txn_master), 2
  ) AS over_index_vs_overall
FROM v_txn_master
GROUP BY risk_flag
ORDER BY fraud_flag_rate_pct DESC;

-- How do transaction outcomes and fraud flags vary by customer segment?
-- EXPORT: by_segment.csv
SELECT
  customer_segment,
  COUNT(*) AS transaction_count,
  COUNT(DISTINCT customer_id) AS customer_count,
  SUM(is_failed) AS failed_count,
  ROUND(100.0 * SUM(is_failed) / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct,
  SUM(is_flagged_fraud) AS fraud_flagged_count,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp,
  ROUND(SUM(fee_charged_gbp), 2) AS fee_revenue_gbp
FROM v_txn_master
GROUP BY customer_segment
ORDER BY transaction_count DESC;

-- How do transaction outcomes and fraud flags vary by KYC verification status?
-- EXPORT: by_kyc_status.csv
SELECT
  kyc_verified,
  COUNT(*) AS transaction_count,
  COUNT(DISTINCT customer_id) AS customer_count,
  SUM(is_failed) AS failed_count,
  ROUND(100.0 * SUM(is_failed) / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct,
  SUM(is_flagged_fraud) AS fraud_flagged_count,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp,
  ROUND(SUM(fee_charged_gbp), 2) AS fee_revenue_gbp
FROM v_txn_master
GROUP BY kyc_verified
ORDER BY kyc_verified DESC;

-- How do transaction outcomes and fraud flags vary by customer region?
-- EXPORT: by_region.csv
SELECT
  region,
  COUNT(*) AS transaction_count,
  COUNT(DISTINCT customer_id) AS customer_count,
  ROUND(100.0 * SUM(is_failed) / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct,
  SUM(is_flagged_fraud) AS fraud_flagged_count,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp
FROM v_txn_master
GROUP BY region
ORDER BY transaction_count DESC;

-- How do transaction outcomes and fraud flags vary by customer age band?
-- EXPORT: by_age_band.csv
SELECT
  age_band,
  COUNT(*) AS transaction_count,
  COUNT(DISTINCT customer_id) AS customer_count,
  ROUND(100.0 * SUM(is_failed) / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct,
  SUM(is_flagged_fraud) AS fraud_flagged_count,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp
FROM v_txn_master
GROUP BY age_band
ORDER BY transaction_count DESC;

-- How do domestic and international transactions compare in outcome, value and fee revenue?
-- EXPORT: international_vs_domestic.csv
SELECT
  CASE WHEN is_domestic THEN 'Domestic' ELSE 'International' END AS transaction_scope,
  COUNT(*) AS transaction_count,
  SUM(transaction_status = 'Completed') AS completed_count,
  SUM(transaction_status = 'Declined') AS declined_count,
  SUM(transaction_status = 'Pending') AS pending_count,
  SUM(transaction_status = 'Reversed') AS reversed_count,
  ROUND(100.0 * SUM(is_failed) / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp,
  ROUND(SUM(CASE WHEN transaction_status = 'Completed' THEN amount_gbp ELSE 0 END), 2) AS completed_value_gbp,
  ROUND(SUM(fee_charged_gbp), 2) AS fee_revenue_gbp
FROM v_txn_master
GROUP BY is_domestic
ORDER BY is_domestic DESC;

-- Which ten fraud-flagged transactions have the largest attempted amounts?
-- EXPORT: top10_fraud_flagged_by_amount.csv
SELECT
  transaction_id,
  transaction_date,
  customer_id,
  customer_name,
  type_name AS transaction_type,
  transaction_status,
  ROUND(amount_gbp, 2) AS attempted_amount_gbp,
  ROUND(fee_charged_gbp, 2) AS fee_charged_gbp,
  failed_reason
FROM v_txn_master
WHERE is_flagged_fraud = TRUE
ORDER BY amount_gbp DESC, transaction_id
LIMIT 10;

-- Which five customers have the largest attempted transaction value across all statuses?
-- EXPORT: top5_customers_by_attempted_value.csv
SELECT
  customer_id,
  customer_name,
  customer_segment,
  region,
  COUNT(*) AS transaction_count,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp,
  ROUND(SUM(CASE WHEN transaction_status = 'Completed' THEN amount_gbp ELSE 0 END), 2) AS completed_value_gbp,
  SUM(is_flagged_fraud) AS fraud_flagged_count
FROM v_txn_master
GROUP BY customer_id, customer_name, customer_segment, region
ORDER BY attempted_value_gbp DESC
LIMIT 5;

-- Which five customers contribute the most in charged fees?
-- EXPORT: top5_customers_by_fee_revenue.csv
SELECT
  customer_id,
  customer_name,
  customer_segment,
  COUNT(*) AS transaction_count,
  ROUND(SUM(fee_charged_gbp), 2) AS fee_revenue_gbp,
  SUM(transaction_status = 'Completed') AS completed_count,
  ROUND(SUM(CASE WHEN transaction_status = 'Completed' THEN fee_charged_gbp ELSE 0 END), 2) AS completed_fee_revenue_gbp
FROM v_txn_master
GROUP BY customer_id, customer_name, customer_segment
ORDER BY fee_revenue_gbp DESC
LIMIT 5;

-- What would a simple six-month H2 run-rate look like using the observed monthly average?
-- EXPORT: illustrative_h2_run_rate.csv
WITH monthly AS (
  SELECT
    txn_month,
    COUNT(*) AS transaction_count,
    SUM(amount_gbp) AS attempted_value_gbp,
    SUM(CASE WHEN transaction_status = 'Completed' THEN amount_gbp ELSE 0 END) AS completed_value_gbp,
    SUM(fee_charged_gbp) AS fee_revenue_gbp
  FROM v_txn_master
  GROUP BY txn_month
), averages AS (
  SELECT
    COUNT(*) AS observed_month_count,
    AVG(transaction_count) AS avg_monthly_transactions,
    AVG(attempted_value_gbp) AS avg_monthly_attempted_value_gbp,
    AVG(completed_value_gbp) AS avg_monthly_completed_value_gbp,
    AVG(fee_revenue_gbp) AS avg_monthly_fee_revenue_gbp
  FROM monthly
)
SELECT
  'Illustrative only: observed monthly average multiplied by six months' AS scenario_label,
  observed_month_count,
  ROUND(avg_monthly_transactions, 2) AS avg_monthly_transactions,
  ROUND(avg_monthly_transactions * 6, 2) AS illustrative_h2_transactions,
  ROUND(avg_monthly_attempted_value_gbp, 2) AS avg_monthly_attempted_value_gbp,
  ROUND(avg_monthly_attempted_value_gbp * 6, 2) AS illustrative_h2_attempted_value_gbp,
  ROUND(avg_monthly_completed_value_gbp, 2) AS avg_monthly_completed_value_gbp,
  ROUND(avg_monthly_completed_value_gbp * 6, 2) AS illustrative_h2_completed_value_gbp,
  ROUND(avg_monthly_fee_revenue_gbp, 2) AS avg_monthly_fee_revenue_gbp,
  ROUND(avg_monthly_fee_revenue_gbp * 6, 2) AS illustrative_h2_fee_revenue_gbp
FROM averages;

-- Which customers account for fraud flags, and what are their transaction values?
-- EXPORT: fraud_by_customer.csv
SELECT
  customer_id,
  customer_name,
  COUNT(*) AS transaction_count,
  SUM(is_flagged_fraud) AS fraud_flagged_count,
  ROUND(100.0 * SUM(is_flagged_fraud) / NULLIF(COUNT(*), 0), 2) AS fraud_flag_rate_pct,
  SUM(transaction_status = 'Reversed') AS reversed_count,
  ROUND(SUM(amount_gbp), 2) AS attempted_value_gbp,
  ROUND(SUM(CASE WHEN transaction_status = 'Completed' THEN amount_gbp ELSE 0 END), 2) AS completed_value_gbp
FROM v_txn_master
GROUP BY customer_id, customer_name
ORDER BY fraud_flagged_count DESC, attempted_value_gbp DESC;

-- How many rows and how much fee revenue are associated with each transaction status?
-- EXPORT: fees_by_status.csv
SELECT
  transaction_status,
  COUNT(*) AS transaction_count,
  ROUND(SUM(fee_charged_gbp), 2) AS fee_revenue_gbp
FROM v_txn_master
GROUP BY transaction_status
ORDER BY transaction_status;
