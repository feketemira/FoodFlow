
CREATE OR ALTER PROCEDURE dbo.sp_generate_reorder_alerts
    @CreatedCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Resolve open alerts where stock is no longer low
    UPDATE ra
    SET ra.Status = 'Resolved'
    FROM dbo.ReorderAlerts ra
    JOIN dbo.Ingredients i ON i.IngredientID = ra.IngredientID
    WHERE ra.Status = 'Open'
      AND i.StockQuantity > i.ReorderLevel;

    -- Create new alerts for currently low-stock ingredients
    INSERT INTO dbo.ReorderAlerts (IngredientID, CurrentStock, ReorderLevel, Status)
    SELECT
        i.IngredientID,
        i.StockQuantity,
        i.ReorderLevel,
        'Open'
    FROM dbo.Ingredients i
    WHERE i.StockQuantity <= i.ReorderLevel
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.ReorderAlerts ra
          WHERE ra.IngredientID = i.IngredientID
            AND ra.Status = 'Open'
      );

    SET @CreatedCount = @@ROWCOUNT;

    INSERT INTO dbo.OrderLog (OrderID, EventType, Message)
    VALUES (
        NULL,
        'STOCK_CHECK',
        'Stock check completed. New reorder alerts created: ' + CAST(@CreatedCount AS NVARCHAR(20))
    );
END;

CREATE OR ALTER PROCEDURE dbo.sp_cancel_order
    @OrderID INT,
    @StatusCode INT OUTPUT,
    @StatusMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CurrentStatus NVARCHAR(30);

    SET @StatusCode = 0;
    SET @StatusMessage = 'OK';

    BEGIN TRY
        BEGIN TRAN;

        SELECT @CurrentStatus = Status
        FROM dbo.Orders
        WHERE OrderID = @OrderID;

        IF @CurrentStatus IS NULL
        BEGIN
            SET @StatusCode = 1;
            SET @StatusMessage = 'Order not found.';
            ROLLBACK TRAN;
            RETURN;
        END;

        IF @CurrentStatus = 'Cancelled'
        BEGIN
            SET @StatusCode = 2;
            SET @StatusMessage = 'Order is already cancelled.';
            ROLLBACK TRAN;
            RETURN;
        END;

        IF @CurrentStatus = 'Delivered'
        BEGIN
            SET @StatusCode = 3;
            SET @StatusMessage = 'Delivered orders cannot be cancelled.';
            ROLLBACK TRAN;
            RETURN;
        END;

        -- Return ingredients to inventory
        UPDATE i
        SET i.StockQuantity = i.StockQuantity + (mii.RequiredQuantity * oi.Quantity)
        FROM dbo.Ingredients i
        JOIN dbo.MenuItemIngredients mii ON mii.IngredientID = i.IngredientID
        JOIN dbo.OrderItems oi ON oi.MenuItemID = mii.MenuItemID
        WHERE oi.OrderID = @OrderID;

        -- Change status
        UPDATE dbo.Orders
        SET Status = 'Cancelled'
        WHERE OrderID = @OrderID;

        INSERT INTO dbo.OrderLog (OrderID, EventType, OldStatus, NewStatus, Message)
        VALUES (
            @OrderID,
            'ORDER_CANCELLED',
            @CurrentStatus,
            'Cancelled',
            'Order was cancelled and ingredients were returned to inventory.'
        );

        COMMIT TRAN;

        SET @StatusCode = 0;
        SET @StatusMessage = 'Order cancelled successfully. Ingredients were returned to inventory.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        SET @StatusCode = 99;
        SET @StatusMessage = ERROR_MESSAGE();
    END CATCH
END;

CREATE OR ALTER PROCEDURE dbo.sp_add_order_item
    @OrderID INT,
    @MenuItemID INT,
    @Quantity INT,
    @StatusCode INT OUTPUT,
    @StatusMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Price DECIMAL(10,2);

    SET @StatusCode = 0;
    SET @StatusMessage = 'OK';

    SELECT @Price = Price
    FROM dbo.MenuItems
    WHERE MenuItemID = @MenuItemID
      AND IsAvailable = 1;

    IF @Price IS NULL
    BEGIN
        SET @StatusCode = 2;
        SET @StatusMessage = 'Menu item not found or not available.';
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.MenuItemIngredients mii
        JOIN dbo.Ingredients i ON i.IngredientID = mii.IngredientID
        WHERE mii.MenuItemID = @MenuItemID
          AND i.StockQuantity < mii.RequiredQuantity * @Quantity
    )
    BEGIN
        SET @StatusCode = 3;
        SET @StatusMessage = 'Not enough ingredients.';
        RETURN;
    END;

    INSERT INTO dbo.OrderItems (OrderID, MenuItemID, Quantity, UnitPrice)
    VALUES (@OrderID, @MenuItemID, @Quantity, @Price);

    UPDATE i
    SET i.StockQuantity = i.StockQuantity - (mii.RequiredQuantity * @Quantity)
    FROM dbo.Ingredients i
    JOIN dbo.MenuItemIngredients mii ON i.IngredientID = mii.IngredientID
    WHERE mii.MenuItemID = @MenuItemID;

    UPDATE dbo.Orders
    SET TotalAmount = TotalAmount + (@Price * @Quantity)
    WHERE OrderID = @OrderID;

    INSERT INTO dbo.OrderLog (OrderID, EventType, Message)
    VALUES (
        @OrderID,
        'ORDER_ITEM_ADDED',
        'Menu item ID ' + CAST(@MenuItemID AS NVARCHAR(20)) +
        ' was added with quantity ' + CAST(@Quantity AS NVARCHAR(20)) + '.'
    );

    SET @StatusCode = 0;
    SET @StatusMessage = 'Order item added successfully.';
END;

CREATE OR ALTER PROCEDURE dbo.sp_get_or_create_customer
    @Name NVARCHAR(100),
    @Email NVARCHAR(100),
    @Phone NVARCHAR(30),
    @CustomerID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @CustomerID = CustomerID
    FROM dbo.Customers
    WHERE Email = @Email;

    IF @CustomerID IS NULL
    BEGIN
        INSERT INTO dbo.Customers (Name, Email, Phone)
        VALUES (@Name, @Email, @Phone);

        SET @CustomerID = SCOPE_IDENTITY();
    END
END;

CREATE OR ALTER PROCEDURE dbo.sp_create_order_header
    @CustomerID INT,
    @OrderID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Orders (CustomerID, Status, TotalAmount)
    VALUES (@CustomerID, 'Pending', 0);

    SET @OrderID = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderLog (OrderID, EventType, NewStatus, Message)
    VALUES (@OrderID, 'ORDER_CREATED', 'Pending', 'New multi-item food order was created.');
END;
