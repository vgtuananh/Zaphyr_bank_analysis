-- Purpose: load the four raw CSV files while parsing text dates and TRUE/FALSE booleans.
-- Empty CSV fields become NULL; CRLF is handled by explicitly accepting \r in the line terminator.

USE zephyr;

SET SESSION sql_mode = 'STRICT_ALL_TABLES,NO_ENGINE_SUBSTITUTION';

TRUNCATE TABLE fact_transactions;
DELETE FROM dim_transaction_type;
DELETE FROM dim_merchant_category;
DELETE FROM dim_customer;

LOAD DATA LOCAL INFILE 'data/raw/dim_customer.csv'
INTO TABLE dim_customer
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
  customer_id,
  customer_name,
  age_band,
  region,
  customer_segment,
  @kyc_verified,
  @account_open_date
)
SET
  kyc_verified = CASE LOWER(@kyc_verified)
    WHEN 'true' THEN TRUE
    WHEN 'false' THEN FALSE
    ELSE NULL
  END,
  account_open_date = STR_TO_DATE(NULLIF(TRIM(@account_open_date), ''), '%Y-%m-%d');

LOAD DATA LOCAL INFILE 'data/raw/dim_transaction_type.csv'
INTO TABLE dim_transaction_type
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
  transaction_type_id,
  type_name,
  channel,
  @is_domestic,
  @typical_fee_gbp
)
SET
  is_domestic = CASE LOWER(@is_domestic)
    WHEN 'true' THEN TRUE
    WHEN 'false' THEN FALSE
    ELSE NULL
  END,
  typical_fee_gbp = CAST(NULLIF(TRIM(@typical_fee_gbp), '') AS DECIMAL(12,2));

LOAD DATA LOCAL INFILE 'data/raw/dim_merchant_category.csv'
INTO TABLE dim_merchant_category
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/raw/fact_transactions_updated.csv'
INTO TABLE fact_transactions
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
  transaction_id,
  customer_id,
  transaction_type_id,
  merchant_category_id,
  @transaction_date,
  @transaction_datetime,
  @amount_gbp,
  @fee_charged_gbp,
  transaction_status,
  @is_flagged_fraud,
  @fx_rate_used,
  @device_type,
  @failed_reason
)
SET
  transaction_date = STR_TO_DATE(NULLIF(TRIM(@transaction_date), ''), '%m/%e/%Y'),
  transaction_datetime = STR_TO_DATE(NULLIF(TRIM(@transaction_datetime), ''), '%m/%e/%Y %k:%i'),
  amount_gbp = CAST(NULLIF(TRIM(@amount_gbp), '') AS DECIMAL(18,2)),
  fee_charged_gbp = CAST(NULLIF(TRIM(@fee_charged_gbp), '') AS DECIMAL(12,2)),
  is_flagged_fraud = CASE LOWER(@is_flagged_fraud)
    WHEN 'true' THEN TRUE
    WHEN 'false' THEN FALSE
    ELSE NULL
  END,
  fx_rate_used = CAST(NULLIF(TRIM(@fx_rate_used), '') AS DECIMAL(18,6)),
  device_type = NULLIF(TRIM(@device_type), ''),
  failed_reason = NULLIF(TRIM(@failed_reason), '');
