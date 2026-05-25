-- AIDP Medallion Demo SQL snippets
-- Example Catalog: sniwa_test
-- Schema         : production
-- Change the following USE line to your own catalog name before running.
USE `sniwa_test`.`production`;

-- 1. Show demo tables
SHOW TABLES LIKE 'demo_*';

-- 2. Bronze inspection: row counts
SELECT 'customers_raw' AS object_name, COUNT(*) AS row_count FROM `demo_bronze_customers_raw`
UNION ALL SELECT 'products_raw', COUNT(*) FROM `demo_bronze_products_raw`
UNION ALL SELECT 'orders_raw', COUNT(*) FROM `demo_bronze_orders_raw`
UNION ALL SELECT 'order_items_raw', COUNT(*) FROM `demo_bronze_order_items_raw`
UNION ALL SELECT 'web_events_raw', COUNT(*) FROM `demo_bronze_web_events_raw`
UNION ALL SELECT 'reviews_raw', COUNT(*) FROM `demo_bronze_reviews_raw`
UNION ALL SELECT 'ingestion_audit', COUNT(*) FROM `demo_bronze_ingestion_audit`
ORDER BY object_name;

-- 3. Bronze inspection: ingestion audit
SELECT
  ingest_batch_id,
  source_name,
  source_path,
  row_count,
  audit_created_at
FROM `demo_bronze_ingestion_audit`
ORDER BY source_name;

-- 4. Silver inspection: row counts
SELECT 'customers' AS object_name, COUNT(*) AS row_count FROM `demo_silver_customers`
UNION ALL SELECT 'products', COUNT(*) FROM `demo_silver_products`
UNION ALL SELECT 'orders', COUNT(*) FROM `demo_silver_orders`
UNION ALL SELECT 'order_items', COUNT(*) FROM `demo_silver_order_items`
UNION ALL SELECT 'sales_fact', COUNT(*) FROM `demo_silver_sales_fact`
UNION ALL SELECT 'web_events', COUNT(*) FROM `demo_silver_web_events`
UNION ALL SELECT 'reviews', COUNT(*) FROM `demo_silver_reviews`
UNION ALL SELECT 'dq_issues', COUNT(*) FROM `demo_silver_dq_issues`
UNION ALL SELECT 'dq_summary', COUNT(*) FROM `demo_silver_dq_summary`
ORDER BY object_name;

-- 5. Silver inspection: sales fact sample
SELECT
  order_id,
  line_no,
  customer_id,
  product_id,
  category,
  sub_category,
  order_date,
  channel,
  status,
  quantity,
  unit_price,
  discount_amount,
  net_sales,
  gross_margin
FROM `demo_silver_sales_fact`
ORDER BY order_date, order_id, line_no
LIMIT 20;

-- 6. Executive KPI
SELECT *
FROM `demo_gold_executive_kpis`;

-- 7. Daily sales
-- This is the SQL version of the same extraction shown in the Notebook's
-- Python/SQL equivalent extraction step.
SELECT
  order_date,
  channel,
  order_count,
  customer_count,
  units_sold,
  net_sales,
  gross_margin,
  avg_order_value
FROM `demo_gold_daily_sales`
ORDER BY order_date, channel;

-- 8. Top products
-- This is the SQL version of the same extraction shown in the Notebook's
-- Python/SQL equivalent extraction step.
SELECT
  product_id,
  product_name,
  category,
  sub_category,
  brand,
  units_sold,
  net_sales,
  gross_margin,
  avg_rating
FROM `demo_gold_product_performance`
ORDER BY net_sales DESC, product_id
LIMIT 10;

-- 9. Data quality summary
-- This is the SQL version of the same extraction shown in the Notebook's
-- Python/SQL equivalent extraction step.
SELECT
  source_table,
  rule_name,
  severity,
  issue_count,
  last_detected_at
FROM `demo_silver_dq_summary`
ORDER BY issue_count DESC, source_table, rule_name;

-- 10. Optional cleanup: tables
DROP TABLE IF EXISTS `demo_gold_executive_kpis`;
DROP TABLE IF EXISTS `demo_gold_review_summary`;
DROP TABLE IF EXISTS `demo_gold_channel_funnel`;
DROP TABLE IF EXISTS `demo_gold_customer_360`;
DROP TABLE IF EXISTS `demo_gold_product_performance`;
DROP TABLE IF EXISTS `demo_gold_daily_sales`;
DROP TABLE IF EXISTS `demo_silver_dq_summary`;
DROP TABLE IF EXISTS `demo_silver_dq_issues`;
DROP TABLE IF EXISTS `demo_silver_reviews`;
DROP TABLE IF EXISTS `demo_silver_web_events`;
DROP TABLE IF EXISTS `demo_silver_sales_fact`;
DROP TABLE IF EXISTS `demo_silver_order_items`;
DROP TABLE IF EXISTS `demo_silver_orders`;
DROP TABLE IF EXISTS `demo_silver_products`;
DROP TABLE IF EXISTS `demo_silver_customers`;
DROP TABLE IF EXISTS `demo_bronze_ingestion_audit`;
DROP TABLE IF EXISTS `demo_bronze_reviews_raw`;
DROP TABLE IF EXISTS `demo_bronze_web_events_raw`;
DROP TABLE IF EXISTS `demo_bronze_order_items_raw`;
DROP TABLE IF EXISTS `demo_bronze_orders_raw`;
DROP TABLE IF EXISTS `demo_bronze_products_raw`;
DROP TABLE IF EXISTS `demo_bronze_customers_raw`;
