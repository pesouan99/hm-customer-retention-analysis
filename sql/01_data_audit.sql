-- H&M Customer Retention Analysis
-- 01_data_audit.sql
-- Purpose: audit raw transaction/customer/article tables before any cleaning decisions.
-- Engine: DuckDB
-- Assumption: raw CSV files are stored locally under ./dataset/ and are NOT committed to GitHub.

-- -------------------------------------------------------------------
-- 0. Create raw views
-- -------------------------------------------------------------------

CREATE OR REPLACE VIEW transactions_raw AS
SELECT *
FROM read_csv_auto('dataset/transactions_train.csv', header = TRUE);

CREATE OR REPLACE VIEW customers_raw AS
SELECT *
FROM read_csv_auto('dataset/customers.csv', header = TRUE);

CREATE OR REPLACE VIEW articles_raw AS
SELECT *
FROM read_csv_auto('dataset/articles.csv', header = TRUE);


-- -------------------------------------------------------------------
-- 1. Transaction table overview
-- -------------------------------------------------------------------

SELECT
    COUNT(*) AS transaction_rows,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(DISTINCT article_id) AS unique_articles,
    MIN(CAST(t_dat AS DATE)) AS min_transaction_date,
    MAX(CAST(t_dat AS DATE)) AS max_transaction_date
FROM transactions_raw;


-- -------------------------------------------------------------------
-- 2. Null audit: transactions
-- -------------------------------------------------------------------

SELECT
    SUM(CASE WHEN t_dat IS NULL THEN 1 ELSE 0 END) AS null_t_dat,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN article_id IS NULL THEN 1 ELSE 0 END) AS null_article_id,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN sales_channel_id IS NULL THEN 1 ELSE 0 END) AS null_sales_channel_id
FROM transactions_raw;


-- -------------------------------------------------------------------
-- 3. Sales channel values and volume
-- -------------------------------------------------------------------

SELECT
    sales_channel_id,
    COUNT(*) AS transaction_rows,
    COUNT(DISTINCT customer_id) AS customers
FROM transactions_raw
GROUP BY sales_channel_id
ORDER BY sales_channel_id;


-- -------------------------------------------------------------------
-- 4. Price audit
--    Do not delete values here. First quantify them.
-- -------------------------------------------------------------------

SELECT
    COUNT(*) AS transaction_rows,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    AVG(price) AS avg_price,
    MEDIAN(price) AS median_price,
    QUANTILE_CONT(price, 0.01) AS p01,
    QUANTILE_CONT(price, 0.25) AS p25,
    QUANTILE_CONT(price, 0.75) AS p75,
    QUANTILE_CONT(price, 0.99) AS p99,
    SUM(CASE WHEN price < 0 THEN 1 ELSE 0 END) AS negative_price_rows,
    SUM(CASE WHEN price = 0 THEN 1 ELSE 0 END) AS zero_price_rows
FROM transactions_raw;


-- -------------------------------------------------------------------
-- 5. Exact duplicate-looking rows
--    These are audited, not automatically removed.
--    Without quantity/order-line IDs, identical rows are not sufficient
--    evidence on their own to prove that one record is erroneous.
-- -------------------------------------------------------------------

WITH duplicate_groups AS (
    SELECT
        t_dat,
        customer_id,
        article_id,
        price,
        sales_channel_id,
        COUNT(*) AS row_count
    FROM transactions_raw
    GROUP BY
        t_dat,
        customer_id,
        article_id,
        price,
        sales_channel_id
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_groups,
    SUM(row_count) AS rows_in_duplicate_groups,
    SUM(row_count - 1) AS potential_extra_rows
FROM duplicate_groups;


-- Optional: inspect the largest duplicate-looking groups
SELECT
    t_dat,
    customer_id,
    article_id,
    price,
    sales_channel_id,
    COUNT(*) AS row_count
FROM transactions_raw
GROUP BY
    t_dat,
    customer_id,
    article_id,
    price,
    sales_channel_id
HAVING COUNT(*) > 1
ORDER BY row_count DESC
LIMIT 100;


-- -------------------------------------------------------------------
-- 6. Customer table overview
-- -------------------------------------------------------------------

SELECT
    COUNT(*) AS customer_rows,
    COUNT(DISTINCT customer_id) AS unique_customer_ids,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN age IS NULL THEN 1 ELSE 0 END) AS null_age,
    MIN(age) AS min_age,
    MAX(age) AS max_age
FROM customers_raw;


-- Customer categorical values
SELECT club_member_status, COUNT(*) AS customers
FROM customers_raw
GROUP BY club_member_status
ORDER BY customers DESC;

SELECT fashion_news_frequency, COUNT(*) AS customers
FROM customers_raw
GROUP BY fashion_news_frequency
ORDER BY customers DESC;


-- -------------------------------------------------------------------
-- 7. Article table overview
-- -------------------------------------------------------------------

SELECT
    COUNT(*) AS article_rows,
    COUNT(DISTINCT article_id) AS unique_article_ids,
    SUM(CASE WHEN article_id IS NULL THEN 1 ELSE 0 END) AS null_article_id
FROM articles_raw;


-- -------------------------------------------------------------------
-- 8. Referential integrity checks
-- -------------------------------------------------------------------

-- Transactions whose customer_id is not found in customers.csv
SELECT
    COUNT(*) AS unmatched_transaction_rows,
    COUNT(DISTINCT t.customer_id) AS unmatched_customers
FROM transactions_raw t
LEFT JOIN customers_raw c
    ON t.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- Transactions whose article_id is not found in articles.csv
SELECT
    COUNT(*) AS unmatched_transaction_rows,
    COUNT(DISTINCT t.article_id) AS unmatched_articles
FROM transactions_raw t
LEFT JOIN articles_raw a
    ON t.article_id = a.article_id
WHERE a.article_id IS NULL;


-- -------------------------------------------------------------------
-- 9. First-purchase date audit
-- -------------------------------------------------------------------

WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(CAST(t_dat AS DATE)) AS first_purchase_date
    FROM transactions_raw
    GROUP BY customer_id
)
SELECT
    MIN(first_purchase_date) AS earliest_first_purchase,
    MAX(first_purchase_date) AS latest_first_purchase,
    COUNT(*) AS customers
FROM first_purchase;


-- -------------------------------------------------------------------
-- 10. 90-day eligibility audit
--     Dataset ends on 2020-09-22, so complete 90-day observation
--     requires first_purchase_date <= 2020-06-24.
-- -------------------------------------------------------------------

WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(CAST(t_dat AS DATE)) AS first_purchase_date
    FROM transactions_raw
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE
        WHEN first_purchase_date <= DATE '2020-06-24' THEN 1
        ELSE 0
    END) AS eligible_90d_customers,
    SUM(CASE
        WHEN first_purchase_date > DATE '2020-06-24' THEN 1
        ELSE 0
    END) AS ineligible_90d_customers
FROM first_purchase;


-- -------------------------------------------------------------------
-- 11. First-purchase-day channel pattern
-- -------------------------------------------------------------------

WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(CAST(t_dat AS DATE)) AS first_purchase_date
    FROM transactions_raw
    GROUP BY customer_id
),
first_day AS (
    SELECT
        t.customer_id,
        COUNT(DISTINCT t.sales_channel_id) AS first_day_channel_count
    FROM transactions_raw t
    INNER JOIN first_purchase f
        ON t.customer_id = f.customer_id
       AND CAST(t.t_dat AS DATE) = f.first_purchase_date
    GROUP BY t.customer_id
)
SELECT
    first_day_channel_count,
    COUNT(*) AS customers
FROM first_day
GROUP BY first_day_channel_count
ORDER BY first_day_channel_count;


-- -------------------------------------------------------------------
-- 12. First-purchase scale/value proxy audit
-- -------------------------------------------------------------------

WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(CAST(t_dat AS DATE)) AS first_purchase_date
    FROM transactions_raw
    GROUP BY customer_id
),
first_day AS (
    SELECT
        t.customer_id,
        COUNT(*) AS first_purchase_record_count,
        COUNT(DISTINCT t.article_id) AS first_purchase_distinct_article_count,
        AVG(t.price) AS first_purchase_avg_price,
        SUM(t.price) AS first_purchase_value_proxy
    FROM transactions_raw t
    INNER JOIN first_purchase f
        ON t.customer_id = f.customer_id
       AND CAST(t.t_dat AS DATE) = f.first_purchase_date
    GROUP BY t.customer_id
)
SELECT
    COUNT(*) AS customers,
    MEDIAN(first_purchase_record_count) AS median_record_count,
    QUANTILE_CONT(first_purchase_record_count, 0.90) AS p90_record_count,
    MEDIAN(first_purchase_distinct_article_count) AS median_distinct_articles,
    MEDIAN(first_purchase_value_proxy) AS median_value_proxy,
    QUANTILE_CONT(first_purchase_value_proxy, 0.90) AS p90_value_proxy
FROM first_day;
