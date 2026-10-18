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


### Products table

`product_id`,	             TEXT (Primary Key),         SKU identifier, e.g. SKU001

`product_name`,	            TEXT,	                      Display name

`category`,	                TEXT,	                      One of: Beverages, Snacks, Dairy, Household, Produce

`unit_cost`,	               NUMERIC,	                  Cost to the business per unit

`unit_price`,	              NUMERIC,	                  Retail selling price per unit

`lead_time_days`,	          INTEGER,	                   Supplier lead time used for reorder point calc

`safety_stock_days`,	        INTEGER,	                 Buffer days of stock cover incase of mishappenings like stock                                                                delays, or unforeseen spike instock demand, kept on top of lead time


### Sales Table ###

`product_id`,	             TEXT (Foreign Key),             References Primary Key in Products table

`category`,	               TEXT,	                        Denormalised for convenience (matches clean.products.category)

`units_sold`,	             INTEGER,	                    Actual units sold that day (capped by available stock)

`unit_price`,	             NUMERIC,	                    Price on that day specifically(price varies on promotion days)

`promotion_flag`,	         BOOLEAN,	                    `True` if the SKU was on promotion that day, `False` if otherwise

`stock_level_end_of_day`,	  NUMERIC,	                    Stock remaining after that day's sales

`stockout_flag`,	           BOOLEAN,	                    `True` if demand exceeded available stock 

`date` ,                    DATE,                         Calender date

**Change log**
1. 91 duplicates removed from the ***sales_transactions_production*** table, after standardising `category` column casing (5        categories had mixed-case variants)
2. back-filled 176 missing `unit_price` values from products table ***products_production***

**NOTE:**
`stockout_flag` marks days where recorded sales undercount true demand — when forecasting, we shall treat `units_sold` on stockout days as a lower bound, not ground truth (this matters most for the forecasting step, not the cleaning step).

## FEATURE ENGINEERING ##
Feature engineering is an important feature prior forecasting models.
We basically want to enrich our data with deliverables that will be adopted in our later forecast models, for instance;

**Calendar features**
```python
mergetable['day_of_week'] = mergetable['date'].dt.day_name()        #monday, tuesday......
mergetable['is_weekend'] = mergetable['date'].dt.dayofweek>=5       #'True' if Saturdays and Sundays, otherwise 'False' [Monday(0), Tuesday(1), Wed(2)....]
mergetable['Month'] = mergetable['date'].dt.month                   #'Jan', 'Feb', 'March'
mergetable['Quarter'] = mergetable['date'].dt.quarter
mergetable['is_festive'] = mergetable['Month'].isin([11,12])     #Nov and Dec, festive seasons
mergetable['day_of_year'] = mergetable['date'].dt.dayofyear
```

Our new table will have extra columns for instance : `is_festive` and `is_weekend` which are boolean values, `Month` which stands for the sale month, `day_of_week` with values like Mondays, Tuesdays....etc

**Time_series_features**

(rolling averages)
```python
g = mergetable.groupby('product_id')['units_sold'] 
mergetable['rolling_7d_avg'] = g.transform(lambda x: x.rolling(7, min_periods = 1).mean())
mergetable['rolling_28d_avg'] = g.transform(lambda x: x.rolling(28, min_periods = 1).mean())
```
(lagging daily sales)
```python
mergetable['previous_day_sale'] = g.shift(1)
mergetable['previous_week_sale'] = g.shift(7)
```

We are essentially transforming raw sales data into historical demand features that a forecasting model can use to learn patterns such as weekly behavior, recent trends, seasonality, and previous demand.

## EDA SUMMARY ##

Average units sold on Weekdays : `42`, Average units sold on weekends : `50`. So asically weekend sales run `20%` above weekday sales.

Date Range of our data : from `1-1-2024` to `31-12-2025` which  is 2 years.

Total Revenue generated: `105,936,670` KSH

Promotions lift the average units sold by `53.2%`.

Snacks is topping the list of categories with a stockout rate of `3.2%`. This is to say, the days that true demand for snacks exceed available stock, amount to 3.2% of the total days in the dataset.


## FORECAST MODELS
### MODEL EVALUATION
We first tested our data with baseline forecasting models like Seasonal Naive, and Simple Moving Average then we moved on to Exponential Smoothing to uncover trends and seasonal patterns lying underneath our data. The latter uses all past data points infinitely, applying an exponential decay so newer data has a much higher impact than older data. 

The model with the least error is the most accurate:

| Models                | Mae  | Rmse  |
|-----------------------|------|-------|
| Simple Moving Average | 7.2  | 9.8   |
| Holt Winter           | 6.3  | 8.0   |
| Seasonal Naive        | 9.97 | 12.11 |

**NOTE** The above data was analysed from a 7 days window, meaning:
1. Seasonal Naive uses the last 7 days of our training data to forecast fututre values
2. Simple Moving Average finds the average of the last 7 days of our training data and uses that average to forecast future values.
3. Holt winter(Exponential Smoothing) uses last 7 days of our training data to uncover trends and seasonality then uses the exact logic to forecast future values.

Seeing that our data comprises of different SKUS combined in one table, we will use The moving average which assumes the forecast values is constant across all the forecasted days, that way we can compress each SKU result into one row and end up with 25 rows in our forecast table.

### REORDER LOGIC
Our forecasted table has 25 SKUs each having a forecasted value of units_sold.We need to esatablish a reorder point based on  leadtime days and safety stock days. These two deliverables are from the product master table so we have to merge the two tables.We will also merge the sales table so as to get the current stock value.

### Data enrichment
To arrive to our desired objective of generating a demand forecast, we formed new columns:
```python
1. leadtime_demand = lead_time_days * average_daily_forecast                           #forecasted value
2. safetystock_units = safety_stock_days * average_daily_forecast
3. reorder_point = safetystock_units + leadtime_demand
4. forecasted_14_day_total = 14 * average_daily_forecast                               #14 is total forecast days
5. current_stock = stock_level_end_of_day                                              #from sales table
6. days_of_cover = current_stock / average_daily_forecast
7. status                                                                              #(a conditional column)
8. order_upto_level = leadtime_demand + safetystock_units + forecasted_14_day_total
9. gap = order_upto_level - current_stock
10. suggested_order_quantity                                                           #(a conditional column )
```

`days_of_cover` basically gives us the number of days we have to sustain our customers before we deplete our stock.
`order_upto_level` is how we wish our stock to be, enough to cover the next 14 days, considering also leadtime and safetystock units. The `gap` column simply shows us the gap we have between where we are now, and where we want to be quantity wise.
The `status` column guides us on how we should reorder our stock, and what quantitites are we reordering. It is derived from 4 conditions:
1. `Critical` - days_of_cover < leadtime_demand (this means even if you reorder immediately, your stock will be depleted                     before the supplier delivers.
2. `reorder_now` - current_stock <= reorder_point ( if you reorder now , youll still have enough stock to get you by before                     your next restock arrives, but this doesnt necessarily cover for the safety stock units incase there is                      an unexpected spike in demand). 
3. `watch_out` - `current_stock` <= (`reorder_point` * 1.25) - here current stock is within 25% above the reorder point, so                   there's no need to reorder immediately but watch out for your stock so that it doesnt run out.
4. `OK` - This status means the current stock is way above 25% of your reorder_point, there's really no need to reorder,               unless one wants to themselves.

The whole point of the reorder logic is to meet our clients demands while otimising on the resources we have at hand (C apital used for the restock). We dont necessarily want to deplete our Inventory Output in purchasing deadstocks espeially the fact that some products are perishable. This now takes us to the next step which is the `suggested order quantity` where we only reorder stocks for SKU's whose status are `reorder_now` and `Critical`.

