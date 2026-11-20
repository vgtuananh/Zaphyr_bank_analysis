-- Purpose: expose one transaction-level analytical model joining all dimensions.
-- txn_month, fee_gap_gbp, txn_hour and txn_weekday support monthly, fee and temporal analysis.

USE zephyr;

DROP VIEW IF EXISTS v_txn_master;

CREATE VIEW v_txn_master AS
SELECT
  f.transaction_id,
  f.transaction_date,
  f.transaction_datetime,
  DATE_FORMAT(f.transaction_date, '%Y-%m') AS txn_month,
  HOUR(f.transaction_datetime) AS txn_hour,
  DAYNAME(f.transaction_datetime) AS txn_weekday,
  f.amount_gbp,
  f.fee_charged_gbp,
  (f.fee_charged_gbp - tt.typical_fee_gbp) AS fee_gap_gbp,
  f.transaction_status,
  CASE
    WHEN f.transaction_status IN ('Declined', 'Reversed') THEN TRUE
    ELSE FALSE
  END AS is_failed,
  f.is_flagged_fraud,
  f.fx_rate_used,
  f.device_type,
  f.failed_reason,
  c.customer_id,
  c.customer_name,
  c.age_band,
  c.region,
  c.customer_segment,
  c.kyc_verified,
  c.account_open_date,
  tt.transaction_type_id,
  tt.type_name,
  tt.channel,
  tt.is_domestic,
  tt.typical_fee_gbp,
  mc.merchant_category_id,
  mc.category_name,
  mc.sector,
  mc.risk_flag
FROM fact_transactions AS f
INNER JOIN dim_customer AS c
  ON c.customer_id = f.customer_id
INNER JOIN dim_transaction_type AS tt
  ON tt.transaction_type_id = f.transaction_type_id
INNER JOIN dim_merchant_category AS mc
  ON mc.merchant_category_id = f.merchant_category_id;
