-- Summarize daily trading activity by security.
CREATE OR REPLACE TABLE investment_platform.gold.daily_trade_summary
USING DELTA
AS
SELECT
    DATE(trade_timestamp) AS trade_date,
    security_id,
    COUNT(*) AS total_trades,
    SUM(CASE WHEN trade_type = 'BUY' THEN quantity ELSE 0 END) AS total_buy_quantity,
    SUM(CASE WHEN trade_type = 'SELL' THEN quantity ELSE 0 END) AS total_sell_quantity,
    ROUND(SUM(quantity * trade_price), 2) AS total_trade_value
FROM investment_platform.silver.trades_clean
GROUP BY DATE(trade_timestamp), security_id;

-- Select the newest market price for every security.
CREATE OR REPLACE TABLE investment_platform.gold.latest_market_prices
USING DELTA
AS
WITH ranked_prices AS
(
    SELECT
        security_id,
        market_price,
        price_timestamp,
        trading_volume,
        ROW_NUMBER() OVER (
            PARTITION BY security_id
            ORDER BY price_timestamp DESC
        ) AS price_rank
    FROM investment_platform.silver.market_prices_clean
)
SELECT
    security_id,
    market_price AS latest_market_price,
    price_timestamp AS latest_price_timestamp,
    trading_volume
FROM ranked_prices
WHERE price_rank = 1;

-- Calculate each account's position and current market value by security.
CREATE OR REPLACE TABLE investment_platform.gold.portfolio_positions
USING DELTA
AS
WITH position_quantities AS
(
    SELECT
        account_id,
        security_id,
        SUM(
            CASE
                WHEN trade_type = 'BUY' THEN quantity
                WHEN trade_type = 'SELL' THEN -quantity
                ELSE 0
            END
        ) AS net_quantity
    FROM investment_platform.silver.trades_clean
    GROUP BY account_id, security_id
)
SELECT
    p.account_id,
    p.security_id,
    p.net_quantity,
    m.latest_market_price,
    ROUND(p.net_quantity * m.latest_market_price, 2) AS current_market_value,
    m.latest_price_timestamp
FROM position_quantities AS p
INNER JOIN investment_platform.gold.latest_market_prices AS m
    ON p.security_id = m.security_id
WHERE p.net_quantity <> 0;

-- Create one portfolio summary row per account.
CREATE OR REPLACE TABLE investment_platform.gold.account_portfolio_summary
USING DELTA
AS
SELECT
    account_id,
    COUNT(*) AS total_positions,
    ROUND(SUM(current_market_value), 2) AS total_portfolio_value,
    ROUND(AVG(current_market_value), 2) AS average_position_value,
    ROUND(MAX(current_market_value), 2) AS largest_position_value
FROM investment_platform.gold.portfolio_positions
GROUP BY account_id;

-- Aggregate portfolio risk by security.
CREATE OR REPLACE TABLE investment_platform.gold.security_exposure_summary
USING DELTA
AS
SELECT
    security_id,
    COUNT(DISTINCT account_id) AS total_accounts,
    SUM(net_quantity) AS total_net_quantity,
    ROUND(SUM(current_market_value), 2) AS total_market_value,
    ROUND(AVG(current_market_value), 2) AS average_position_value,
    ROUND(MAX(current_market_value), 2) AS largest_account_position
FROM investment_platform.gold.portfolio_positions
GROUP BY security_id;

-- Add readable reference details to the security risk report.
CREATE OR REPLACE TABLE investment_platform.gold.security_exposure_report
USING DELTA
AS
SELECT
    e.security_id,
    s.symbol,
    s.security_name,
    s.asset_type,
    s.sector,
    s.currency,
    e.total_accounts,
    e.total_net_quantity,
    e.total_market_value,
    e.average_position_value,
    e.largest_account_position
FROM investment_platform.gold.security_exposure_summary AS e
INNER JOIN investment_platform.silver.securities_clean AS s
    ON e.security_id = s.security_id;

-- Aggregate concentration risk by sector.
CREATE OR REPLACE TABLE investment_platform.gold.sector_exposure_summary
USING DELTA
AS
SELECT
    s.sector,
    COUNT(DISTINCT p.security_id) AS total_securities,
    COUNT(DISTINCT p.account_id) AS total_accounts,
    ROUND(SUM(p.current_market_value), 2) AS total_sector_value,
    ROUND(AVG(p.current_market_value), 2) AS average_position_value,
    ROUND(MAX(p.current_market_value), 2) AS largest_position_value
FROM investment_platform.gold.portfolio_positions AS p
INNER JOIN investment_platform.silver.securities_clean AS s
    ON p.security_id = s.security_id
GROUP BY s.sector;
