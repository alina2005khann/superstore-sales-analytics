-- ============================================================
-- PROJECT 1: SUPERSTORE SALES ANALYSIS
-- Author: Alina khan
-- Date: 23-04-2026
-- Dataset: 9,994 rows x 23 columns
-- Description: Complete SQL — Setup, Cleaning, Analysis
-- ============================================================

-- ─────────────────────────────────────────
-- SECTION 1: DATABASE & TABLE SETUP
-- ─────────────────────────────────────────

CREATE DATABASE Superstore_db;
USE Superstore_db;

CREATE TABLE sales (
    Row_ID        INT,
    Order_ID      VARCHAR(50),
    Order_Date    VARCHAR(15),
    Ship_Date     VARCHAR(15),
    Ship_Mode     VARCHAR(50),
    Customer_ID   VARCHAR(50),
    Customer_Name VARCHAR(100),
    Segment       VARCHAR(50),
    Country       VARCHAR(100),
    City          VARCHAR(100),
    State         VARCHAR(100),
    Postal_Code   VARCHAR(20),
    Region        VARCHAR(50),
    Product_ID    VARCHAR(50),
    Category      VARCHAR(100),
    Sub_Category  VARCHAR(100),
    Product_Name  TEXT,
    Sales         FLOAT,
    Quantity      INT,
    Discount      FLOAT,
    Profit        FLOAT,
    Delivery_Days INT,
    Revenue_Flag  VARCHAR(20)
);


-- ─────────────────────────────────────────
-- SECTION 2: LOAD DATA
-- ─────────────────────────────────────────

SET SESSION sql_mode = '';

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Superstore_Messy_1.csv'
INTO TABLE sales
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(Row_ID, Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID, Customer_Name,
 Segment, Country, City, State, Postal_Code, Region, Product_ID, Category,
 Sub_Category, Product_Name, Sales, Quantity, Discount, Profit, Delivery_Days, Revenue_Flag);


-- ─────────────────────────────────────────
-- SECTION 3: VERIFY LOAD
-- ─────────────────────────────────────────

SELECT COUNT(*) AS total_rows FROM sales;
SELECT DISTINCT Region   FROM sales ORDER BY Region ASC;
SELECT DISTINCT Category FROM sales ORDER BY Category;

SELECT
    SUM(CASE WHEN Sales  IS NULL THEN 1 ELSE 0 END) AS missing_sales,
    SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END) AS missing_profit
FROM sales;

SELECT COUNT(*) AS bad_delivery FROM sales WHERE Delivery_Days < 0;
SELECT * FROM sales LIMIT 5;


-- ─────────────────────────────────────────
-- SECTION 4: DATA CLEANING
-- ─────────────────────────────────────────

SET SQL_SAFE_UPDATES = 0;

-- 1. Fix Region Casing (west/WEST/EAST → West/East)
UPDATE sales
SET Region = CONCAT(UPPER(SUBSTR(Region,1,1)), LOWER(SUBSTR(Region,2)));

SELECT DISTINCT Region FROM sales;

-- 2. Fix Category Typos
UPDATE sales
SET Category = CASE
    WHEN Category = 'Furnitur'      THEN 'Furniture'
    WHEN Category = 'Office Supply' THEN 'Office Supplies'
    WHEN Category = 'Technolgy'     THEN 'Technology'
    ELSE Category
END;

SELECT DISTINCT Category FROM sales;

-- 3. Fix Missing Sales (replace NULL with average)
UPDATE sales
SET Sales = (
    SELECT avg_sales
    FROM (SELECT AVG(Sales) AS avg_sales FROM sales) AS A
)
WHERE Sales IS NULL;

SELECT COUNT(*) AS missing_sales FROM sales WHERE Sales IS NULL;

-- 4. Fix Missing Profit (replace NULL with 0)
UPDATE sales
SET Profit = 0
WHERE Profit IS NULL;

SELECT COUNT(*) AS missing_profit FROM sales WHERE Profit IS NULL;

-- 5. Fix Negative Delivery Days
UPDATE sales
SET Delivery_Days = ABS(Delivery_Days)
WHERE Delivery_Days < 0;

SELECT COUNT(*) AS bad_delivery FROM sales WHERE Delivery_Days < 0;

-- 6. Remove Duplicate Rows
CREATE TABLE sales_clean AS 
SELECT DISTINCT * FROM sales;

SELECT COUNT(*) AS old_count FROM sales;
SELECT COUNT(*) AS new_count FROM sales_clean;

DROP TABLE sales;

RENAME TABLE sales_clean TO sales;

SELECT COUNT(*) AS final_count FROM sales;

-- 7. Fix Date Columns (VARCHAR to DATE)
UPDATE sales SET Order_Date = DATE_FORMAT(STR_TO_DATE(Order_Date, '%m/%d/%Y'), '%Y-%m-%d');
UPDATE sales SET Ship_Date  = DATE_FORMAT(STR_TO_DATE(Ship_Date,  '%m/%d/%Y'), '%Y-%m-%d');

ALTER TABLE sales 
MODIFY Order_Date DATE;

ALTER TABLE sales 
MODIFY Ship_Date  DATE;

SELECT Order_Date, Ship_Date 
FROM sales LIMIT 5;

SET SQL_SAFE_UPDATES = 1;


-- ─────────────────────────────────────────
-- SECTION 5: FINAL CLEAN DATA CHECK
-- ─────────────────────────────────────────

-- Expected: 9994 rows | 4 regions | 3 categories | 0 nulls | 0 bad days
SELECT
    COUNT(*)                                            AS total_rows,
    COUNT(DISTINCT Region)                              AS regions,
    COUNT(DISTINCT Category)                            AS categories,
    SUM(CASE WHEN Sales IS NULL THEN 1 ELSE 0 END)     AS missing_sales,
    SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END)    AS missing_profit,
    SUM(CASE WHEN Delivery_Days < 0 THEN 1 ELSE 0 END) AS bad_delivery_days
FROM sales;


-- ─────────────────────────────────────────
-- SECTION 6: BUSINESS INSIGHTS
-- ─────────────────────────────────────────

-- Q1: Which Category Makes the Most Profit?
-- Finding:  Technology    → Highest profit
		 --  Office Supply → Medium profit
         --  Furniture     → Lowest profit
SELECT
    Category,
    ROUND(SUM(Profit), 2)         AS total_profit,
    ROUND(SUM(Sales), 2)          AS total_sales,
    ROUND(AVG(Discount) * 100, 1) AS avg_discount
FROM sales
GROUP BY Category
ORDER BY total_profit DESC;


-- Q2: Which Region Performs Best?
-- Finding: West = highest profit and sales
--          East = second best
--          South = Weak sales performance
--          Central = Central region is the biggest concern — even though it has a good number of orders, it makes the least profit. This could be because of high discounts or higher costs.
SELECT
    Region,
    ROUND(SUM(Sales), 2)     AS total_sales,
    ROUND(SUM(Profit), 2)    AS total_profit,
    COUNT(DISTINCT Order_ID) AS total_orders
FROM sales
GROUP BY Region
ORDER BY total_profit DESC;
 

-- Q3. Which Sub-Categories Are Losing Money?
-- Finding: Tables & Bookcases lose money despite high sales
SELECT
    Sub_Category,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(SUM(Sales), 2)  AS total_sales
FROM sales
GROUP BY Sub_Category
HAVING total_profit < 0
ORDER BY total_profit ASC;


-- Q4: Monthly Revenue Trend
-- Finding: September, November, December appear  every single year  = peak season every year
SELECT  
	year(order_date)                  AS years,
    monthname(order_date)             AS month_name,
    COUNT(DISTINCT Order_ID)          AS total_orders,
    ROUND(SUM(Sales), 2)              AS monthly_revenue,
    ROUND(SUM(Profit), 2)             AS monthly_profit,
    rank() over (partition by year(order_date)order by sum(sales) desc) as rank_year
FROM sales
GROUP BY years,month_name
ORDER BY years ASC;

-- Q5: Top 10 Most Profitable Customers
-- Finding: Hunter Lopez = highest margin (48%) from just 2 orders
-- Finding: Consumer segment = 7 out of 10 VIP customers
-- Finding: Central region = 4 out of 10 VIP customers
SELECT
    Customer_Name,
    Segment,
    Region,
    COUNT(Order_ID)        AS total_orders,
    ROUND(SUM(Sales), 2)  AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    round(sum(profit)/sum(sales)*100,1) as profit_margin
FROM sales
GROUP BY Customer_Name, Segment, Region
ORDER BY total_profit DESC
LIMIT 10;


-- Q6: Shipping Mode Analysis
-- Finding: Is faster shipping worth the cost?
SELECT
    Ship_Mode,
    COUNT(*)                         AS total_orders,
    ROUND(SUM(Sales), 2)             AS total_sales,
    ROUND(SUM(Profit), 2)            AS total_profit,
    ROUND(AVG(Delivery_Days), 1)     AS avg_delivery_days,
    ROUND(SUM(Profit) / COUNT(*), 2) AS profit_per_order
FROM sales
GROUP BY Ship_Mode
ORDER BY total_orders DESC;


-- Q7: Best and Worst States
SELECT State, 
ROUND(SUM(Profit), 2) AS total_profit
FROM sales 
GROUP BY State 
ORDER BY total_profit DESC 
LIMIT 5;

SELECT State, 
ROUND(SUM(Profit), 2) AS total_profit
FROM sales 
GROUP BY State 
ORDER BY total_profit ASC  
LIMIT 5;


-- Q8: Discount Impact on Profit
-- Finding: 40%+ discount destroys profit margin
SELECT
    CASE
        WHEN Discount = 0     THEN 'No Discount (0%)'
        WHEN Discount <= 0.20 THEN 'Low Discount (1-20%)'
        WHEN Discount <= 0.40 THEN 'Medium Discount (21-40%)'
        ELSE                       'High Discount (41-80%)'
    END                              AS discount_range,
    COUNT(*)                         AS total_orders,
    ROUND(SUM(Sales), 2)             AS total_sales,
    ROUND(SUM(Profit), 2)            AS total_profit,
    ROUND(AVG(Profit), 2)            AS avg_profit_per_order
FROM sales
GROUP BY discount_range
ORDER BY total_profit DESC;


-- ============================================================
-- KEY FINDINGS SUMMARY
-- ============================================================
-- Q1: Technology    = highest profit category              (+)
-- Q1: Furniture     = lowest profit category               (!)
-- Q2: West Region   = best performing region               (+)
-- Q2: Central       = lowest profit region                 (!)
-- Q3: Tables        = biggest money loser sub-category     (-)
-- Q3: Bookcases     = second biggest money loser           (-)
-- Q4: Q3-Q4 months (Sep,Nov,Dec) = peak every year         (+)
-- Q5: Top customers = mostly Consumer segment              (+)
-- Q6: Standard Class= most used shipping mode              (+)
-- Q8: 40%+ discount = destroys profit margin               (-)
-- ============================================================


