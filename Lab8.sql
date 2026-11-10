-- ============================================================
-- LAB ASSIGNMENT 8
-- Name: Shuai Yuan
-- ============================================================


-- ============================================================
-- PART 1: COMPLETE THE CTE, BI, AND GIT TASKS
-- ============================================================


-- ------------------------------------------------------------
-- Task 1: Single CTE
-- Find customers whose total spending is above the
-- average total spending across all customers.
-- ------------------------------------------------------------

WITH customer_spend AS (
    SELECT
        customer_id,
        SUM(amount) AS total_spend
    FROM `project-7987ef63-b037-435a-8f6.sql_lab.payment`
    GROUP BY customer_id
)

SELECT
    cs.customer_id,
    c.first_name,
    c.last_name,
    ROUND(cs.total_spend, 2) AS total_spend
FROM customer_spend cs
JOIN `project-7987ef63-b037-435a-8f6.sql_lab.customer` c
    ON cs.customer_id = c.customer_id
WHERE cs.total_spend > (
    SELECT AVG(total_spend)
    FROM customer_spend
)
ORDER BY cs.total_spend DESC;



-- ------------------------------------------------------------
-- Task 2: Chained CTEs
-- Show the top five stores by number of above-average-
-- spending customers and the revenue from those customers.
-- ------------------------------------------------------------

WITH customer_spend AS (
    SELECT
        customer_id,
        SUM(amount) AS total_spend
    FROM `project-7987ef63-b037-435a-8f6.sql_lab.payment`
    GROUP BY customer_id
),

above_average_customers AS (
    SELECT
        customer_id,
        total_spend
    FROM customer_spend
    WHERE total_spend > (
        SELECT AVG(total_spend)
        FROM customer_spend
    )
),

customer_store AS (
    SELECT
        aac.customer_id,
        aac.total_spend,
        s.store_id,
        ci.city AS store_city
    FROM above_average_customers aac
    JOIN `project-7987ef63-b037-435a-8f6.sql_lab.customer` c
        ON aac.customer_id = c.customer_id
    JOIN `project-7987ef63-b037-435a-8f6.sql_lab.store` s
        ON c.store_id = s.store_id
    JOIN `project-7987ef63-b037-435a-8f6.sql_lab.address` a
        ON s.address_id = a.address_id
    JOIN `project-7987ef63-b037-435a-8f6.sql_lab.city` ci
        ON a.city_id = ci.city_id
)

SELECT
    store_id,
    store_city,
    COUNT(*) AS above_average_customer_count,
    ROUND(SUM(total_spend), 2) AS total_revenue
FROM customer_store
GROUP BY
    store_id,
    store_city
ORDER BY
    above_average_customer_count DESC,
    total_revenue DESC
LIMIT 5;



-- ------------------------------------------------------------
-- Task 3: BI Tool Connection
-- ------------------------------------------------------------

-- I connected the cloud warehouse to a BI tool and used the
-- Task 2 result to create a visualization. I applied at least
-- one filter to the visualization.
--
-- The BI visualization screenshot is submitted separately.



-- ------------------------------------------------------------
-- Task 4: Git Basics
-- ------------------------------------------------------------

-- Task 1 and Task 2 are also saved in:
-- lab8_shuai_yuan.sql
--
-- Commit message:
-- Add Lab 8 CTE queries
--
-- The Git commit/push screenshot is submitted separately.



-- ============================================================
-- PART 2: EXPLAIN YOUR CODE
-- ============================================================


-- ------------------------------------------------------------
-- Question 1
-- Rewrite Task 1 using a subquery instead of a CTE.
-- ------------------------------------------------------------

SELECT
    cs.customer_id,
    c.first_name,
    c.last_name,
    ROUND(cs.total_spend, 2) AS total_spend
FROM (
    SELECT
        customer_id,
        SUM(amount) AS total_spend
    FROM `project-7987ef63-b037-435a-8f6.sql_lab.payment`
    GROUP BY customer_id
) cs
JOIN `project-7987ef63-b037-435a-8f6.sql_lab.customer` c
    ON cs.customer_id = c.customer_id
WHERE cs.total_spend > (
    SELECT AVG(total_spend)
    FROM (
        SELECT
            customer_id,
            SUM(amount) AS total_spend
        FROM `project-7987ef63-b037-435a-8f6.sql_lab.payment`
        GROUP BY customer_id
    )
)
ORDER BY cs.total_spend DESC;


-- I think the CTE version is easier to read because the
-- customer-spending calculation is named once at the top.
-- In the subquery version, the same logic is nested inside
-- the query and is harder to follow.
--
-- For a simple one-step query, the difference is small.
-- Once a query has around three or more steps, or needs to
-- reuse an intermediate result, CTEs become much more useful.


-- ------------------------------------------------------------
-- Question 2
-- Can the first CTE reference the third CTE?
-- ------------------------------------------------------------

-- No. In Task 2, a later CTE can use a CTE that was defined
-- before it, but an earlier CTE cannot reference one that has
-- not been defined yet.
--
-- For example, above_average_customers can use customer_spend
-- because customer_spend appears first. customer_spend cannot
-- use customer_store because customer_store is defined later.
-- The CTEs are built in order from top to bottom.


-- ------------------------------------------------------------
-- Question 3
-- What happens when a BI dashboard filter is clicked?
-- ------------------------------------------------------------

-- It depends on the type of connection. With a live connection,
-- the BI tool can send a new or modified query to the warehouse
-- when the user changes a filter, so the result comes from the
-- current warehouse data.
--
-- With an extract, the BI tool works mainly with the saved copy
-- of the data, so many filters can be applied locally without
-- querying the warehouse again. The extract has to be refreshed
-- when newer warehouse data is needed.


-- ------------------------------------------------------------
-- Question 4
-- Why does dbt require Git?
-- ------------------------------------------------------------

-- Git keeps a history of changes to the SQL models and makes
-- it possible for a team to work on the same project safely.
--
-- If two people edited the same SQL file without version
-- control, one person's changes could overwrite the other's,
-- and it would be difficult to see who changed the code or
-- return to an older version. Git helps track and manage those
-- changes.



-- ============================================================
-- PART 3: EXTEND YOUR QUERY
-- ============================================================


-- ------------------------------------------------------------
-- New Requirement:
-- Find the top 20 At Risk customers by lifetime spending.
--
-- Because the course sample database contains historical
-- rental data, the latest rental date in the dataset is used
-- as the reference date for recency.
-- ------------------------------------------------------------

WITH reference_date AS (
    SELECT
        DATE(MAX(rental_date)) AS as_of_date
    FROM `project-7987ef63-b037-435a-8f6.sql_lab.rental`
),

customer_recency AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        DATE(MAX(r.rental_date)) AS most_recent_rental_date,
        DATE_DIFF(
            rd.as_of_date,
            DATE(MAX(r.rental_date)),
            DAY
        ) AS days_since_rental
    FROM `project-7987ef63-b037-435a-8f6.sql_lab.customer` c
    JOIN `project-7987ef63-b037-435a-8f6.sql_lab.rental` r
        ON c.customer_id = r.customer_id
    CROSS JOIN reference_date rd
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name,
        rd.as_of_date
),

classified_customers AS (
    SELECT
        customer_id,
        first_name,
        last_name,
        most_recent_rental_date,
        days_since_rental,
        CASE
            WHEN days_since_rental <= 90 THEN 'Active'
            WHEN days_since_rental BETWEEN 91 AND 180 THEN 'At Risk'
            ELSE 'Lapsed'
        END AS customer_status
    FROM customer_recency
),

lifetime_spend AS (
    SELECT
        customer_id,
        SUM(amount) AS total_lifetime_spend
    FROM `project-7987ef63-b037-435a-8f6.sql_lab.payment`
    GROUP BY customer_id
)

SELECT
    cc.customer_id,
    cc.first_name,
    cc.last_name,
    cc.most_recent_rental_date,
    cc.days_since_rental,
    cc.customer_status,
    ROUND(COALESCE(ls.total_lifetime_spend, 0), 2)
        AS total_lifetime_spend
FROM classified_customers cc
LEFT JOIN lifetime_spend ls
    ON cc.customer_id = ls.customer_id
WHERE cc.customer_status = 'At Risk'
ORDER BY total_lifetime_spend DESC
LIMIT 20;