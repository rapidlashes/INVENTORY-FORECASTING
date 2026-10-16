set search_path to retail;
create table retail.products_production (
product_id           varchar(50) primary key ,
product_name         varchar(50),
category             varchar(50),
unit_cost            numeric,
unit_price           numeric,
lead_time_days       int,
safety_stock_days    int
);

insert into retail.products_production (
product_id,
product_name,
category,
unit_cost,
unit_price,
lead_time_days,
safety_stock_days
)
select 
product_id,
product_name,
category,
unit_cost::numeric,
unit_price::numeric,
lead_time_days::int,
safety_stock_days::int
from retail.products_staging ps ;

select * from retail.products_production;








create table retail.sales_transactions_production(
product_id       VARCHAR(50) not null references retail.products_production(product_id),
product_name     VARCHAR(50),
category         VARCHAR(50),
units_sold       INT,
unit_price       numeric,
promotion_flag   VARCHAR(50),
stock_level_end_of_day  numeric,
stockout_flag           VARCHAR(50),
date                    DATE 
);

select * from retail.sales_transactions_production;





insert into retail.sales_transactions_production (
product_id,
product_name,
category,
units_sold,
unit_price,
promotion_flag,
stock_level_end_of_day,
stockout_flag,
date
)
select 
product_id,
initcap(trim(product_name)) ,
initcap(trim(category)),
units_sold::int,
nullif(trim(unit_price),'')::numeric,
promotion_flag,
nullif(trim(stock_level_end_of_day),'')::numeric,
stockout_flag,
date::DATE 
from public.temp_table;








select * from retail.sales_transactions_production
where unit_price is null;



update retail.sales_transactions_production stp
set unit_price = pp.unit_price
from retail.products_production pp 
where stp.product_id = pp.product_id and stp.unit_price is null;













--QC checks
--confirming count of rows in staging and production tables for sales_transactions
select count (*) from retail.sales_transactions_staging sts ;
select count(*) from retail.sales_transactions_production;


--confirming counts of rows in staging table and production table for products(25 in each) 
select count(*)from retail.products_staging ps ;
select count(*) from retail.products_production pp ;

select * from retail.sales_transactions_production;
select * from retail.products_production;


--checking if there are still pending duplicate rows in the production table for sales_transactions
select product_id, product_name, category, units_sold, unit_price, promotion_flag, stock_level_end_of_day, stockout_flag, date, count(*) as occurrences
from retail.sales_transactions_production
group by product_id, product_name, category, units_sold, unit_price, promotion_flag, stock_level_end_of_day, stockout_flag, date
having count(*) > 1;

