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
            WHEN cancellation = 'null'
                 OR cancellation = 'NaN'
                 OR cancellation = '' THEN NULL
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

-- 1. How many runners signed up for each 1 week period?
--    (i.e. week starts 2021-01-01)

SELECT TO_CHAR(registration_date, 'W') as week,
        COUNT(*) AS number_of_signups
FROM runners
GROUP BY week
ORDER BY week;

-- Query Results

--  week | number_of_signups 
-- ------+-------------------
--  1    |                 2
--  2    |                 1
--  3    |                 1


-- 2. What was the average time in minutes it took for each runner to arrive
--    at the Pizza Runner HQ to pickup the order?

SELECT runner_id,
        AVG(EXTRACT(HOUR FROM pickup_time - order_time) * 60
            + EXTRACT(MINUTES FROM pickup_time - order_time)
            + EXTRACT(SECONDS FROM pickup_time - order_time) / 60
            ) AS average_time
FROM customer_orders_clean JOIN runner_orders_clean
     ON customer_orders_clean.order_id = runner_orders_clean.order_id
GROUP BY runner_id
ORDER BY runner_id;

-- Query Results

--  runner_id |    average_time    
-- -----------+--------------------
--          1 | 15.677777777777777
--          2 | 23.720000000000002
--          3 | 10.466666666666667


-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

SELECT customer_orders_clean.order_id,
        COUNT(pizza_id) AS number_of_pizzas,
        AVG(EXTRACT(HOUR FROM pickup_time - order_time) * 60
            + EXTRACT(MINUTES FROM pickup_time - order_time)
            + EXTRACT(SECONDS FROM pickup_time - order_time) / 60
            ) AS time_to_prepare
FROM customer_orders_clean JOIN runner_orders_clean
     ON customer_orders_clean.order_id = runner_orders_clean.order_id
GROUP BY customer_orders_clean.order_id
ORDER BY customer_orders_clean.order_id;

-- Query Results

--  order_id | number_of_pizzas |  time_to_prepare   
-- ----------+------------------+--------------------
--         1 |                1 | 10.533333333333333
--         2 |                1 | 10.033333333333333
--         3 |                2 | 21.233333333333334
--         4 |                3 | 29.283333333333335
--         5 |                1 | 10.466666666666667
--         6 |                1 |                   
--         7 |                1 | 10.266666666666667
--         8 |                1 | 20.483333333333334
--         9 |                1 |                   
--        10 |                2 | 15.516666666666667

-- There seems to be a direct correlation between the number of pizzas and the time it takes to prepare the order.


-- 5. What was the average distance travelled for each customer?

SELECT customer_id,
        ROUND(AVG(distance), 2) AS average_distance_travelled
FROM customer_orders_clean JOIN runner_orders_clean
     ON customer_orders_clean.order_id = runner_orders_clean.order_id
GROUP BY customer_id
ORDER BY customer_id;

-- Query Results

--  customer_id | average_distance_travelled 
-- -------------+----------------------------
--          101 |                      20.00
--          102 |                      16.73
--          103 |                      23.40
--          104 |                      10.00
--          105 |                      25.00


-- 5. What was the difference between the longest and shortest delivery times for all orders?

SELECT MAX(duration) - MIN(duration) AS diff
FROM runner_orders_clean;

-- Query Results

--  diff 
-- ------
--    30


-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

SELECT runner_id, order_id, ROUND(AVG(distance/duration*60), 2) AS "average_speed (km/hr)"
FROM runner_orders_clean
WHERE cancellation IS NULL
GROUP BY runner_id, order_id
ORDER BY runner_id;

-- Query Results

--  runner_id | order_id | average_speed (km/hr) 
-- -----------+----------+-----------------------
--          1 |        1 |                 37.50
--          1 |        2 |                 44.44
--          1 |        3 |                 40.20
--          1 |       10 |                 60.00
--          2 |        4 |                 35.10
--          2 |        7 |                 60.00
--          2 |        8 |                 93.60
--          3 |        5 |                 40.00

-- Runner 2 is generally faster


-- 7. What is the successful delivery percentage for each runner?

SELECT runner_id, COUNT(order_id) AS total_orders,
        SUM(CASE WHEN cancellation IS NOT NULL THEN 0 ELSE 1 END) AS success_orders,
        CAST(SUM(CASE WHEN cancellation IS NOT NULL THEN 0 ELSE 1 END) AS FLOAT) / COUNT(order_id) * 100 AS success_percent
FROM runner_orders_clean
GROUP BY runner_id
ORDER BY runner_id;
    
-- Query Results

--  runner_id | total_orders | success_orders | success_percent 
-- -----------+--------------+----------------+-----------------
--          1 |            4 |              4 |             100
--          2 |            4 |              3 |              75
--          3 |            2 |              1 |              50
