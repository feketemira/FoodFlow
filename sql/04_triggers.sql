CREATE OR ALTER TRIGGER tr_order_status_log
ON Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO OrderLog (OrderID, EventType, OldStatus, NewStatus, Message)
    SELECT
        i.OrderID,
        'STATUS_CHANGED',
        d.Status,
        i.Status,
        'Order status changed from ' + d.Status + ' to ' + i.Status
    FROM inserted i
    JOIN deleted d ON i.OrderID = d.OrderID
    WHERE ISNULL(i.Status, '') <> ISNULL(d.Status, '');
END;