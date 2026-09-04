-- Dataset: Portfolio KPIs
SELECT
    (
        SELECT ROUND(SUM(total_portfolio_value), 2)
        FROM investment_platform.gold.account_portfolio_summary
    ) AS total_portfolio_value,
    (
        SELECT COUNT(*)
        FROM investment_platform.gold.account_portfolio_summary
    ) AS total_accounts,
    (
        SELECT COUNT(*)
        FROM investment_platform.gold.latest_market_prices
    ) AS total_securities,
    (
        SELECT ROUND(MAX(largest_position_value), 2)
        FROM investment_platform.gold.account_portfolio_summary
    ) AS largest_position;

-- Dataset: Sector Exposure
SELECT *
FROM investment_platform.gold.sector_exposure_summary
ORDER BY ABS(total_sector_value) DESC;

-- Dataset: Asset Type Exposure
SELECT
    asset_type,
    ROUND(SUM(total_market_value), 2) AS total_exposure
FROM investment_platform.gold.security_exposure_report
GROUP BY asset_type
ORDER BY ABS(total_exposure) DESC;

-- Dataset: Security Exposure Details
SELECT
    symbol,
    security_name,
    sector,
    asset_type,
    total_market_value AS total_exposure,
    total_accounts,
    total_net_quantity AS total_quantity
FROM investment_platform.gold.security_exposure_report
ORDER BY ABS(total_market_value) DESC;
