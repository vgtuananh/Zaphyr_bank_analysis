-- Purpose: create the zephyr database and only its four analytical tables.
-- This script deliberately never creates or modifies objects outside zephyr.

CREATE DATABASE IF NOT EXISTS zephyr
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE zephyr;

DROP TABLE IF EXISTS fact_transactions;
DROP TABLE IF EXISTS dim_transaction_type;
DROP TABLE IF EXISTS dim_merchant_category;
DROP TABLE IF EXISTS dim_customer;

CREATE TABLE dim_customer (
  customer_id INT NOT NULL,
  customer_name VARCHAR(100) NOT NULL,
  age_band VARCHAR(20) NOT NULL,
  region VARCHAR(50) NOT NULL,
  customer_segment VARCHAR(30) NOT NULL,
  kyc_verified BOOLEAN NOT NULL,
  account_open_date DATE NOT NULL,
  PRIMARY KEY (customer_id)
) ENGINE=InnoDB;

CREATE TABLE dim_transaction_type (
  transaction_type_id INT NOT NULL,
  type_name VARCHAR(100) NOT NULL,
  channel VARCHAR(50) NOT NULL,
  is_domestic BOOLEAN NOT NULL,
  typical_fee_gbp DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (transaction_type_id)
) ENGINE=InnoDB;

CREATE TABLE dim_merchant_category (
  merchant_category_id INT NOT NULL,
  category_name VARCHAR(100) NOT NULL,
  sector VARCHAR(50) NOT NULL,
  risk_flag VARCHAR(20) NOT NULL,
  PRIMARY KEY (merchant_category_id)
) ENGINE=InnoDB;

CREATE TABLE fact_transactions (
  transaction_id INT NOT NULL,
  customer_id INT NOT NULL,
  transaction_type_id INT NOT NULL,
  merchant_category_id INT NOT NULL,
  transaction_date DATE NOT NULL,
  transaction_datetime DATETIME NOT NULL,
  amount_gbp DECIMAL(18,2) NOT NULL,
  fee_charged_gbp DECIMAL(12,2) NOT NULL,
  transaction_status VARCHAR(20) NOT NULL,
  is_flagged_fraud BOOLEAN NOT NULL,
  fx_rate_used DECIMAL(18,6) NULL,
  device_type VARCHAR(20) NULL,
  failed_reason VARCHAR(100) NULL,
  PRIMARY KEY (transaction_id),
  CONSTRAINT fk_fact_customer
    FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
  CONSTRAINT fk_fact_transaction_type
    FOREIGN KEY (transaction_type_id) REFERENCES dim_transaction_type(transaction_type_id),
  CONSTRAINT fk_fact_merchant_category
    FOREIGN KEY (merchant_category_id) REFERENCES dim_merchant_category(merchant_category_id)
) ENGINE=InnoDB;
