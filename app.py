from flask import Flask, render_template, request, redirect, url_for, flash
import pyodbc
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.secret_key = "dev-secret"


def get_conn():
    server = os.getenv("DB_SERVER")
    database = os.getenv("DB_NAME")
    driver = os.getenv("DB_DRIVER")

    conn_str = (
        f"DRIVER={{{driver}}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"Trusted_Connection=yes;"
        f"TrustServerCertificate=yes;"
    )

    return pyodbc.connect(conn_str)


@app.route("/")
def menu():
    conn = get_conn()
    cursor = conn.cursor()

    menu_items = cursor.execute("""
        SELECT 
            MenuItemID, 
            Name, 
            Description, 
            Category, 
            CAST(ROUND(Price, 0) AS INT) AS Price
        FROM dbo.MenuItems
        WHERE IsAvailable = 1
        ORDER BY Category, Name
    """).fetchall()

    conn.close()

    return render_template(
        "menu.html",
        menu_items=menu_items
    )

@app.route("/order", methods=["POST"])
def place_order():
    customer_name = request.form["customer_name"]
    customer_email = request.form["customer_email"]
    customer_phone = request.form["customer_phone"]

    selected_items = []

    for key, value in request.form.items():
        if key.startswith("qty_"):
            menu_item_id = int(key.replace("qty_", ""))
            quantity = int(value or 0)

            if quantity > 0:
                selected_items.append((menu_item_id, quantity))

    if not selected_items:
        flash("Please select at least one menu item.", "danger")
        return redirect(url_for("menu"))

    conn = get_conn()
    cursor = conn.cursor()

    try:
        cursor.execute("BEGIN TRANSACTION;")

        cursor.execute("""
            DECLARE @CustomerID INT;

            EXEC dbo.sp_get_or_create_customer
                @Name = ?,
                @Email = ?,
                @Phone = ?,
                @CustomerID = @CustomerID OUTPUT;

            SELECT @CustomerID AS CustomerID;
        """, customer_name, customer_email, customer_phone)

        customer_id = cursor.fetchone().CustomerID

        cursor.execute("""
            DECLARE @OrderID INT;

            EXEC dbo.sp_create_order_header
                @CustomerID = ?,
                @OrderID = @OrderID OUTPUT;

            SELECT @OrderID AS OrderID;
        """, customer_id)

        order_id = cursor.fetchone().OrderID

        for menu_item_id, quantity in selected_items:
            cursor.execute("""
                DECLARE @StatusCode INT, @StatusMessage NVARCHAR(255);

                EXEC dbo.sp_add_order_item
                    @OrderID = ?,
                    @MenuItemID = ?,
                    @Quantity = ?,
                    @StatusCode = @StatusCode OUTPUT,
                    @StatusMessage = @StatusMessage OUTPUT;

                SELECT @StatusCode AS StatusCode, @StatusMessage AS StatusMessage;
            """, order_id, menu_item_id, quantity)

            row = cursor.fetchone()

            if row.StatusCode != 0:
                cursor.execute("ROLLBACK TRANSACTION;")
                conn.rollback()
                conn.close()
                flash(row.StatusMessage, "danger")
                return redirect(url_for("menu"))

        cursor.execute("COMMIT TRANSACTION;")
        conn.commit()
        conn.close()

        flash(f"Order created successfully. Order ID: {order_id}", "success")
        return redirect(url_for("menu"))

    except Exception as e:
        try:
            cursor.execute("ROLLBACK TRANSACTION;")
        except:
            pass

        try:
            conn.rollback()
        except:
            pass

        conn.close()
        flash(f"Order failed: {str(e)}", "danger")
        return redirect(url_for("menu"))

@app.route("/admin/orders")
def admin_orders():
    conn = get_conn()
    cursor = conn.cursor()

    orders = cursor.execute("""
        SELECT 
            OrderID, 
            CustomerName, 
        CONVERT(VARCHAR(16), OrderDate, 120) AS OrderDate,
            Status, 
            CAST(ROUND(TotalAmount, 0) AS INT) AS TotalAmount,
            Items
        FROM dbo.vw_admin_orders
        ORDER BY OrderDate DESC
    """).fetchall()

    conn.close()

    return render_template("admin_orders.html", orders=orders)

@app.route("/admin/orders/<int:order_id>/status", methods=["POST"])
def update_order_status(order_id):
    new_status = request.form["status"]

    conn = get_conn()
    cursor = conn.cursor()

    if new_status == "Cancelled":
        try:
            cursor.execute("BEGIN TRANSACTION;")

            cursor.execute("""
                DECLARE @StatusCode INT, @StatusMessage NVARCHAR(255);

                EXEC dbo.sp_cancel_order
                    @OrderID = ?,
                    @StatusCode = @StatusCode OUTPUT,
                    @StatusMessage = @StatusMessage OUTPUT;

                SELECT @StatusCode AS StatusCode, @StatusMessage AS StatusMessage;
            """, order_id)

            row = cursor.fetchone()

            if row.StatusCode != 0:
                cursor.execute("ROLLBACK TRANSACTION;")
                conn.rollback()
                conn.close()
                flash(row.StatusMessage, "danger")
                return redirect(url_for("admin_orders"))

            cursor.execute("""
                DECLARE @CreatedCount INT;

                EXEC dbo.sp_generate_reorder_alerts
                    @CreatedCount = @CreatedCount OUTPUT;

                SELECT @CreatedCount AS CreatedCount;
            """)
            cursor.fetchone()

            cursor.execute("COMMIT TRANSACTION;")
            conn.commit()
            conn.close()

            flash(row.StatusMessage, "success")
            return redirect(url_for("admin_orders"))

        except Exception as e:
            try:
                cursor.execute("ROLLBACK TRANSACTION;")
            except:
                pass

            try:
                conn.rollback()
            except:
                pass

            conn.close()
            flash(f"Order cancellation failed: {str(e)}", "danger")
            return redirect(url_for("admin_orders"))

    cursor.execute("""
        UPDATE dbo.Orders
        SET Status = ?
        WHERE OrderID = ?
    """, new_status, order_id)

    conn.commit()
    conn.close()

    flash("Order status updated successfully.", "success")

    return redirect(url_for("admin_orders"))

@app.route("/admin/dashboard")
def dashboard():
    conn = get_conn()
    cursor = conn.cursor()

    daily = cursor.execute("""
        SELECT 
            CONVERT(VARCHAR(10), ReportDate, 120) AS ReportDate,
            CAST(TodayOrders AS INT) AS TodayOrders,
            CAST(ROUND(TodayRevenue, 0) AS INT) AS TodayRevenue
        FROM dbo.vw_daily_dashboard
    """).fetchone()

    low_stock = cursor.execute("""
        SELECT 
            Name, 
            Unit, 
            CAST(ROUND(StockQuantity, 2) AS FLOAT) AS StockQuantity,
            CAST(ROUND(ReorderLevel, 2) AS FLOAT) AS ReorderLevel
        FROM dbo.vw_low_stock_ingredients
        ORDER BY Name
    """).fetchall()

    best_selling = cursor.execute("""
        SELECT TOP 5
            MenuItemName,
            CAST(TotalQuantitySold AS INT) AS TotalQuantitySold,
            CAST(ROUND(TotalRevenue, 0) AS INT) AS TotalRevenue
        FROM dbo.vw_best_selling_items
        ORDER BY TotalQuantitySold DESC
    """).fetchall()

    status_summary = cursor.execute("""
        SELECT Status, OrderCount
        FROM dbo.vw_order_status_summary
        ORDER BY Status
    """).fetchall()

    reorder_alerts = cursor.execute("""
        SELECT
            ra.AlertID,
            i.Name AS IngredientName,
            CAST(ROUND(ra.CurrentStock, 2) AS FLOAT) AS CurrentStock,
            CAST(ROUND(ra.ReorderLevel, 2) AS FLOAT) AS ReorderLevel,
            CONVERT(VARCHAR(16), ra.CreatedAt, 120) AS CreatedAt,
            ra.Status
        FROM dbo.ReorderAlerts ra
        JOIN dbo.Ingredients i ON i.IngredientID = ra.IngredientID
        ORDER BY
            CASE WHEN ra.Status = 'Open' THEN 0 ELSE 1 END,
            ra.CreatedAt DESC
    """).fetchall()

    conn.close()

    return render_template(
        "dashboard.html",
        daily=daily,
        low_stock=low_stock,
        best_selling=best_selling,
        status_summary=status_summary,
        reorder_alerts=reorder_alerts
    )

@app.route("/admin/stock-check", methods=["POST"])
def stock_check():
    conn = get_conn()
    cursor = conn.cursor()

    cursor.execute("""
        DECLARE @CreatedCount INT;

        EXEC dbo.sp_generate_reorder_alerts
            @CreatedCount = @CreatedCount OUTPUT;

        SELECT @CreatedCount AS CreatedCount;
    """)

    row = cursor.fetchone()
    conn.commit()
    conn.close()

    flash(f"Stock check completed. New reorder alerts created: {row.CreatedCount}", "success")
    return redirect(url_for("dashboard"))


@app.route("/admin/logs")
def logs():
    conn = get_conn()
    cursor = conn.cursor()

    logs = cursor.execute("""
        SELECT TOP 100
            LogID,
            OrderID,
            EventType,
            OldStatus,
            NewStatus,
            CONVERT(VARCHAR(16), EventTime, 120) AS EventTime,
            Message
        FROM dbo.OrderLog
        ORDER BY EventTime DESC
    """).fetchall()

    conn.close()

    return render_template("logs.html", logs=logs)

@app.route("/admin/reorder-alerts/<int:alert_id>/resolve", methods=["POST"])
def resolve_reorder_alert(alert_id):
    restock_quantity = float(request.form["restock_quantity"])

    conn = get_conn()
    cursor = conn.cursor()

    cursor.execute("""
        DECLARE @StatusCode INT, @StatusMessage NVARCHAR(255);

        EXEC dbo.sp_resolve_reorder_alert
            @AlertID = ?,
            @RestockQuantity = ?,
            @StatusCode = @StatusCode OUTPUT,
            @StatusMessage = @StatusMessage OUTPUT;

        SELECT @StatusCode AS StatusCode, @StatusMessage AS StatusMessage;
    """, alert_id, restock_quantity)

    row = cursor.fetchone()
    conn.commit()
    conn.close()

    if row.StatusCode == 0:
        flash(row.StatusMessage, "success")
    else:
        flash(row.StatusMessage, "danger")

    return redirect(url_for("dashboard"))


if __name__ == "__main__":
    app.run(debug=True)