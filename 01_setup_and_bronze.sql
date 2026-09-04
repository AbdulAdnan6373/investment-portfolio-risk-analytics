-- Create the catalog and Medallion schemas.
CREATE CATALOG IF NOT EXISTS investment_platform;
USE CATALOG investment_platform;

CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- Generate 1,000 synthetic investment accounts.
CREATE OR REPLACE TABLE investment_platform.bronze.accounts_raw
USING DELTA
AS
SELECT
    CONCAT('ACC', LPAD(CAST(id AS STRING), 6, '0')) AS account_id,
    CASE WHEN id % 250 = 0 THEN NULL ELSE CONCAT('Customer_', id) END AS customer_name,
    CASE
        WHEN id % 3 = 0 THEN 'RETIREMENT'
        WHEN id % 3 = 1 THEN 'INDIVIDUAL'
        ELSE 'JOINT'
    END AS account_type,
    CASE WHEN id % 10 = 0 THEN 'INACTIVE' ELSE 'ACTIVE' END AS account_status,
    DATE_SUB(CURRENT_DATE(), CAST(id % 1825 AS INT)) AS opened_date,
    CURRENT_TIMESTAMP() AS ingestion_timestamp
FROM RANGE(1, 1001);

-- Create a small security reference table.
CREATE OR REPLACE TABLE investment_platform.bronze.securities_raw
USING DELTA
AS
SELECT
    security_id,
    symbol,
    security_name,
    asset_type,
    sector,
    currency,
    CURRENT_TIMESTAMP() AS ingestion_timestamp
FROM VALUES
    ('SEC001', 'AAPL',  'Apple Inc.',              'STOCK', 'Technology',          'USD'),
    ('SEC002', 'MSFT',  'Microsoft Corporation',   'STOCK', 'Technology',          'USD'),
    ('SEC003', 'GOOGL', 'Alphabet Inc.',            'STOCK', 'Technology',          'USD'),
    ('SEC004', 'AMZN',  'Amazon.com Inc.',          'STOCK', 'Consumer',            'USD'),
    ('SEC005', 'TSLA',  'Tesla Inc.',               'STOCK', 'Automotive',          'USD'),
    ('SEC006', 'JPM',   'JPMorgan Chase & Co.',     'STOCK', 'Financial Services', 'USD'),
    ('SEC007', 'V',     'Visa Inc.',                'STOCK', 'Financial Services', 'USD'),
    ('SEC008', 'JNJ',   'Johnson & Johnson',        'STOCK', 'Healthcare',          'USD'),
    ('SEC009', 'XOM',   'Exxon Mobil Corporation',  'STOCK', 'Energy',              'USD'),
    ('SEC010', 'NVDA',  'NVIDIA Corporation',       'STOCK', 'Technology',          'USD'),
    ('SEC011', 'SPY',   'S&P 500 ETF',              'ETF',   'Diversified',         'USD'),
    ('SEC012', 'BND',   'Total Bond Market ETF',    'ETF',   'Fixed Income',        'USD')
AS securities(security_id, symbol, security_name, asset_type, sector, currency);

-- Generate 50,000 synthetic trades.
CREATE OR REPLACE TABLE investment_platform.bronze.trades_raw
USING DELTA
AS
SELECT
    CONCAT('TRD', LPAD(CAST(id AS STRING), 8, '0')) AS trade_id,
    CONCAT('ACC', LPAD(CAST((id % 1000) + 1 AS STRING), 6, '0')) AS account_id,
    CONCAT('SEC', LPAD(CAST((id % 12) + 1 AS STRING), 3, '0')) AS security_id,
    CASE WHEN id % 10 < 7 THEN 'BUY' ELSE 'SELL' END AS trade_type,
    CAST((id % 100) + 1 AS INT) AS quantity,
    ROUND(50 + (id % 450) + RAND(42), 2) AS trade_price,
    TIMESTAMPADD(MINUTE, -CAST(id % 43200 AS INT), CURRENT_TIMESTAMP()) AS trade_timestamp,
    CURRENT_TIMESTAMP() AS ingestion_timestamp
FROM RANGE(1, 50001);

-- Generate 30 days of hourly prices for 12 securities.
CREATE OR REPLACE TABLE investment_platform.bronze.market_prices_raw
USING DELTA
AS
SELECT
    CONCAT('SEC', LPAD(CAST(s.id AS STRING), 3, '0')) AS security_id,
    ROUND(50 + (s.id * 20) + ((h.id % 24) * 0.25) + RAND(99), 2) AS market_price,
    TIMESTAMPADD(HOUR, -CAST(h.id AS INT), CURRENT_TIMESTAMP()) AS price_timestamp,
    CAST(10000 + ((s.id * (h.id + 1) * 137) % 900000) AS BIGINT) AS trading_volume,
    CURRENT_TIMESTAMP() AS ingestion_timestamp
FROM RANGE(1, 13) AS s
CROSS JOIN RANGE(0, 720) AS h;
