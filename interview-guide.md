# Interview Guide

## 1. Explain the project

I built an investment portfolio and risk analytics pipeline in Databricks. It processes account, security, trade, and market-price data through Bronze, Silver, and Gold Delta tables. The final Gold tables support a dashboard for portfolio value and concentration risk.

## 2. Why did you use Bronze, Silver, and Gold layers?

- Bronze keeps the source data.
- Silver validates and cleans the records.
- Gold calculates business metrics used by reports and dashboards.

This separation makes the pipeline easier to test, maintain, and troubleshoot.

## 3. What data-quality checks did you implement?

I checked required fields, allowed account and trade types, positive quantity and prices, non-negative trading volume, duplicates, and valid account and security references. I also retained rejected accounts and trades with a rejection reason.

## 4. Why did you join trades with accounts and securities?

A trade is usable only when its account and security exist in the clean reference tables. Inner joins keep valid matches and prevent unknown accounts or securities from entering financial reports.

## 5. How did you select the latest price?

I used ROW_NUMBER, separated the records by security ID, ordered each security's prices from newest to oldest, and retained row number one.

## 6. How did you calculate a position?

I added BUY quantities and subtracted SELL quantities for each account and security. The result is the net quantity.

## 7. How did you calculate current market value?

I multiplied each position's net quantity by the security's latest market price.

## 8. Why did you use GROUP BY?

GROUP BY combines related records so calculations can be made for each business group. I used it to create daily security summaries, account portfolios, security exposure, and sector exposure.

## 9. What dashboard issue did you find?

The first account KPI added account counts from multiple sectors. One account can invest in several sectors, so that calculation counted some accounts repeatedly. I corrected it by calculating the account total directly from the account-level Gold table.

## 10. Is this implementation streaming?

The current repository implements a batch pipeline with generated data. A production extension would ingest live trades using Kafka and Spark Structured Streaming and would process only new or changed records.

## 11. What would you improve for production?

I would add orchestration, automated tests, alerts, access controls, incremental processing, a schema-change strategy, and monitoring for pipeline runtime and failed records.

## 12. What was the main outcome?

The pipeline created validated, traceable datasets and business-ready reports that show account values, security exposure, sector concentration, and asset-type exposure.
