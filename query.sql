/* ============================================================
   query.sql —— week4 多表查询（连接查询）
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   说明：以下查询基于 ddl.sql + dml.sql 建立的数据。
        每段前注释说明该查询回答的业务问题。
   ============================================================ */

USE CampusCoffee;
GO

-- 1. 订单总览：订单号 + 顾客 + 门店 + 状态 + 金额
SELECT o.order_no, u.username, s.store_name, o.status, o.total_amount, o.created_at
FROM dbo.orders o
JOIN dbo.users  u ON o.user_id  = u.user_id
JOIN dbo.stores s ON o.store_id = s.store_id
ORDER BY o.created_at DESC;
GO

-- 2. 某订单明细：商品、规格、单价、数量、小计、分类（订单+明细+SKU+商品+分类）
SELECT oi.order_id, p.product_name, oi.sku_name, oi.unit_price, oi.quantity, oi.subtotal, c.category_name
FROM dbo.order_items oi
JOIN dbo.skus       k ON oi.sku_id    = k.sku_id
JOIN dbo.products   p ON k.product_id = p.product_id
JOIN dbo.categories c ON p.category_id = c.category_id
WHERE oi.order_id = 1;
GO

-- 3. 低库存商品：门店 + 商品 + SKU + 数量（库存 < 10）
SELECT s.store_name, p.product_name, k.sku_name, i.quantity
FROM dbo.inventory i
JOIN dbo.skus     k ON i.sku_id    = k.sku_id
JOIN dbo.products p ON k.product_id = p.product_id
JOIN dbo.stores   s ON i.store_id  = s.store_id
WHERE i.quantity < 10
ORDER BY i.quantity;
GO

-- 4. 员工信息：姓名、职位、门店、登录账号（员工+门店+用户，账号左连接）
SELECT e.name, e.position, s.store_name, u.username
FROM dbo.employees e
JOIN dbo.stores   s ON e.store_id = s.store_id
LEFT JOIN dbo.users u ON e.user_id = u.user_id;
GO

-- 5. 评价：评分、内容、顾客、订单号（评价+订单+用户）
SELECT r.rating, r.content, u.username, o.order_no
FROM dbo.reviews r
JOIN dbo.orders o ON r.order_id = o.order_id
JOIN dbo.users  u ON r.user_id  = u.user_id;
GO

-- 6. 积分流水：用户、变动类型、分值、余额（流水+用户）
SELECT u.username, pt.change_type, pt.points_change, pt.balance_after, pt.created_at
FROM dbo.point_transactions pt
JOIN dbo.users u ON pt.user_id = u.user_id
WHERE u.user_id = 1
ORDER BY pt.created_at;
GO

-- 7. 优惠券领取情况：用户、券名、状态、领取时间（领取+券+用户）
SELECT u.username, c.coupon_name, cc.status, cc.claimed_at
FROM dbo.coupon_claims cc
JOIN dbo.coupons c ON cc.coupon_id = c.coupon_id
JOIN dbo.users   u ON cc.user_id   = u.user_id;
GO

-- 8. 取餐码核销情况：取餐码、状态、订单号、核销店员、核销时间（取餐码+订单+员工）
SELECT pc.pickup_code, pc.status, o.order_no, e.name AS [核销店员], pc.verified_at
FROM dbo.pickup_codes pc
JOIN dbo.orders      o  ON pc.order_id = o.order_id
LEFT JOIN dbo.employees e ON pc.verify_employee_id = e.employee_id;
GO

-- 9. 分类层级（自连接）：子分类 -> 父分类
SELECT c1.category_name AS [子分类], c2.category_name AS [父分类]
FROM dbo.categories c1
LEFT JOIN dbo.categories c2 ON c1.parent_id = c2.category_id;
GO

-- 10. 用户-角色-权限链路（五表连接）
SELECT u.username, r.role_name, p.permission_name
FROM dbo.users            u
JOIN dbo.user_roles       ur ON u.user_id  = ur.user_id
JOIN dbo.roles            r  ON ur.role_id = r.role_id
JOIN dbo.role_permissions rp ON r.role_id  = rp.role_id
JOIN dbo.permissions      p  ON rp.permission_id = p.permission_id;
GO
