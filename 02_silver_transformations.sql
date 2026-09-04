-- Retain valid accounts.
CREATE OR REPLACE TABLE investment_platform.silver.accounts_clean
USING DELTA
AS
SELECT account_id, customer_name, account_type, account_status, opened_date, ingestion_timestamp
FROM investment_platform.bronze.accounts_raw
WHERE customer_name IS NOT NULL
  AND account_type IN ('INDIVIDUAL', 'JOINT', 'RETIREMENT')
  AND account_status IN ('ACTIVE', 'INACTIVE');

-- Retain rejected accounts with a reason.
CREATE OR REPLACE TABLE investment_platform.silver.accounts_rejected
USING DELTA
AS
SELECT
    *,
    CASE
        WHEN customer_name IS NULL THEN 'MISSING CUSTOMER NAME'
        WHEN account_type IS NULL THEN 'MISSING ACCOUNT TYPE'
        WHEN account_type NOT IN ('INDIVIDUAL', 'JOINT', 'RETIREMENT') THEN 'INVALID ACCOUNT TYPE'
        WHEN account_status IS NULL THEN 'MISSING ACCOUNT STATUS'
        WHEN account_status NOT IN ('ACTIVE', 'INACTIVE') THEN 'INVALID ACCOUNT STATUS'
    END AS rejection_reason
FROM investment_platform.bronze.accounts_raw
WHERE customer_name IS NULL
   OR account_type IS NULL
   OR account_type NOT IN ('INDIVIDUAL', 'JOINT', 'RETIREMENT')
   OR account_status IS NULL
   OR account_status NOT IN ('ACTIVE', 'INACTIVE');

-- Remove duplicate or invalid security records.
CREATE OR REPLACE TABLE investment_platform.silver.securities_clean
USING DELTA
AS
SELECT DISTINCT
    security_id, symbol, security_name, asset_type, sector, currency, ingestion_timestamp
FROM investment_platform.bronze.securities_raw
WHERE security_id IS NOT NULL
  AND symbol IS NOT NULL
  AND security_name IS NOT NULL
  AND asset_type IN ('STOCK', 'ETF')
  AND currency = 'USD';

-- Retain trades with valid references and numeric values.
CREATE OR REPLACE TABLE investment_platform.silver.trades_clean
USING DELTA
AS
SELECT DISTINCT
    t.trade_id,
    t.account_id,
    t.security_id,
    t.trade_type,
    t.quantity,
    t.trade_price,
    t.trade_timestamp,
    t.ingestion_timestamp
FROM investment_platform.bronze.trades_raw AS t
INNER JOIN investment_platform.silver.accounts_clean AS a
    ON t.account_id = a.account_id
INNER JOIN investment_platform.silver.securities_clean AS s
    ON t.security_id = s.security_id
WHERE t.trade_id IS NOT NULL
  AND t.trade_type IN ('BUY', 'SELL')
  AND t.quantity > 0
  AND t.trade_price > 0;

-- Retain rejected trades with a reason.
CREATE OR REPLACE TABLE investment_platform.silver.trades_rejected
USING DELTA
AS
SELECT
    t.*,
    CASE
        WHEN t.trade_id IS NULL THEN 'MISSING TRADE ID'
        WHEN a.account_id IS NULL THEN 'INVALID OR REJECTED ACCOUNT'
        WHEN s.security_id IS NULL THEN 'INVALID SECURITY'
        WHEN t.trade_type NOT IN ('BUY', 'SELL') THEN 'INVALID TRADE TYPE'
        WHEN t.quantity <= 0 THEN 'INVALID QUANTITY'
        WHEN t.trade_price <= 0 THEN 'INVALID TRADE PRICE'
    END AS rejection_reason
FROM investment_platform.bronze.trades_raw AS t
LEFT JOIN investment_platform.silver.accounts_clean AS a
    ON t.account_id = a.account_id
LEFT JOIN investment_platform.silver.securities_clean AS s
    ON t.security_id = s.security_id
WHERE t.trade_id IS NULL
   OR a.account_id IS NULL
   OR s.security_id IS NULL
   OR t.trade_type NOT IN ('BUY', 'SELL')
   OR t.quantity <= 0
   OR t.trade_price <= 0;

-- Retain valid market-price records.
CREATE OR REPLACE TABLE investment_platform.silver.market_prices_clean
USING DELTA
AS
SELECT DISTINCT
    m.security_id,
    m.market_price,
    m.price_timestamp,
    m.trading_volume,
    m.ingestion_timestamp
FROM investment_platform.bronze.market_prices_raw AS m
INNER JOIN investment_platform.silver.securities_clean AS s
    ON m.security_id = s.security_id
WHERE m.market_price > 0
  AND m.trading_volume >= 0
  AND m.price_timestamp IS NOT NULL;

-- Validate the cleaned market-price table.
SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN market_price <= 0 THEN 1 ELSE 0 END) AS invalid_prices,
    SUM(CASE WHEN trading_volume < 0 THEN 1 ELSE 0 END) AS invalid_volumes,
    SUM(CASE WHEN price_timestamp IS NULL THEN 1 ELSE 0 END) AS missing_timestamps
FROM investment_platform.silver.market_prices_clean;
