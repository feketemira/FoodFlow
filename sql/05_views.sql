CREATE OR ALTER VIEW dbo.vw_best_selling_items AS
SELECT
    mi.MenuItemID,
    mi.Name AS MenuItemName,
    SUM(oi.Quantity) AS TotalQuantitySold,
    SUM(oi.Quantity * oi.UnitPrice) AS TotalRevenue
FROM dbo.OrderItems oi
JOIN dbo.MenuItems mi ON mi.MenuItemID = oi.MenuItemID
JOIN dbo.Orders o ON o.OrderID = oi.OrderID
WHERE o.Status <> 'Cancelled'
GROUP BY
    mi.MenuItemID,
    mi.Name;
GO

CREATE OR ALTER VIEW dbo.vw_order_status_summary AS
SELECT
    Status,
    COUNT(*) AS OrderCount
FROM dbo.Orders
GROUP BY Status;
GO

CREATE OR ALTER VIEW dbo.vw_admin_orders AS
SELECT
    o.OrderID,
    c.Name AS CustomerName,
    o.OrderDate,
    o.Status,
    o.TotalAmount,
    ISNULL(
        STRING_AGG(mi.Name + ' x' + CAST(oi.Quantity AS NVARCHAR(10)), ', '),
        'No items'
    ) AS Items
FROM dbo.Orders o
JOIN dbo.Customers c ON c.CustomerID = o.CustomerID
LEFT JOIN dbo.OrderItems oi ON oi.OrderID = o.OrderID
LEFT JOIN dbo.MenuItems mi ON mi.MenuItemID = oi.MenuItemID
GROUP BY
    o.OrderID,
    c.Name,
    o.OrderDate,
    o.Status,
    o.TotalAmount;
GO

CREATE OR ALTER VIEW dbo.vw_order_details AS
SELECT
    o.OrderID,
    c.Name AS CustomerName,
    o.OrderDate,
    o.Status,
    mi.Name AS MenuItemName,
    oi.Quantity,
    oi.UnitPrice,
    oi.Quantity * oi.UnitPrice AS LineTotal,
    o.TotalAmount
FROM dbo.Orders o
JOIN dbo.Customers c ON c.CustomerID = o.CustomerID
JOIN dbo.OrderItems oi ON oi.OrderID = o.OrderID
JOIN dbo.MenuItems mi ON mi.MenuItemID = oi.MenuItemID;
GO

CREATE OR ALTER VIEW dbo.vw_active_orders AS
SELECT
    o.OrderID,
    c.Name AS CustomerName,
    o.OrderDate,
    o.Status,
    o.TotalAmount
FROM dbo.Orders o
JOIN dbo.Customers c ON c.CustomerID = o.CustomerID
WHERE o.Status NOT IN ('Delivered', 'Cancelled');
GO

CREATE OR ALTER VIEW dbo.vw_low_stock_ingredients AS
SELECT
    IngredientID,
    Name,
    Unit,
    StockQuantity,
    ReorderLevel
FROM dbo.Ingredients
WHERE StockQuantity <= ReorderLevel;
GO

CREATE OR ALTER VIEW dbo.vw_daily_dashboard AS
SELECT
    CAST(GETDATE() AS DATE) AS ReportDate,
    COUNT(*) AS TodayOrders,
    ISNULL(SUM(TotalAmount), 0) AS TodayRevenue
FROM dbo.Orders
WHERE CAST(OrderDate AS DATE) = CAST(GETDATE() AS DATE)
  AND Status <> 'Cancelled';
GO