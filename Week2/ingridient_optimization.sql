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

-- 1. What are the standard ingredients for each pizza?

SELECT topping_list.pizza_id,
        pizza_name,
        ARRAY_TO_STRING(ARRAY_AGG(topping_name), ', ') AS standard_ingridients
FROM   pizza_toppings JOIN
        (SELECT pizza_id,
                CAST(UNNEST(STRING_TO_ARRAY(toppings, ', ')) AS INTEGER) as topping_id
        FROM pizza_recipes) AS topping_list
        ON pizza_toppings.topping_id = topping_list.topping_id
        JOIN pizza_names
        ON topping_list.pizza_id = pizza_names.pizza_id
GROUP BY topping_list.pizza_id, pizza_name
ORDER BY topping_list.pizza_id;

-- Query Results

--  pizza_id | pizza_name |                         standard_ingridients                          
-- ----------+------------+-----------------------------------------------------------------------
--         1 | Meatlovers | BBQ Sauce, Pepperoni, Cheese, Salami, Chicken, Bacon, Mushrooms, Beef
--         2 | Vegetarian | Tomato Sauce, Cheese, Mushrooms, Onions, Peppers, Tomatoes


-- 2. What was the most commonly added extra?

WITH ranked_extras AS (
    SELECT extras_id, topping_name, RANK () OVER(ORDER BY number_of_times DESC)
    FROM (
            (
                SELECT extras_id, COUNT(*) AS number_of_times
                FROM (
                    SELECT CAST(UNNEST(STRING_TO_ARRAY(extras, ', ')) AS INTEGER) AS extras_id
                    FROM customer_orders_clean
                    WHERE extras IS NOT NULL
                ) AS extras_table
                GROUP BY extras_id
                ORDER BY COUNT(*) DESC
            ) AS count_table
            JOIN pizza_toppings
            ON count_table.extras_id = pizza_toppings.topping_id
    )
)

SELECT extras_id, topping_name FROM ranked_extras WHERE rank = 1;

-- Query Results

--  extras_id | topping_name 
-- -----------+--------------
--          1 | Bacon


-- 3. What was the most common exclusion?

WITH ranked_exclusions AS (
    SELECT exclusions_id, topping_name, RANK () OVER(ORDER BY number_of_times DESC)
    FROM (
            (
                SELECT exclusions_id, COUNT(*) AS number_of_times
                FROM (
                    SELECT CAST(UNNEST(STRING_TO_ARRAY(exclusions, ', ')) AS INTEGER) AS exclusions_id
                    FROM customer_orders_clean
                    WHERE exclusions IS NOT NULL
                ) AS exclusions_table
                GROUP BY exclusions_id
                ORDER BY COUNT(*) DESC
            ) AS count_table
            JOIN pizza_toppings
            ON count_table.exclusions_id = pizza_toppings.topping_id
    )
)

SELECT exclusions_id, topping_name FROM ranked_exclusions exclusions_id WHERE rank=1;

-- Query Results

--  exclusions_id | topping_name 
-- ---------------+--------------
--              4 | Cheese


-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
--    Meat Lovers
--    Meat Lovers - Exclude Beef
--    Meat Lovers - Extra Bacon
--    Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

/*
DROP TABLE IF EXISTS named_toppings;
CREATE TEMP TABLE named_toppings AS(
    SELECT order_id,
            ext_and_excl.pizza_id,
            pizza_names.pizza_name,
            CASE WHEN extras_id is NULL THEN 0
                 ELSE extras_id
            END AS extras_id,
            CASE WHEN exclusions_id is NULL THEN 0
                 ELSE exclusions_id
            END AS exclusions_id,
            tp1.topping_name AS extras, 
            tp2.topping_name AS exclusions
    FROM (
        SELECT  order_id, pizza_id,
                CAST(UNNEST(STRING_TO_ARRAY(extras, ', ')) AS INTEGER) AS extras_id,
                CAST(UNNEST(STRING_TO_ARRAY(exclusions, ', ')) AS INTEGER) AS exclusions_id
       FROM customer_orders_clean
    ) AS ext_and_excl
    LEFT JOIN pizza_toppings AS tp1 ON ext_and_excl.extras_id = tp1.topping_id
    LEFT JOIN pizza_toppings AS tp2 ON ext_and_excl.exclusions_id = tp2.topping_id
    JOIN pizza_names ON pizza_names.pizza_id = ext_and_excl.pizza_id
);

SELECT * FROM named_toppings ORDER BY order_id;
*/

-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza
-- order from the customer_orders table and add a 2x in front of any relevant ingredients
-- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

/**/

-- 6. What is the total quantity of each ingredient used in all delivered pizzas
-- sorted by most frequent first?
WITH pizza_number_table AS(
    SELECT pizza_id, COUNT(pizza_id) AS num
    FROM customer_orders_clean
    GROUP BY pizza_id
),
pizza_recipes_unnest AS(
    SELECT pizza_id,
           CAST(UNNEST(STRING_TO_ARRAY(toppings, ', ')) AS INTEGER) AS toppings
    FROM pizza_recipes 
),  
exc AS(
    SELECT exclusions as toppings, -1 * COUNT(*) as num
    FROM (
        SELECT CAST(UNNEST(STRING_TO_ARRAY(exclusions, ', ')) AS INTEGER) AS exclusions
        FROM customer_orders_clean
    ) AS exc_count
    GROUP BY exclusions
),
ext AS(
    SELECT extras as toppings, COUNT(*) as num
    FROM (
        SELECT CAST(UNNEST(STRING_TO_ARRAY(extras, ', ')) AS INTEGER) AS extras
        FROM customer_orders_clean
    ) AS ext_count
    GROUP BY extras
)

SELECT toppings, SUM(num) AS num
FROM (
    SELECT toppings, num 
    FROM pizza_recipes_unnest
        JOIN pizza_number_table
        ON pizza_number_table.pizza_id = pizza_recipes_unnest.pizza_id
    UNION
    SELECT * FROM exc
    UNION
    SELECT * FROM ext
) AS topping_frequency
GROUP BY toppings
ORDER BY num DESC;

-- Query Results

--  toppings | num 
-- ----------+-----
--         1 |  14
--         6 |  13
--         4 |  11
--         5 |  11
--         8 |  10
--         3 |  10
--        10 |  10
--         2 |   9
--         7 |   4
--        12 |   4
--         9 |   4
--        11 |   4
