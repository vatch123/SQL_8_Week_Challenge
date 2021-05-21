/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?

SELECT customer_id, SUM(price) AS "Amount Spent"
FROM sales JOIN menu
    ON sales.product_id = menu.product_id
GROUP BY customer_id;

-- Query Results

--  customer_id | Amount Spent 
-- -------------+--------------
--  B           |           74
--  C           |           36
--  A           |           76


-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT order_date) AS "Days visited"
FROM sales
GROUP BY customer_id;

-- Query Results

--  customer_id | Days visited 
-- -------------+--------------
--  A           |            4
--  B           |            6
--  C           |            2


-- 3. What was the first item from the menu purchased by each customer?

SELECT customer_id, product_name
FROM (
    SELECT RANK() OVER (PARTITION BY customer_id ORDER BY order_date ASC) AS ranking,
            customer_id,
            product_name
    FROM sales JOIN menu
        ON sales.product_id = menu.product_id
    ) AS ranked
WHERE ranked.ranking = 1;

-- Query Results

--  customer_id | product_name 
-- -------------+--------------
--  A           | curry
--  A           | sushi
--  B           | curry
--  C           | ramen
--  C           | ramen


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT product_name, COUNT(*)
FROM sales JOIN menu
    ON sales.product_id = menu.product_id
GROUP BY menu.product_name
ORDER BY COUNT(*) DESC
LIMIT 1;

-- Query Results

--  product_name | count 
-- --------------+-------
--  ramen        |     8


-- 5. Which item was the most popular for each customer?

WITH ranked AS (
    SELECT RANK() OVER(PARTITION BY customer_id ORDER BY num DESC) AS ranking,
            customer_id,
            product_name
    FROM(
        SELECT customer_id, product_name, COUNT(*) as num
        FROM sales JOIN menu
            ON sales.product_id = menu.product_id
        GROUP BY customer_id, product_name
        ORDER BY num DESC
    ) AS max_orders
)

SELECT customer_id, product_name
FROM ranked
WHERE ranking = 1;

-- Query Results

--  customer_id | product_name 
-- -------------+--------------
--  A           | ramen
--  B           | ramen
--  B           | sushi
--  B           | curry
--  C           | ramen

-- B had ordered every dish same number of time


-- 6. Which item was purchased first by the customer after they became a member?

WITH ranked AS (
    SELECT RANK() OVER(PARTITION BY customer_id ORDER BY order_date ASC) as ranking,
            customer_id,
            product_name
    FROM (
        SELECT sales.customer_id, product_name, order_date
        FROM sales JOIN members
            ON sales.customer_id = members.customer_id
            JOIN menu
            ON sales.product_id = menu.product_id
        WHERE order_date >= join_date
    ) AS complete_table
)

SELECT customer_id, product_name
FROM ranked
WHERE ranking = 1;

-- Query Results

--  customer_id | product_name 
-- -------------+--------------
--  A           | curry
--  B           | sushi


-- 7. Which item was purchased just before the customer became a member?

WITH ranked AS (
    SELECT RANK() OVER(PARTITION BY customer_id ORDER BY order_date DESC) as ranking,
            customer_id,
            product_name
    FROM (
        SELECT sales.customer_id, product_name, order_date
        FROM sales JOIN members
            ON sales.customer_id = members.customer_id
            JOIN menu
            ON sales.product_id = menu.product_id
        WHERE order_date < join_date
    ) AS complete_table
)

SELECT customer_id, product_name
FROM ranked
WHERE ranking = 1;

-- Query Results

--  customer_id | product_name 
-- -------------+--------------
--  A           | sushi
--  A           | curry
--  B           | sushi

-- A bought two items simultanesously before becoming a member


-- 8. What is the total items and amount spent for each member before they became a member?

SELECT sales.customer_id, COUNT(*) AS total_items, SUM(price) AS amount
FROM sales JOIN members
    ON sales.customer_id = members.customer_id
    JOIN menu
    ON sales.product_id = menu.product_id
WHERE order_date < join_date
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- Query Results

--  customer_id | total_items | amount 
-- -------------+-------------+--------
--  A           |           2 |     25
--  B           |           3 |     40


-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT customer_id,
    SUM(CASE 
        WHEN product_name = 'sushi' THEN 20 * price
        ELSE 10 * price
        END) AS points
FROM sales JOIN menu
    ON sales.product_id = menu.product_id
GROUP BY customer_id
ORDER BY points DESC;

-- Query Results

--  customer_id | points 
-- -------------+--------
--  B           |    940
--  A           |    860
--  C           |    360


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SELECT sales.customer_id,
        SUM(CASE 
                WHEN product_name = 'sushi' THEN 20 * price
                WHEN order_date BETWEEN join_date AND join_date + 7 THEN 20 * price
                ELSE 10 * price
            END) AS points
FROM members JOIN sales
    ON sales.customer_id = members.customer_id
    JOIN menu
    ON menu.product_id = sales.product_id
WHERE order_date <= '2021-01-31'
GROUP BY sales.customer_id;

-- Query Results

--  customer_id | points 
-- -------------+--------
--  A           |   1370
--  B           |    940


-- #################################
-- Bonus Questions

-- Join all things
SELECT sales.customer_id,
        order_date,
        product_name,
        price,
        CASE
            WHEN order_date >= join_date THEN 'Y'
            ELSE 'N'
        END AS member
FROM sales JOIN menu
     ON sales.product_id = menu.product_id
     LEFT JOIN members
     ON sales.customer_id = members.customer_id
ORDER BY customer_id ASC, order_date ASC;

-- Query Results

--  customer_id | order_date | product_name | price | member 
-- -------------+------------+--------------+-------+--------
--  A           | 2021-01-01 | sushi        |    10 | N
--  A           | 2021-01-01 | curry        |    15 | N
--  A           | 2021-01-07 | curry        |    15 | Y
--  A           | 2021-01-10 | ramen        |    12 | Y
--  A           | 2021-01-11 | ramen        |    12 | Y
--  A           | 2021-01-11 | ramen        |    12 | Y
--  B           | 2021-01-01 | curry        |    15 | N
--  B           | 2021-01-02 | curry        |    15 | N
--  B           | 2021-01-04 | sushi        |    10 | N
--  B           | 2021-01-11 | sushi        |    10 | Y
--  B           | 2021-01-16 | ramen        |    12 | Y
--  B           | 2021-02-01 | ramen        |    12 | Y
--  C           | 2021-01-01 | ramen        |    12 | N
--  C           | 2021-01-01 | ramen        |    12 | N
--  C           | 2021-01-07 | ramen        |    12 | N


-- Rank all the things
SELECT *,
        CASE
            WHEN member = 'Y' THEN RANK () OVER(PARTITION BY customer_id, member ORDER BY order_date)
            ELSE NULL
        END AS ranking
FROM (
    SELECT sales.customer_id,
            order_date,
            product_name,
            price,
            CASE
                WHEN order_date >= join_date THEN 'Y'
                ELSE 'N'
            END AS member
    FROM sales JOIN menu
        ON sales.product_id = menu.product_id
        LEFT JOIN members
        ON sales.customer_id = members.customer_id
    ORDER BY customer_id ASC, order_date ASC
) AS total

-- Query Results

--  customer_id | order_date | product_name | price | member | ranking 
-- -------------+------------+--------------+-------+--------+---------
--  A           | 2021-01-01 | sushi        |    10 | N      |        
--  A           | 2021-01-01 | curry        |    15 | N      |        
--  A           | 2021-01-07 | curry        |    15 | Y      |       1
--  A           | 2021-01-10 | ramen        |    12 | Y      |       2
--  A           | 2021-01-11 | ramen        |    12 | Y      |       3
--  A           | 2021-01-11 | ramen        |    12 | Y      |       3
--  B           | 2021-01-01 | curry        |    15 | N      |        
--  B           | 2021-01-02 | curry        |    15 | N      |        
--  B           | 2021-01-04 | sushi        |    10 | N      |        
--  B           | 2021-01-11 | sushi        |    10 | Y      |       1
--  B           | 2021-01-16 | ramen        |    12 | Y      |       2
--  B           | 2021-02-01 | ramen        |    12 | Y      |       3
--  C           | 2021-01-01 | ramen        |    12 | N      |        
--  C           | 2021-01-01 | ramen        |    12 | N      |        
--  C           | 2021-01-07 | ramen        |    12 | N      |        
