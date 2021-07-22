WITH price_table AS (
    -- Get the price of the plans first
    SELECT customer_id, s.plan_id, plan_name, start_date, price
    FROM foodie_fi.subscriptions AS s JOIN foodie_fi.plans AS p
        ON s.plan_id = p.plan_id
    WHERE s.plan_id != 0
),
next_date_cte AS(
    -- Find the next plan's starting date
    SELECT *,
            LEAD (start_date, 1) OVER (PARTITION BY customer_id ORDER BY start_date) AS next_date
    FROM price_table
),
plan_table AS (
    -- For current plan define the range for which the payment is to be made
    SELECT customer_id, plan_id, plan_name, start_date, price,
            CASE
                WHEN next_date IS NULL THEN '2020-12-31'::DATE
                ELSE next_date
            END AS next_date,
            CASE
                WHEN plan_id=1 OR plan_id=2 THEN '1 month'::INTERVAL
                ELSE '1 year'::INTERVAL
            END AS payment_interval
    FROM next_date_cte
    WHERE plan_id!=4
),
payment_dates_cte AS (
    -- Generate all the payment dates
    SELECT customer_id, plan_id, plan_name,
            GENERATE_SERIES(start_date, next_date, payment_interval)::DATE AS payment_date,
            price 
    FROM plan_table
),
clean_pro2pro_upgrade AS(
    -- If pro monthly to pro annual upgrade is made then there will be two payments one monthly and one
    -- annual at the start date of the annual plan we need to remove that extra monthly payment
    WITH next_plan_payment AS (
        SELECT *, LEAD (plan_id, 1) OVER (PARTITION BY customer_id ORDER BY payment_date) AS next_plan
        FROM payment_dates_cte
    )    
    SELECT customer_id, plan_id, plan_name, payment_date, price
    FROM next_plan_payment
    WHERE NOT (next_plan IS NOT NULL AND (plan_id=2 AND next_plan=3))
),
clean_basic2pro_upgrade AS (
    -- Now if we upgrade from basic to pro we get two payments in the same month, but we need to 
    -- update the pro plan's price by reducing  the basic plan's price
    WITH prev_plan AS (
        SELECT *,
                LAG (plan_id, 1) OVER (PARTITION BY customer_id ORDER BY payment_date) AS prev_plan
        FROM clean_pro2pro_upgrade
    )
    SELECT customer_id, plan_id, plan_name, payment_date,
        CASE
            WHEN (plan_id=2 OR plan_id=3) AND prev_plan=1 THEN price - 9.90
            ELSE price
        END AS price
    FROM prev_plan
),
payment_order_number AS (
    -- Add the payment order number finally.
    -- We also need to filter on the payment date as some customer's which may have upgraded the account in
    -- 2021 will also be listed because there next plan would not have been Null
    SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY payment_date) AS payment_order
    FROM clean_basic2pro_upgrade
    WHERE payment_date <= '2020-12-31'::DATE
)

-- Display the payments table
SELECT * FROM payment_order_number 

-- Query Results

-- customer_id | plan_id |   plan_name   | payment_date | price  | payment_order 
-- -------------+---------+---------------+--------------+--------+---------------
--            1 |       1 | basic monthly | 2020-08-08   |   9.90 |             1
--            1 |       1 | basic monthly | 2020-09-08   |   9.90 |             2
--            1 |       1 | basic monthly | 2020-10-08   |   9.90 |             3
--            1 |       1 | basic monthly | 2020-11-08   |   9.90 |             4
--            1 |       1 | basic monthly | 2020-12-08   |   9.90 |             5
--            2 |       3 | pro annual    | 2020-09-27   | 199.00 |             1
--            3 |       1 | basic monthly | 2020-01-20   |   9.90 |             1
--            3 |       1 | basic monthly | 2020-02-20   |   9.90 |             2
--            3 |       1 | basic monthly | 2020-03-20   |   9.90 |             3
--            3 |       1 | basic monthly | 2020-04-20   |   9.90 |             4
--            3 |       1 | basic monthly | 2020-05-20   |   9.90 |             5
--            3 |       1 | basic monthly | 2020-06-20   |   9.90 |             6
--            3 |       1 | basic monthly | 2020-07-20   |   9.90 |             7
--            3 |       1 | basic monthly | 2020-08-20   |   9.90 |             8
--            3 |       1 | basic monthly | 2020-09-20   |   9.90 |             9
--            3 |       1 | basic monthly | 2020-10-20   |   9.90 |            10
--            3 |       1 | basic monthly | 2020-11-20   |   9.90 |            11
--            3 |       1 | basic monthly | 2020-12-20   |   9.90 |            12
--            4 |       1 | basic monthly | 2020-01-24   |   9.90 |             1
--            4 |       1 | basic monthly | 2020-02-24   |   9.90 |             2
--            4 |       1 | basic monthly | 2020-03-24   |   9.90 |             3
--            5 |       1 | basic monthly | 2020-08-10   |   9.90 |             1
--            5 |       1 | basic monthly | 2020-09-10   |   9.90 |             2
--            5 |       1 | basic monthly | 2020-10-10   |   9.90 |             3
--            5 |       1 | basic monthly | 2020-11-10   |   9.90 |             4
--            5 |       1 | basic monthly | 2020-12-10   |   9.90 |             5
--            6 |       1 | basic monthly | 2020-12-30   |   9.90 |             1
--            7 |       1 | basic monthly | 2020-02-12   |   9.90 |             1
--            7 |       1 | basic monthly | 2020-03-12   |   9.90 |             2
--            7 |       1 | basic monthly | 2020-04-12   |   9.90 |             3
--            7 |       1 | basic monthly | 2020-05-12   |   9.90 |             4
--            7 |       2 | pro monthly   | 2020-05-22   |  10.00 |             5
--            7 |       2 | pro monthly   | 2020-06-22   |  19.90 |             6
--            7 |       2 | pro monthly   | 2020-07-22   |  19.90 |             7
--            7 |       2 | pro monthly   | 2020-08-22   |  19.90 |             8
--            7 |       2 | pro monthly   | 2020-09-22   |  19.90 |             9
--            7 |       2 | pro monthly   | 2020-10-22   |  19.90 |            10
--            7 |       2 | pro monthly   | 2020-11-22   |  19.90 |            11
--            7 |       2 | pro monthly   | 2020-12-22   |  19.90 |            12
--            8 |       1 | basic monthly | 2020-06-18   |   9.90 |             1
--            8 |       1 | basic monthly | 2020-07-18   |   9.90 |             2
--            8 |       2 | pro monthly   | 2020-08-03   |  10.00 |             3
--            8 |       2 | pro monthly   | 2020-09-03   |  19.90 |             4
--            8 |       2 | pro monthly   | 2020-10-03   |  19.90 |             5
--            8 |       2 | pro monthly   | 2020-11-03   |  19.90 |             6
--            8 |       2 | pro monthly   | 2020-12-03   |  19.90 |             7
--            9 |       3 | pro annual    | 2020-12-14   | 199.00 |             1
--           10 |       2 | pro monthly   | 2020-09-26   |  19.90 |             1
--           10 |       2 | pro monthly   | 2020-10-26   |  19.90 |             2
--           10 |       2 | pro monthly   | 2020-11-26   |  19.90 |             3
--           10 |       2 | pro monthly   | 2020-12-26   |  19.90 |             4
--           12 |       1 | basic monthly | 2020-09-29   |   9.90 |             1
--           12 |       1 | basic monthly | 2020-10-29   |   9.90 |             2
--           12 |       1 | basic monthly | 2020-11-29   |   9.90 |             3
--           12 |       1 | basic monthly | 2020-12-29   |   9.90 |             4
--           13 |       1 | basic monthly | 2020-12-22   |   9.90 |             1
--           14 |       1 | basic monthly | 2020-09-29   |   9.90 |             1
--           14 |       1 | basic monthly | 2020-10-29   |   9.90 |             2
--           14 |       1 | basic monthly | 2020-11-29   |   9.90 |             3
--           14 |       1 | basic monthly | 2020-12-29   |   9.90 |             4
--           15 |       2 | pro monthly   | 2020-03-24   |  19.90 |             1
--           15 |       2 | pro monthly   | 2020-04-24   |  19.90 |             2
--           16 |       1 | basic monthly | 2020-06-07   |   9.90 |             1
--           16 |       1 | basic monthly | 2020-07-07   |   9.90 |             2
--           16 |       1 | basic monthly | 2020-08-07   |   9.90 |             3
--           16 |       1 | basic monthly | 2020-09-07   |   9.90 |             4
--           16 |       1 | basic monthly | 2020-10-07   |   9.90 |             5
--           16 |       3 | pro annual    | 2020-10-21   | 189.10 |             6
--           17 |       1 | basic monthly | 2020-08-03   |   9.90 |             1
--           17 |       1 | basic monthly | 2020-09-03   |   9.90 |             2
--           17 |       1 | basic monthly | 2020-10-03   |   9.90 |             3
--           17 |       1 | basic monthly | 2020-11-03   |   9.90 |             4
--           17 |       1 | basic monthly | 2020-12-03   |   9.90 |             5
--           17 |       3 | pro annual    | 2020-12-11   | 189.10 |             6
--           18 |       2 | pro monthly   | 2020-07-13   |  19.90 |             1
--           18 |       2 | pro monthly   | 2020-08-13   |  19.90 |             2
--           18 |       2 | pro monthly   | 2020-09-13   |  19.90 |             3
--           18 |       2 | pro monthly   | 2020-10-13   |  19.90 |             4
--           18 |       2 | pro monthly   | 2020-11-13   |  19.90 |             5
--           18 |       2 | pro monthly   | 2020-12-13   |  19.90 |             6
--           19 |       2 | pro monthly   | 2020-06-29   |  19.90 |             1
--           19 |       2 | pro monthly   | 2020-07-29   |  19.90 |             2
--           19 |       3 | pro annual    | 2020-08-29   | 199.00 |             3
--           20 |       1 | basic monthly | 2020-04-15   |   9.90 |             1
--           20 |       1 | basic monthly | 2020-05-15   |   9.90 |             2
--           20 |       3 | pro annual    | 2020-06-05   | 189.10 |             3
--           21 |       1 | basic monthly | 2020-02-11   |   9.90 |             1
--           21 |       1 | basic monthly | 2020-03-11   |   9.90 |             2