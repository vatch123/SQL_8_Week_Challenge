-- 1. How many customers has Foodie-Fi ever had?
SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM foodie_fi.subscriptions;

-- Query Results

--  total_customers 
-- -----------------
--             1000


-- 2. What is the monthly distribution of trial plan start_date values for our
--    dataset - use the start of the month as the group by value

SELECT EXTRACT(MONTH FROM start_date) AS months, COUNT(*)
FROM foodie_fi.subscriptions
WHERE plan_id = 0
GROUP BY months
ORDER BY months;

-- Query Results

--  months | count 
-- --------+-------
--       1 |    88
--       2 |    68
--       3 |    94
--       4 |    81
--       5 |    88
--       6 |    79
--       7 |    89
--       8 |    88
--       9 |    87
--      10 |    79
--      11 |    75
--      12 |    84


-- 3.  What plan start_date values occur after the year 2020 for our dataset? Show the 
--     breakdown by count of events for each plan_name

SELECT plan_id, COUNT(*)
FROM foodie_fi.subscriptions
WHERE start_date > '2020-01-01'::DATE
GROUP BY plan_id
ORDER BY plan_id;

-- Query Results

--  plan_id | count 
-- ---------+-------
--        0 |   997
--        1 |   546
--        2 |   539
--        3 |   258
--        4 |   307


-- 4.  What is the customer count and percentage of customers who have churned rounded 
--     to 1 decimal place?

WITH churn_count AS (
    SELECT COUNT(DISTINCT customer_id) AS num
    FROM foodie_fi.subscriptions
    WHERE plan_id = 4
),
total_count AS (
    SELECT COUNT(DISTINCT customer_id) AS num
    FROM foodie_fi.subscriptions
)

SELECT churn_count.num AS num_churned,
       churn_count.num::FLOAT  / total_count.num::FLOAT *100 AS percent_churned
FROM churn_count, total_count;

-- Query Results

--  num_churned | percent_churned 
-- -------------+-----------------
--          307 |            30.7
