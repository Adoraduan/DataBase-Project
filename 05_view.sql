/* ============================================================
   05_view.sql —— 统计视图
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   前提：已执行 01_create_database.sql 与 02_insert_sample_data.sql。
   本文件创建 7 个统计视图，并在末尾逐个查询验证（7 个都要出结果）。

   说明：CREATE OR ALTER VIEW 需 SQL Server 2016+；
        更早版本请改为「DROP VIEW IF EXISTS dbo.v_x;」后接 CREATE VIEW。
   ============================================================ */

USE CampusCoffee;
GO

-- 1. 订单明细视图（订单+顾客+门店+明细快照）
CREATE OR ALTER VIEW dbo.v_order_detail AS
SELECT o.order_id, o.order_no, u.username, s.store_name, o.status, o.total_amount,
       oi.product_name, oi.sku_name, oi.unit_price, oi.quantity, oi.subtotal
FROM dbo.orders o
JOIN dbo.users  u ON o.user_id  = u.user_id
JOIN dbo.stores s ON o.store_id = s.store_id
JOIN dbo.order_items oi ON o.order_id = oi.order_id;
GO

-- 2. 每商品销量/销售额统计
CREATE OR ALTER VIEW dbo.v_sales_by_product AS
SELECT oi.product_name AS [商品], SUM(oi.quantity) AS [销量], SUM(oi.subtotal) AS [销售额]
FROM dbo.order_items oi
JOIN dbo.orders o ON oi.order_id = o.order_id
WHERE o.status <> N'已取消'
GROUP BY oi.product_name;
GO

-- 3. 每门店订单数与销售额统计
CREATE OR ALTER VIEW dbo.v_sales_by_store AS
SELECT s.store_name AS [门店], COUNT(DISTINCT o.order_id) AS [订单数], SUM(o.total_amount) AS [销售额]
FROM dbo.orders o
JOIN dbo.stores s ON o.store_id = s.store_id
WHERE o.status IN (N'已支付', N'制作中', N'待取餐', N'已完成')
GROUP BY s.store_name;
GO

-- 4. 用户积分汇总（余额 + 累计获得 + 流水笔数）
CREATE OR ALTER VIEW dbo.v_user_points AS
SELECT u.user_id, u.username, u.points_balance AS [积分余额],
       ISNULL(SUM(CASE WHEN pt.points_change > 0 THEN pt.points_change ELSE 0 END), 0) AS [累计获得],
       COUNT(pt.transaction_id) AS [流水笔数]
FROM dbo.users u
LEFT JOIN dbo.point_transactions pt ON u.user_id = pt.user_id
GROUP BY u.user_id, u.username, u.points_balance;
GO

-- 5. 库存状态视图（门店 + 商品 + SKU + 数量 + 库存状态）
CREATE OR ALTER VIEW dbo.v_inventory_status AS
SELECT s.store_name AS [门店], p.product_name AS [商品], k.sku_name AS [规格], i.quantity AS [数量],
       CASE WHEN i.quantity = 0 THEN N'缺货' WHEN i.quantity < 10 THEN N'低库存' ELSE N'充足' END AS [库存状态]
FROM dbo.inventory i
JOIN dbo.skus     k ON i.sku_id    = k.sku_id
JOIN dbo.products p ON k.product_id = p.product_id
JOIN dbo.stores   s ON i.store_id  = s.store_id;
GO

-- 6. 每顾客消费统计（下单数 + 累计消费）
CREATE OR ALTER VIEW dbo.v_customer_spend AS
SELECT u.user_id, u.username, COUNT(o.order_id) AS [下单数], ISNULL(SUM(o.total_amount), 0) AS [累计消费]
FROM dbo.users u
LEFT JOIN dbo.orders o ON u.user_id = o.user_id AND o.status <> N'已取消'
GROUP BY u.user_id, u.username;
GO

-- 7. 按日销售统计
CREATE OR ALTER VIEW dbo.v_daily_sales AS
SELECT CONVERT(DATE, o.created_at) AS [日期], COUNT(o.order_id) AS [订单数], SUM(o.total_amount) AS [销售额]
FROM dbo.orders o
WHERE o.status <> N'已取消'
GROUP BY CONVERT(DATE, o.created_at);
GO

/* ============================================================
   逐个查询验证：7 个视图都应有结果（截图留证）
   ============================================================ */

-- 1. 订单明细（每笔订单展开成明细行）
SELECT * FROM dbo.v_order_detail;
GO

-- 2. 商品销量/销售额
SELECT * FROM dbo.v_sales_by_product;
GO

-- 3. 门店订单数与销售额
SELECT * FROM dbo.v_sales_by_store;
GO

-- 4. 用户积分汇总（余额 / 累计获得 / 流水笔数）
SELECT * FROM dbo.v_user_points;
GO

-- 5. 库存状态（缺货 / 低库存 / 充足）
SELECT * FROM dbo.v_inventory_status;
GO

-- 6. 每顾客消费统计
SELECT * FROM dbo.v_customer_spend;
GO

-- 7. 按日销售统计
SELECT * FROM dbo.v_daily_sales;
GO
