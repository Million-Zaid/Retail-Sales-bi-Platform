-- select warehouse to use
use warehouse  IMT577_MILLION_DW_STAGING;

-- select database to use 
use database IMT577_MILLION_STAGING;

-- FACT TABLE 1
-- FACT_SALESACTUAL FACT 
CREATE OR REPLACE TABLE Fact_SalesActual (
    DimProductID     INT   NOT NULL CONSTRAINT FK_DimProductID   FOREIGN KEY REFERENCES Dim_Product(DimProductID),
    DimStoreID       INT   NOT NULL CONSTRAINT FK_DimStoreID     FOREIGN KEY REFERENCES Dim_Store(DimStoreID),
    DimResellerID    INT   NOT NULL CONSTRAINT FK_DimResellerID  FOREIGN KEY REFERENCES Dim_Reseller(DimResellerID),
    DimCustomerID    INT   NOT NULL CONSTRAINT FK_DimCustomerID  FOREIGN KEY REFERENCES Dim_Customer(DimCustomerID),
    DimChannelID     INT   NOT NULL CONSTRAINT FK_DimChannelID   FOREIGN KEY REFERENCES Dim_Channel(DimChannelID),
    DimSaleDateID    number(9)   NOT NULL CONSTRAINT FK_DimSaleDateID  FOREIGN KEY REFERENCES DIM_DATE(DATE_PKEY),
    DimLocationID    INT   NOT NULL CONSTRAINT FK_DimLocationID  FOREIGN KEY REFERENCES Dim_Location(DimLocationID),
    SalesHeaderID    INT   NOT NULL,
    SalesDetailID    INT   NOT NULL,
    SaleAmount       FLOAT NOT NULL,
    SaleQuantity     FLOAT NOT NULL,
    SaleUnitPrice    FLOAT NOT NULL,
    SaleExtendedCost FLOAT NOT NULL,
    SaleTotalProfit  FLOAT NOT NULL
);

INSERT INTO Fact_SalesActual (
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
)
SELECT
    dp.DimProductID                                                          AS DimProductID,
    NVL(ds.DimStoreID, -1)                                                   AS DimStoreID,
    NVL(dr.DimResellerID, -1)                                                AS DimResellerID,
    NVL(dc.DimCustomerID, -1)                                                AS DimCustomerID,
    NVL(dch.DimChannelID, -1)                                                AS DimChannelID,
    NVL(dd.DATE_PKEY, -1)                                                    AS DimSaleDateID,
    NVL(NVL(NVL(ds.DimLocationID, dc.DimLocationID), dr.DimLocationID), -1)  AS DimLocationID,
    sh.SalesHeaderID,
    sd.SalesDetailID,
    sd.SalesAmount                                                           AS SaleAmount,
    sd.SalesQuantity                                                         AS SaleQuantity,
    dp.ProductRetailPrice                                                    AS SaleUnitPrice,
    dp.ProductCost * sd.SalesQuantity                                        AS SaleExtendedCost,
    sd.SalesAmount - (dp.ProductCost * sd.SalesQuantity)                     AS SaleTotalProfit
FROM STAGE_SALES_DETAIL sd
INNER JOIN STAGE_SALES_HEADER sh   ON sd.SalesHeaderID  = sh.SalesHeaderID
INNER JOIN Dim_Product        dp   ON sd.ProductID      = dp.ProductID
LEFT  JOIN Dim_Store          ds   ON sh.StoreID        = ds.SourceStoreID
LEFT  JOIN Dim_Reseller       dr   ON sh.ResellerID     = dr.ResellerID
LEFT  JOIN Dim_Customer       dc   ON sh.CustomerID     = dc.CustomerID
LEFT  JOIN Dim_Channel        dch  ON sh.ChannelID      = dch.ChannelID
LEFT  JOIN DIM_DATE           dd   ON TO_DATE(sh.Date)  = dd.DATE;

-- Verifying rows
SELECT COUNT(*) FROM Fact_SalesActual;
SELECT * FROM Fact_SalesActual LIMIT 20;

-- FACT TABLE 2
-- FACT_PRODUCTSALESTARGET
CREATE OR REPLACE TABLE Fact_ProductSalesTarget (
    DimProductID               INT   NOT NULL CONSTRAINT FK_DimProductID    FOREIGN KEY REFERENCES Dim_Product(DimProductID),
    DimTargetDateID            number(9)   NOT NULL CONSTRAINT FK_DimTargetDateID FOREIGN KEY REFERENCES DIM_DATE(DATE_PKEY),
    ProductTargetSalesQuantity FLOAT NOT NULL
);

INSERT INTO Fact_ProductSalesTarget (
    DimProductID,
    DimTargetDateID,
    ProductTargetSalesQuantity
)
SELECT
    NVL(dp.DimProductID, -1)        AS DimProductID,
    dd.DATE_PKEY                    AS DimTargetDateID,
    stp.SalesQuantityTarget         AS ProductTargetSalesQuantity
FROM STAGE_TARGET_PRODUCT stp
LEFT JOIN Dim_Product dp
    ON stp.ProductID = dp.ProductID
INNER JOIN DIM_DATE dd
    ON dd.YEAR = TO_NUMBER(stp.Year);

-- verifying row counts
SELECT COUNT(*) FROM Fact_ProductSalesTarget;
SELECT COUNT(*) FROM STAGE_TARGET_PRODUCT;
SELECT * FROM Fact_ProductSalesTarget LIMIT 20;


-- FACT TABLE 3
-- FACT_SRCSALESTARGET
CREATE OR REPLACE TABLE Fact_SRCSalesTarget (
    DimStoreID        INT   NOT NULL CONSTRAINT FK_DimStoreID      FOREIGN KEY REFERENCES Dim_Store(DimStoreID),
    DimResellerID     INT   NOT NULL CONSTRAINT FK_DimResellerID   FOREIGN KEY REFERENCES Dim_Reseller(DimResellerID),
    DimChannelID      INT   NOT NULL CONSTRAINT FK_DimChannelID    FOREIGN KEY REFERENCES Dim_Channel(DimChannelID),
    DimTargetDateID   number(9)   NOT NULL CONSTRAINT FK_DimTargetDateID FOREIGN KEY REFERENCES DIM_DATE(DATE_PKEY),
    SalesTargetAmount FLOAT NOT NULL
);

INSERT INTO Fact_SRCSalesTarget (
    DimStoreID,
    DimResellerID,
    DimChannelID,
    DimTargetDateID,
    SalesTargetAmount
)
SELECT
    NVL(ds.DimStoreID, -1)        AS DimStoreID,
    NVL(dr.DimResellerID, -1)     AS DimResellerID,
    NVL(dch.DimChannelID, -1)     AS DimChannelID,
    dd.DATE_PKEY                  AS DimTargetDateID,
    stc.TargetSalesAmount         AS SalesTargetAmount
FROM STAGE_TARGET_CHANNEL stc
LEFT JOIN Dim_Channel dch
    ON dch.ChannelName = CASE
        WHEN stc.ChannelName = 'Online' THEN 'On-line'
        ELSE stc.ChannelName
    END
LEFT JOIN Dim_Store ds
    ON ds.StoreNumber = CASE
        WHEN stc.TargetName LIKE 'Store Number %'
            THEN TRY_CAST(SUBSTR(stc.TargetName, 14) AS INT)
        ELSE NULL
    END
LEFT JOIN Dim_Reseller dr
    ON dr.ResellerName = stc.TargetName
INNER JOIN DIM_DATE dd
    ON dd.YEAR = TO_NUMBER(stc.Year);

-- checking row counts
SELECT COUNT(*) FROM Fact_SRCSalesTarget;
SELECT * FROM Fact_SRCSalesTarget;