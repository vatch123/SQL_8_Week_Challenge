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

-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no
--    charges for changes - how much money has Pizza Runner made so far if there
--    are no delivery fees?

SELECT SUM(
        CASE
            WHEN pizza_id = 1 THEN 12
            ELSE 10
        END
        ) AS total_revenue
FROM customer_orders_clean;

-- Query Results

--  total_revenue 
-- ---------------
--            160


-- 2. What if there was an additional $1 charge for any pizza extras?
--      Add cheese is $1 extra

SELECT SUM(
        CASE
            WHEN pizza_id = 1 THEN 12
            ELSE 10
        END
        ) + 
        SUM(ARRAY_LENGTH(STRING_TO_ARRAY(extras, ', '), 1))
        AS total_revenue
FROM customer_orders_clean;

-- Query Results

--  total_revenue 
-- ---------------
--            166


-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to
--    rate their runner, how would you design an additional table for this new dataset - generate
--    a schema for this new table and insert your own data for ratings for each successful customer
--    order between 1 to 5.

-- Create a basic table and add random ratings between 1-5
DROP TABLE IF EXISTS runner_ratings;
CREATE TEMP TABLE runner_ratings AS (
    SELECT order_id, runner_id, CEIL(RANDOM() *5) AS ratings
    FROM runner_orders_clean
);

SELECT * FROM runner_ratings;

-- Query Results

--  order_id | runner_id | ratings 
-- ----------+-----------+---------
--         1 |         1 |       2
--         2 |         1 |       5
--         3 |         1 |       1
--         4 |         2 |       2
--         5 |         3 |       1
--         6 |         3 |       5
--         7 |         2 |       2
--         8 |         2 |       1
--         9 |         2 |       5
--        10 |         1 |       2


-- 4. Using your newly generated table - can you join all of the information together to form
--    a table which has the following information for successful deliveries?
--      customer_id
--      order_id
--      runner_id
--      rating
--      order_time
--      pickup_time
--      Time between order and pickup
--      Delivery duration
--      Average speed
--      Total number of pizzas

WITH pizza_num_per_order AS(
    SELECT order_id, customer_id, order_time, COUNT(pizza_id) AS num_pizza
    FROM customer_orders_clean
    GROUP BY order_id, customer_id, order_time
    ORDER BY order_id
)

SELECT customer_id,
       runner_orders_clean.order_id,
       runner_orders_clean.runner_id,
       ratings,
       order_time,
       pickup_time,
       pickup_time - order_time AS time_diff,
       duration,
       ROUND(distance / duration * 60, 2) AS average_speed,
       num_pizza 
FROM runner_orders_clean
     JOIN pizza_num_per_order ON runner_orders_clean.order_id = pizza_num_per_order.order_id
     JOIN runner_ratings ON runner_orders_clean.order_id = runner_ratings.order_id;

-- Query Results

--  customer_id | order_id | runner_id | ratings |     order_time      |     pickup_time     | time_diff | duration | average_speed | num_pizza 
-- -------------+----------+-----------+---------+---------------------+---------------------+-----------+----------+---------------+-----------
--          101 |        1 |         1 |       1 | 2021-01-01 18:05:02 | 2021-01-01 18:15:34 | 00:10:32  |       32 |         37.50 |         1
--          101 |        2 |         1 |       3 | 2021-01-01 19:00:52 | 2021-01-01 19:10:54 | 00:10:02  |       27 |         44.44 |         1
--          102 |        3 |         1 |       3 | 2021-01-02 23:51:23 | 2021-01-03 00:12:37 | 00:21:14  |       20 |         40.20 |         2
--          103 |        4 |         2 |       1 | 2021-01-04 13:23:46 | 2021-01-04 13:53:03 | 00:29:17  |       40 |         35.10 |         3
--          104 |        5 |         3 |       1 | 2021-01-08 21:00:29 | 2021-01-08 21:10:57 | 00:10:28  |       15 |         40.00 |         1
--          101 |        6 |         3 |       4 | 2021-01-08 21:03:13 |                     |           |          |               |         1
--          105 |        7 |         2 |       4 | 2021-01-08 21:20:29 | 2021-01-08 21:30:45 | 00:10:16  |       25 |         60.00 |         1
--          102 |        8 |         2 |       5 | 2021-01-09 23:54:33 | 2021-01-10 00:15:02 | 00:20:29  |       15 |         93.60 |         1
--          103 |        9 |         2 |       4 | 2021-01-10 11:22:59 |                     |           |          |               |         1
--          104 |       10 |         1 |       2 | 2021-01-11 18:34:49 | 2021-01-11 18:50:20 | 00:15:31  |       10 |         60.00 |         2


-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras
--    and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have
--    left over after these deliveries?

SELECT SUM(revenue) AS total_revenue
FROM (
    SELECT SUM(
            CASE
                WHEN pizza_id = 1 THEN 12
                ELSE 10
            END
            ) AS revenue
    FROM customer_orders_clean
    UNION
    SELECT SUM(
        -1 * distance * 0.3
    ) AS revenue
    FROM runner_orders_clean
) AS rev_table;

-- Query Results

--  total_revenue 
-- ---------------
--         116.44
