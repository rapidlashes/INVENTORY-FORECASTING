## OVERVIEW ##
The project takes on another step from the usual cleaning, transforming and visualizing data to building models.
Using sales and stock data , we will build a forescasting model that predicts future demand and sales of products.
This is the flow : 
**Sales/stock data → EDA → simple forecasting model (e.g. moving average or basic regression) → dashboard of reorder recommendations.**

## Problem Statement ##
"Predict future product demand and generate reorder recommendations for a retail/supermarket business, using historical sales and stock data." This framing shows both technical depth and business understanding — connecting the model output to an actual decision (when to reorder, how much).

## Data Source ##
Synthetic/simulated data —  Generated realistic daily sales for ~20-50 SKUs over 1-2 years with seasonality, trends, and randomness using Python.


## Cleaning and Transformation ##
The dataset had 2 tables, **sales table** and **products table**, both messy and up for cleaning.
Loaded the data in my postgressql database, did the cleaning which includes removing duplicates and filling missing values in the **sales table**  , column `unit_price` with data from the **products table**.


### Products table ##

`product_id`,	             TEXT (Primary Key),         SKU identifier, e.g. SKU001

`product_name`,	            TEXT,	                      Display name

`category`,	                TEXT,	                      One of: Beverages, Snacks, Dairy, Household, Produce

`unit_cost`,	               NUMERIC,	                  Cost to the business per unit

`unit_price`,	              NUMERIC,	                  Retail selling price per unit

`lead_time_days`,	          INTEGER,	                   Supplier lead time used for reorder point calc

`safety_stock_days`,	        INTEGER,	                 Buffer days of stock cover incase of mishappenings like stock                                                                delays, or unforeseen spike instock demand, kept on top of lead time


### Sales Table ###

`product_id`,	             TEXT (Foreign Key),

`category`,	               TEXT,	                        Denormalised for convenience (matches clean.products.category)

`units_sold`,	             INTEGER,	                    Actual units sold that day (capped by available stock)

`unit_price`,	             NUMERIC,	                    Price on that day specifically(price varies on promotion days)

`promotion_flag`,	         BOOLEAN,	                    `True` if the SKU was on promotion that day, `False` if otherwise

`stock_level_end_of_day`,	  NUMERIC,	                    Stock remaining after that day's sales

`stockout_flag`,	           BOOLEAN,	                    `True` if demand exceeded available stock 

`date` ,                    Date,                         Calender date

**Change log**
1. 91 duplicates removed from the `sales_transactions_production` table, after standardising `category` column casing (5        categories had mixed-case variants)
2. back-filled 176 missing `unit_price` values from products table `products_production`

**NOTE:**
`stockout_flag` marks days where recorded sales undercount true demand — when forecasting, we shall treat `units_sold` on stockout days as a lower bound, not ground truth (this matters most for the forecasting step, not the cleaning step).


