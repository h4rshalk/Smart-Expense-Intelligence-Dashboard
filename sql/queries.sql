
-- =====================================================
-- Smart Expense Intelligence Dashboard
-- SQL Analysis Queries
-- =====================================================

-- Q1: Total Spend by Category
SELECT 
    category,
    COUNT(*)                                    AS total_transactions,
    ROUND(SUM(transaction_amount), 2)           AS total_spend,
    ROUND(AVG(transaction_amount), 2)           AS avg_transaction,
    ROUND(SUM(transaction_amount) * 100.0 / 
          (SELECT SUM(transaction_amount) 
           FROM transactions), 2)               AS spend_percentage
FROM transactions
GROUP BY category
ORDER BY total_spend DESC;

-- Q2: Month over Month Spend Change (LAG)
WITH monthly_spend AS (
    SELECT 
        month, month_name,
        ROUND(SUM(transaction_amount), 2) AS total_spend
    FROM transactions
    WHERE month < 10
    GROUP BY month, month_name
)
SELECT 
    month, month_name, total_spend,
    LAG(total_spend) OVER (ORDER BY month)   AS prev_month_spend,
    ROUND(total_spend - LAG(total_spend) 
          OVER (ORDER BY month), 2)          AS mom_change,
    ROUND((total_spend - LAG(total_spend) 
          OVER (ORDER BY month)) * 100.0 / 
          LAG(total_spend) 
          OVER (ORDER BY month), 2)          AS mom_pct_change
FROM monthly_spend
ORDER BY month;

-- Q3: Running Total Spend (Cumulative SUM)
WITH monthly AS (
    SELECT month, month_name,
        ROUND(SUM(transaction_amount), 2) AS monthly_spend
    FROM transactions
    WHERE month < 10
    GROUP BY month, month_name
)
SELECT month, month_name, monthly_spend,
    ROUND(SUM(monthly_spend) OVER (ORDER BY month), 2) AS running_total,
    ROUND(SUM(monthly_spend) OVER (ORDER BY month) * 100.0 /
          SUM(monthly_spend) OVER (), 2)               AS cumulative_pct
FROM monthly
ORDER BY month;

-- Q4: Category Spend Rank per Month (RANK)
WITH monthly_cat AS (
    SELECT month_name, month, category,
        ROUND(SUM(transaction_amount), 2) AS total_spend
    FROM transactions
    WHERE month < 10
    GROUP BY month_name, month, category
)
SELECT month_name, category, total_spend,
    RANK() OVER (
        PARTITION BY month ORDER BY total_spend DESC
    ) AS spend_rank
FROM monthly_cat
ORDER BY month, spend_rank;

-- Q5: Top 10 Customers by Total Spend (DENSE_RANK)
WITH customer_spend AS (
    SELECT customer_id, name, surname, gender, age,
        COUNT(*)                          AS total_transactions,
        ROUND(SUM(transaction_amount), 2) AS total_spend,
        ROUND(AVG(transaction_amount), 2) AS avg_transaction
    FROM transactions
    GROUP BY customer_id, name, surname, gender, age
)
SELECT *, DENSE_RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
FROM customer_spend
ORDER BY spend_rank LIMIT 10;

-- Q6: Spend by Gender and Category (Pivot CTE)
WITH base AS (
    SELECT gender, category,
        ROUND(SUM(transaction_amount), 2) AS total_spend
    FROM transactions
    WHERE gender != 'Unknown'
    GROUP BY gender, category
)
SELECT category,
    MAX(CASE WHEN gender = 'F' THEN total_spend END) AS female_spend,
    MAX(CASE WHEN gender = 'M' THEN total_spend END) AS male_spend,
    ROUND(MAX(CASE WHEN gender = 'F' THEN total_spend END) -
          MAX(CASE WHEN gender = 'M' THEN total_spend END), 2) AS difference,
    CASE WHEN MAX(CASE WHEN gender = 'F' THEN total_spend END) >
              MAX(CASE WHEN gender = 'M' THEN total_spend END)
         THEN 'Female Higher' ELSE 'Male Higher' END AS winner
FROM base
GROUP BY category
ORDER BY female_spend DESC;

-- Q7: Weekend vs Weekday Spend by Category
WITH spend_type AS (
    SELECT CASE WHEN is_weekend = 1 THEN 'Weekend' ELSE 'Weekday' END AS day_type,
        category,
        COUNT(*)                          AS transactions,
        ROUND(SUM(transaction_amount), 2) AS total_spend,
        ROUND(AVG(transaction_amount), 2) AS avg_spend
    FROM transactions
    GROUP BY day_type, category
)
SELECT day_type, category, transactions, total_spend, avg_spend,
    ROUND(total_spend * 100.0 / 
          SUM(total_spend) OVER (PARTITION BY day_type), 2) AS pct_within_day_type
FROM spend_type
ORDER BY day_type, total_spend DESC;

-- Q8: Monthly Anomaly Detection (2+ Std Dev)
WITH monthly_avg AS (
    SELECT month, month_name,
        ROUND(AVG(transaction_amount), 2)    AS avg_spend,
        ROUND(STDDEV(transaction_amount), 2) AS std_spend
    FROM transactions WHERE month < 10
    GROUP BY month, month_name
),
anomalies AS (
    SELECT t.month, t.month_name,
        COUNT(*) AS anomaly_count,
        ROUND(SUM(t.transaction_amount), 2) AS anomaly_total,
        ROUND(AVG(t.transaction_amount), 2) AS anomaly_avg
    FROM transactions t
    JOIN monthly_avg m ON t.month = m.month
    WHERE t.transaction_amount > m.avg_spend + (2 * m.std_spend)
    AND t.month < 10
    GROUP BY t.month, t.month_name
)
SELECT month, month_name, anomaly_count, anomaly_total, anomaly_avg,
    RANK() OVER (ORDER BY anomaly_count DESC) AS anomaly_rank
FROM anomalies ORDER BY month;
