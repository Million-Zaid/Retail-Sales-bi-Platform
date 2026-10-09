use warehouse  IMT577_MILLION_DW_STAGING;

-- select database to use 
use database IMT577_MILLION_STAGING;

-- VIEWS — DIMENSIONS

CREATE OR REPLACE SECURE VIEW View_Dim_Product AS
SELECT
    DimProductID,
    ProductID,
    ProductTypeID,
    ProductCategoryID,
    ProductName,
    ProductType,
    ProductCategory,
    ProductRetailPrice,
    ProductWholesalePrice,
    ProductCost,
    ProductRetailProfit,
    ProductWholesaleUnitProfit,
    ProductProfitMarginUnitPercent
FROM Dim_Product;



CREATE OR REPLACE SECURE VIEW View_Dim_Location AS
SELECT
    DimLocationID,
    Address,
    City,
    PostalCode,
    State_Province,
    Country
FROM Dim_Location;

CREATE OR REPLACE SECURE VIEW View_Dim_Customer AS
SELECT
    DimCustomerID,
    DimLocationID,
    CustomerID,
    CustomerFullName,
    CustomerFirstName,
    CustomerLastName,
    CustomerGender
FROM Dim_Customer;

CREATE OR REPLACE SECURE VIEW View_Dim_Reseller AS
SELECT
    DimResellerID,
    DimLocationID,
    ResellerID,
    ResellerName,
    ContactName,
    PhoneNumber,
    Email
FROM Dim_Reseller;

CREATE OR REPLACE SECURE VIEW View_Dim_Store AS
SELECT
    DimStoreID,
    DimLocationID,
    SourceStoreID,
    StoreName,
    StoreNumber,
    StoreManager
FROM Dim_Store;

CREATE OR REPLACE SECURE VIEW View_Dim_Channel AS
SELECT
    DimChannelID,
    ChannelID,
    ChannelCategoryID,
    ChannelName,
    ChannelCategory
FROM Dim_Channel;

CREATE OR REPLACE SECURE VIEW View_Dim_Date AS
SELECT
    DATE_PKEY,
    DATE,
    FULL_DATE_DESC,
    DAY_NUM_IN_WEEK,
    DAY_NUM_IN_MONTH,
    DAY_NUM_IN_YEAR,
    DAY_NAME,
    DAY_ABBREV,
    WEEKDAY_IND,
    US_HOLIDAY_IND,
    _HOLIDAY_IND,
    MONTH_END_IND,
    WEEK_BEGIN_DATE_NKEY,
    WEEK_BEGIN_DATE,
    WEEK_END_DATE_NKEY,
    WEEK_END_DATE,
    WEEK_NUM_IN_YEAR,
    MONTH_NAME,
    MONTH_ABBREV,
    MONTH_NUM_IN_YEAR,
    YEARMONTH,
    QUARTER,
    YEARQUARTER,
    YEAR,
    FISCAL_WEEK_NUM,
    FISCAL_MONTH_NUM,
    FISCAL_YEARMONTH,
    FISCAL_QUARTER,
    FISCAL_YEARQUARTER,
    FISCAL_HALFYEAR,
    FISCAL_YEAR,
    SQL_TIMESTAMP,
    CURRENT_ROW_IND,
    EFFECTIVE_DATE,
    EXPIRATION_DATE
FROM DIM_DATE;

select count(*) from view_dim_date;
-- VIEWS — FACTS

CREATE OR REPLACE SECURE VIEW View_Fact_SalesActual AS
SELECT
    DimProductID,
    DimStoreID,
    DimResellerID,
    DimCustomerID,
    DimChannelID,
    DimSaleDateID,
    DimLocationID,
    SalesHeaderID,
    SalesDetailID,
    SaleAmount,
    SaleQuantity,
    SaleUnitPrice,
    SaleExtendedCost,
    SaleTotalProfit
FROM Fact_SalesActual;

CREATE OR REPLACE SECURE VIEW View_Fact_ProductSalesTarget AS
SELECT
    DimProductID,
    DimTargetDateID,
    ProductTargetSalesQuantity
FROM Fact_ProductSalesTarget;

CREATE OR REPLACE SECURE VIEW View_Fact_SRCSalesTarget AS
SELECT
    DimStoreID,
    DimResellerID,
    DimChannelID,
    DimTargetDateID,
    SalesTargetAmount
FROM Fact_SRCSalesTarget;



-- Aggregate Views for Analytics

--View 1: Question 3 of business requirements 
CREATE OR REPLACE SECURE VIEW View_Product_Sales_By_DayOfWeek AS
SELECT
    st.StoreNumber                AS StoreNumber,
    st.StoreName                  AS StoreName,
    dt.DAY_NAME                   AS DayName,
    dt.DAY_NUM_IN_WEEK            AS DayNumberInWeek,
    pr.ProductName                AS ProductName,
    pr.ProductCategory            AS ProductCategory,
    SUM(fsa.SaleAmount)           AS TotalSalesAmount,
    SUM(fsa.SaleQuantity)         AS TotalQuantity,
    SUM(fsa.SaleTotalProfit)      AS TotalProfit
FROM Fact_SalesActual fsa
INNER JOIN Dim_Store   st ON fsa.DimStoreID    = st.DimStoreID
INNER JOIN Dim_Product pr ON fsa.DimProductID  = pr.DimProductID
INNER JOIN DIM_DATE    dt ON fsa.DimSaleDateID = dt.DATE_PKEY
WHERE st.StoreNumber IN (10, 21)
GROUP BY
    st.StoreNumber,
    st.StoreName,
    dt.DAY_NAME,
    dt.DAY_NUM_IN_WEEK,
    pr.ProductName,
    pr.ProductCategory;

select * from view_product_sales_by_dayofweek;
    
    
    --View 2 for Question 4 of business requirements
    CREATE OR REPLACE SECURE VIEW View_Store_Location_Sales_Summary AS
SELECT
    st.StoreNumber                     AS StoreNumber,
    st.StoreName                       AS StoreName,
    lo.City                            AS City,
    lo.State_Province                  AS State_Province,
    lo.Country                         AS Country,
    dt.YEAR                            AS SalesYear,
    SUM(fsa.SaleAmount)                AS TotalSalesAmount,
    SUM(fsa.SaleTotalProfit)           AS TotalProfit,
    SUM(fsa.SaleQuantity)              AS TotalQuantity,
    COUNT(DISTINCT fsa.SalesHeaderID)  AS NumberOfTransactions
FROM Fact_SalesActual fsa
INNER JOIN Dim_Store    st ON fsa.DimStoreID    = st.DimStoreID
INNER JOIN Dim_Location lo ON fsa.DimLocationID = lo.DimLocationID
INNER JOIN DIM_DATE     dt ON fsa.DimSaleDateID = dt.DATE_PKEY
WHERE st.DimStoreID <> -1
GROUP BY
    st.StoreNumber,
    st.StoreName,
    lo.City,
    lo.State_Province,
    lo.Country,
    dt.YEAR;
    
select * from view_store_location_sales_summary;
--view 3 for question 1 of business requirements
    CREATE OR REPLACE SECURE VIEW View_Store_Sales_By_Year AS
SELECT
    st.StoreNumber            AS StoreNumber,
    st.StoreName              AS StoreName,
    dt.YEAR                   AS SalesYear,
    SUM(fsa.SaleAmount)       AS TotalSalesAmount,
    SUM(fsa.SaleTotalProfit)  AS TotalProfit,
    SUM(fsa.SaleQuantity)     AS TotalQuantity
FROM Fact_SalesActual fsa
INNER JOIN Dim_Store st ON fsa.DimStoreID    = st.DimStoreID
INNER JOIN DIM_DATE  dt ON fsa.DimSaleDateID = dt.DATE_PKEY
WHERE st.DimStoreID <> -1
GROUP BY st.StoreNumber, st.StoreName, dt.YEAR;

select * from View_Store_Sales_By_Year;