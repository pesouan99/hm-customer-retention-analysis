# H&M 90-Day Repeat Purchase Analysis

> **Status:** Work in progress

## Project Overview

This project analyses more than 31 million anonymised H&M transaction records to understand which customer and first-purchase characteristics are associated with repeat purchase within 90 days.

The analysis focuses on identifying actionable customer segments, repeat-purchase timing patterns, and product-category relationships that can inform future CRM experiments.

## Business Question

**Which customer and first-purchase characteristics observable at the time of acquisition are associated with repeat purchase within 90 days?**

Based on repeat timing and product-category patterns, which customer segments, contact windows, and product messages should be prioritised for CRM testing?

## Dataset

Source: **H&M Personalized Fashion Recommendations** dataset.

Core files:

- `transactions_train.csv`
- `customers.csv`
- `articles.csv`

The transaction data contains approximately **31.8 million product-level transaction records**, covering about **1.36 million customers** from **2018-09-20 to 2020-09-22**.

Raw dataset files are intentionally not stored in this repository.

## Tools

- DuckDB
- SQL
- Python / pandas
- Power BI
- Excel
- Git / GitHub

## Core Metric

A customer is classified as a **90-day repeat purchaser** if they make at least one purchase on a later date between **Day 1 and Day 90** after their first recorded purchase date.

Customers without a complete 90-day observation window are excluded from the repeat-rate denominator to avoid right-censoring bias.

Because the dataset ends on **2020-09-22**, only customers whose first purchase occurred on or before **2020-06-24** are eligible for the primary 90-day repeat-purchase metric.

## Key Measurement Decisions

- One transaction row is treated as a **product-level purchase record**, not necessarily a complete order.
- Same-day transaction rows do **not** count as repeat purchases.
- Purchase frequency is based on **distinct purchase dates**.
- First-purchase scale is measured using transaction-record count as a proxy.
- `SUM(price)` on the first-purchase date is used as a **first-purchase value proxy**.
- The price field is normalised and must not be interpreted as real currency revenue, sales, or AOV.
- Exact duplicate-looking rows are not automatically removed because the dataset does not include quantity or order-line identifiers.

## Analytical Approach

1. Data quality and transaction-level auditing
2. Customer-level analytical table construction
3. Cohort and 90-day repeat-purchase analysis
4. Customer and first-purchase factor analysis
5. Product-category and repeat-timing analysis
6. Statistical validation
7. Power BI and Excel reporting
8. CRM experiment design
9. One-page stakeholder recommendation memo

## Planned Analytical Base Table

The main analytical table will use **one row per customer** and include:

- first purchase date and acquisition cohort
- first-purchase channel
- customer attributes
- first-purchase transaction-record count
- distinct first-purchase article count
- first-purchase average normalised price
- first-purchase value proxy
- 90-day eligibility flag
- 90-day repeat-purchase outcome
- days to first repeat purchase
- repeat timing and category features

## Scope

### In scope

- 90-day repeat purchase
- cohort analysis
- first-purchase channel
- customer attributes
- first-purchase behaviour
- product-category analysis
- repeat timing
- statistical validation
- Power BI dashboard
- CRM experiment recommendations

### Out of scope

- causal claims from observational data
- real campaign incrementality
- actual A/B test results
- website conversion funnel analysis
- real AOV, LTV, revenue, profit, or CAC
- inventory optimisation
- store-level operations
- real geographic analysis

## Repository Structure

```text
hm-customer-retention-analysis/
├── README.md
├── docs/
│   ├── methodology.md
│   └── metric_definitions.md
├── sql/
├── python/
├── dashboard/
├── images/
└── memo/
```

Additional files will be added as the analysis progresses.

## Current Project Stage

The business question, scope, core retention definition, right-censoring rule, and initial first-purchase metrics have been defined.

The next stage is the **data audit**, followed by construction of the customer-level retention fact table.
