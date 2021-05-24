-- Danny Ma's 8 Week SQL Challenge
-- Week 2

------------------------------------------------------------------------------------
---------------------------------- Pizza Metrics -----------------------------------
------------------------------------------------------------------------------------

/* First clean the given tables */

-- Cleaning the customer_orders table
DROP TABLE IF EXISTS customer_orders_clean;
CREATE TEMP TABLE customer_orders_clean AS (
    SELECT  order_id,
            customer_id,
            pizza_id,
            CASE
                WHEN exclusions = '' THEN NULL
                WHEN exclusions = 'null' THEN NULL
                ELSE exclusions
            END AS exclusions,
            CASE
                WHEN extras = '' THEN NULL
                WHEN extras = 'null' THEN NULL
                WHEN extras = 'NaN' THEN NULL
                ELSE extras
            END AS extras,
            order_time
    FROM customer_orders
);

-- Sanity check for the cleaned customer_orders table
SELECT * FROM customer_orders;
SELECT * FROM customer_orders_clean;


-- Cleaning the runner_orders table
DROP TABLE IF EXISTS runner_orders_clean;
CREATE TEMP TABLE runner_orders_clean AS (
    SELECT
        order_id,
        runner_id,
        CAST(
            CASE
                WHEN pickup_time = 'null' THEN NULL
                ELSE pickup_time
            END AS TIMESTAMP
        ) AS pickup_time,
        CAST(
            CASE 
                WHEN distance = 'null' THEN NULL
                ELSE REGEXP_REPLACE(distance, '[a-z]+', '', 'g')
            END AS DECIMAL 
        )  AS distance,
        CAST(
            CASE 
                WHEN duration = 'null' THEN NULL
                ELSE REGEXP_REPLACE(duration, '[a-z]+', '', 'g')
            END AS DECIMAL 
        )  AS duration,
        CASE
            WHEN cancellation = 'null' OR cancellation = 'NaN' OR cancellation = '' THEN NULL
            ELSE cancellation
        END AS cancellation
    FROM runner_orders
);

-- Sanity check for the cleaned runner_orders table
SELECT * FROM runner_orders;
SELECT * FROM runner_orders_clean;

----------------------------------------------------------------------------------
----------------------------------- Queries --------------------------------------
----------------------------------------------------------------------------------

-- 1. How many pizzas were ordered?

SELECT COUNT(*) AS number_of_pizzas_ordered
FROM customer_orders_clean;

-- Query Results

--  number_of_pizzas_ordered 
-- --------------------------
--           14


-- 2. How many unique customer orders were made?

SELECT COUNT(DISTINCT order_id) as number_of_unique_orders
FROM customer_orders_clean;

-- Query Results

--  number_of_unique_orders 
-- -------------------------
--           10


-- 3. How many successful orders were delivered by each runner?

SELECT runner_id, COUNT(*) as number_of_succesful_orders
FROM runner_orders_clean
WHERE cancellation IS NULL
GROUP BY runner_id
ORDER BY runner_id;

-- Query Results

--  runner_id | number_of_succesful_orders 
-- -----------+----------------------------
--          1 |                          4
--          2 |                          3
--          3 |                          1


-- 4. How many of each type of pizza was delivered?

SELECT pizza_id, COUNT(*)
FROM customer_orders_clean JOIN runner_orders_clean
    ON customer_orders_clean.order_id = runner_orders_clean.order_id
WHERE cancellation IS NULL
GROUP BY pizza_id;

-- Query Results

--  pizza_id | count 
-- ----------+-------
--         1 |     9
--         2 |     3


-- 5. How many Vegetarian and Meatlovers were ordered by each customer?

SELECT customer_id,
        SUM(CASE WHEN pizza_names.pizza_id = 1 THEN 1 ELSE 0 END) AS "Meatlovers",
        SUM(CASE WHEN pizza_names.pizza_id = 2 THEN 1 ELSE 0 END) AS "Vegetarian"
FROM customer_orders_clean JOIN pizza_names
    ON customer_orders_clean.pizza_id = pizza_names.pizza_id
GROUP BY customer_id
ORDER BY customer_id;

-- Query Results

--  customer_id | Meatlovers | Vegetarian 
-- -------------+------------+------------
--          101 |          2 |          1
--          102 |          2 |          1
--          103 |          3 |          1
--          104 |          3 |          0
--          105 |          0 |          1


-- 6. What was the maximum number of pizzas delivered in a single order?

SELECT order_id,
        COUNT(*) AS number_of_pizza_in_order
FROM customer_orders_clean
GROUP BY order_id
ORDER BY number_of_pizza_in_order DESC;

-- Query Results

--  order_id | number_of_pizza_in_order 
-- ----------+--------------------------
--         4 |                        3
--        10 |                        2
--         3 |                        2
--         2 |                        1
--         7 |                        1
--         1 |                        1
--         9 |                        1
--         8 |                        1
--         5 |                        1
--         6 |                        1


-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

SELECT customer_id,
        SUM(CASE WHEN exclusions IS NOT NULL OR extras IS NOT NULL THEN 1 ELSE 0 END) AS number_of_modified_pizzas,
        SUM(CASE WHEN exclusions IS NULL AND extras IS NULL THEN 1 ELSE 0 END) AS number_of_unmodified_pizzas
FROM customer_orders_clean AS C JOIN runner_orders_clean AS R
    ON C.order_id = R.order_id
WHERE cancellation IS NULL
GROUP BY customer_id;

-- Query Results

--  customer_id | number_of_modified_pizzas | number_of_unmodified_pizzas 
-- -------------+---------------------------+-----------------------------
--          101 |                         0 |                           2
--          102 |                         0 |                           3
--          103 |                         3 |                           0
--          104 |                         2 |                           1
--          105 |                         1 |                           0


-- 8. How many pizzas were delivered that had both exclusions and extras?

SELECT COUNT(*) as exclusions_and_extras
FROM customer_orders_clean AS C JOIN runner_orders_clean AS R
    ON C.order_id = R.order_id
WHERE cancellation IS NULL
      AND (extras IS NOT NULL AND exclusions IS NOT NULL);

-- Query Results

--  exclusions_and_extras 
-- ----------------------
--          1


-- 9. What was the total volume of pizzas ordered for each hour of the day?

SELECT EXTRACT(HOUR FROM order_time) AS hour,
       COUNT(*) AS orders_per_hour
FROM customer_orders_clean
GROUP BY hour
ORDER BY hour;

-- Query Results

--  hour | orders_per_hour 
-- ------+-----------------
--    11 |               1
--    13 |               3
--    18 |               3
--    19 |               1
--    21 |               3
--    23 |               3


-- 10. What was the volume of orders for each day of the week?

SELECT TO_CHAR(order_time, 'Day') AS day,
       COUNT(*) AS orders_per_day
FROM customer_orders_clean
GROUP BY day
ORDER BY day;

-- Query Results

--     day    | orders_per_day 
-- -----------+----------------
--  Friday    |              5
--  Monday    |              5
--  Saturday  |              3
--  Sunday    |              1
