-- ============================================================
--STAGING AREA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS RETAIL;
set search_path to RETAILS;

DROP TABLE IF EXISTS products_staging;
CREATE TABLE RETAIL.products_staging (
    product_id          TEXT,
    product_name        TEXT,
    category            TEXT,
    unit_cost           TEXT,
    unit_price          TEXT,
    lead_time_days      TEXT,
    safety_stock_days   TEXT
);

DROP TABLE IF EXISTS RETAIL.sales_transactions_staging;
CREATE TABLE RETAIL.sales_transactions_staging (
    sale_date               VARCHAR(50),
    product_id              TEXT,
    product_name             TEXT,
    category                TEXT,
    units_sold               TEXT,
    unit_price               TEXT,
    promotion_flag           TEXT,
    stock_level_end_of_day   TEXT,
    stockout_flag            TEXT
);

select * from retail.sales_transactions_staging sts ;
select count(*) from retail.sales_transactions_staging sts ;

alter table retail.sales_transactions_staging 
drop column sale_date;




--checking for  duplicates
select 
product_id, product_name,category,units_sold,unit_price,promotion_flag,stock_level_end_of_day, stockout_flag, date, 
count(*) as occurences
from retail.sales_transactions_staging
group by  product_id, product_name,category,units_sold,unit_price,promotion_flag,stock_level_end_of_day, stockout_flag, date
having count(*) > 1;









--creating a temporary_table for sales_transactions
create table temp_table as 
select distinct * from retail.sales_transactions_staging;

select * from temp_table;














--CLEANING DATA
--1.product_id cleaning
select distinct product_id from retail.sales_transactions_staging
order by product_id asc;





--2.product_name cleaning
select distinct product_name from  retail.sales_transactions_staging sts ;






--3.category
select distinct category from retail.sales_transactions_staging sts ;
select category, initcap(trim(category)) as cleaned_category
from retail.sales_transactions_staging sts ;


update retail.sales_transactions_staging sts 
set category = initcap(trim(category)) 
where category != initcap(trim(category));







--4units_sold
select distinct units_sold from retail.sales_transactions_staging sts
order by units_sold desc;






--5unit_pricing
select distinct unit_price from retail.sales_transactions_staging sts
order by unit_price desc;






select * from retail.products_staging ps  ;
select distinct product_id from retail.products_staging ps 
order by product_id ;
