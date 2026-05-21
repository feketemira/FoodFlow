CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    Phone NVARCHAR(30)
);

CREATE TABLE MenuItems (
    MenuItemID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Description NVARCHAR(255),
    Category NVARCHAR(50),
    Price DECIMAL(10,2) NOT NULL CHECK (Price > 0),
    IsAvailable BIT NOT NULL DEFAULT 1
);

CREATE TABLE Ingredients (
    IngredientID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Unit NVARCHAR(20) NOT NULL,
    StockQuantity DECIMAL(10,2) NOT NULL CHECK (StockQuantity >= 0),
    ReorderLevel DECIMAL(10,2) NOT NULL CHECK (ReorderLevel >= 0)
);

CREATE TABLE MenuItemIngredients (
    MenuItemID INT NOT NULL,
    IngredientID INT NOT NULL,
    RequiredQuantity DECIMAL(10,2) NOT NULL CHECK (RequiredQuantity > 0),

    PRIMARY KEY (MenuItemID, IngredientID),
    FOREIGN KEY (MenuItemID) REFERENCES MenuItems(MenuItemID),
    FOREIGN KEY (IngredientID) REFERENCES Ingredients(IngredientID)
);

CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME NOT NULL DEFAULT GETDATE(),
    Status NVARCHAR(30) NOT NULL DEFAULT 'Pending',
    TotalAmount DECIMAL(10,2) NOT NULL DEFAULT 0,

    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    CHECK (Status IN ('Pending', 'Accepted', 'Preparing', 'Ready', 'Delivered', 'Cancelled'))
);

CREATE TABLE OrderItems (
    OrderItemID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    MenuItemID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),

    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (MenuItemID) REFERENCES MenuItems(MenuItemID)
);

CREATE TABLE OrderLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NULL,
    EventType NVARCHAR(50) NOT NULL,
    OldStatus NVARCHAR(30) NULL,
    NewStatus NVARCHAR(30) NULL,
    EventTime DATETIME NOT NULL DEFAULT GETDATE(),
    Message NVARCHAR(255)
);

CREATE TABLE ReorderAlerts (
    AlertID INT IDENTITY(1,1) PRIMARY KEY,
    IngredientID INT NOT NULL,
    CurrentStock DECIMAL(10,2) NOT NULL,
    ReorderLevel DECIMAL(10,2) NOT NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    Status NVARCHAR(30) NOT NULL DEFAULT 'Open',

    FOREIGN KEY (IngredientID) REFERENCES Ingredients(IngredientID)
);