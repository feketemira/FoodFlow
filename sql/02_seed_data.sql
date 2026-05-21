USE FoodFlowDB;
GO

-- Reset data in correct dependency order
DELETE FROM dbo.MenuItemIngredients;
DELETE FROM dbo.OrderLog;
DELETE FROM dbo.OrderItems;
DELETE FROM dbo.Orders;
DELETE FROM dbo.ReorderAlerts;
DELETE FROM dbo.Ingredients;
DELETE FROM dbo.MenuItems;
DELETE FROM dbo.Customers;
GO

-- Reset identity columns
DBCC CHECKIDENT ('dbo.Customers', RESEED, 0);
DBCC CHECKIDENT ('dbo.MenuItems', RESEED, 0);
DBCC CHECKIDENT ('dbo.Ingredients', RESEED, 0);
DBCC CHECKIDENT ('dbo.Orders', RESEED, 0);
DBCC CHECKIDENT ('dbo.OrderItems', RESEED, 0);
DBCC CHECKIDENT ('dbo.OrderLog', RESEED, 0);
DBCC CHECKIDENT ('dbo.ReorderAlerts', RESEED, 0);
GO

INSERT INTO dbo.MenuItems (Name, Description, Category, Price) VALUES
('Margherita Pizza', 'Pizza with tomato sauce and mozzarella cheese', 'Pizza', 2490),
('Pepperoni Pizza', 'Pizza with tomato sauce, mozzarella cheese and pepperoni', 'Pizza', 2890),
('Chicken Burger', 'Chicken burger served with French fries', 'Burger', 2990),
('Beef Burger', 'Beef burger with cheddar cheese and lettuce', 'Burger', 3290),
('Caesar Salad', 'Fresh salad with grilled chicken and Caesar dressing', 'Salad', 2190),
('Greek Salad', 'Fresh salad with feta cheese, cucumber, tomato and olives', 'Salad', 1990),
('Pasta Carbonara', 'Pasta with creamy sauce, bacon and cheese', 'Pasta', 2690),
('Pasta Bolognese', 'Pasta with tomato-based beef sauce', 'Pasta', 2790),
('Chicken Wrap', 'Tortilla wrap with grilled chicken, lettuce and sauce', 'Wrap', 2390),
('Tomato Soup', 'Classic tomato soup with herbs', 'Soup', 1490);
GO

INSERT INTO dbo.Ingredients (Name, Unit, StockQuantity, ReorderLevel) VALUES
('Flour', 'kg', 25, 5),
('Mozzarella Cheese', 'kg', 10, 2),
('Tomato Sauce', 'liter', 12, 2),
('Chicken Breast', 'kg', 14, 3),
('Burger Bun', 'pcs', 40, 10),
('Lettuce', 'kg', 6, 1),
('Pasta', 'kg', 12, 2),
('Bacon', 'kg', 6, 2),
('Cream', 'liter', 8, 2),
('Pepperoni', 'kg', 5, 1),
('Beef Patty', 'pcs', 30, 8),
('Cheddar Cheese', 'kg', 5, 1),
('Feta Cheese', 'kg', 4, 1),
('Cucumber', 'kg', 5, 1),
('Tomato', 'kg', 10, 2),
('Olives', 'kg', 3, 1),
('Minced Beef', 'kg', 8, 2),
('Tortilla Wrap', 'pcs', 30, 8),
('Garlic Sauce', 'liter', 5, 1),
('Soup Herbs', 'kg', 2, 0.5);
GO

-- 1. Margherita Pizza
INSERT INTO dbo.MenuItemIngredients (MenuItemID, IngredientID, RequiredQuantity) VALUES
(1, 1, 0.25),
(1, 2, 0.15),
(1, 3, 0.10);

-- 2. Pepperoni Pizza
INSERT INTO dbo.MenuItemIngredients (MenuItemID, IngredientID, RequiredQuantity) VALUES
(2, 1, 0.25),
(2, 2, 0.15),
(2, 3, 0.10),
(2, 10, 0.08);

-- 3. Chicken Burger
INSERT INTO dbo.MenuItemIngredients (MenuItemID, IngredientID, RequiredQuantity) VALUES
(3, 4, 0.20),
(3, 5, 1),
(3, 6, 0.05);

-- 4. Beef Burger
INSERT INTO dbo.MenuItemIngredients (MenuItemID, IngredientID, RequiredQuantity) VALUES
(4, 11, 1),
(4, 5, 1),
(4, 12, 0.05),
(4, 6, 0.05);

-- 5. Caesar Salad
INSERT INTO dbo.MenuItemIngredients (MenuItemID, IngredientID, RequiredQuantity) VALUES
(5, 4, 0.15),
(5, 6, 0.10);

-- 6. Greek Salad
INSERT INTO dbo.MenuItemIngredients (MenuItemID, IngredientID, RequiredQuantity) VALUES
(6, 13, 0.08),
(6, 14, 0.10),
(6, 15, 0.10),
(6, 16, 0.05);

-- 7. Pasta Carbonara
INSERT INTO dbo.MenuItemIngredients (MenuItemID, IngredientID, RequiredQuantity) VALUES
(7, 7, 0.20),
(7, 8, 0.08),
(7, 9, 0.10),
(7, 2, 0.05);

-- 8. Pasta Bolognese
INSERT INTO dbo.MenuItemIngredients (MenuItemID, IngredientID, RequiredQuantity) VALUES
(8, 7, 0.20),
(8, 17, 0.15),
(8, 3, 0.12);

-- 9. Chicken Wrap
INSERT INTO dbo.MenuItemIngredients (MenuItemID, IngredientID, RequiredQuantity) VALUES
(9, 18, 1),
(9, 4, 0.18),
(9, 6, 0.05),
(9, 19, 0.05);

-- 10. Tomato Soup
INSERT INTO dbo.MenuItemIngredients (MenuItemID, IngredientID, RequiredQuantity) VALUES
(10, 3, 0.25),
(10, 15, 0.15),
(10, 20, 0.02);
GO