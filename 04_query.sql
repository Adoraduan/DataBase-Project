/* ============================================================
   04_query.sql —— 多表查询与统计查询
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   前提：已执行 01_create_database.sql 与 02_insert_sample_data.sql
        （执行过 03_crud.sql 也可，数据仍完整）。

   结构：
     Part A  连接查询：多表 INNER JOIN / LEFT JOIN / 自连接
     Part B  统计查询：聚合函数 + GROUP BY + HAVING + 子查询

   每段前的注释说明该查询回答的业务问题。
   ============================================================ */

USE CampusCoffee;
GO

/* ============================================================
   Part A  连接查询
   ============================================================ */

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

/* ============================================================
   Part B  统计查询（聚合 / GROUP BY / HAVING / 子查询）
   ============================================================ */

-- 11. 各商品销量与销售额（聚合 + GROUP BY，排除已取消订单）
SELECT oi.product_name AS [商品],
       SUM(oi.quantity) AS [销量],
       SUM(oi.subtotal) AS [销售额]
FROM dbo.order_items oi
JOIN dbo.orders o ON oi.order_id = o.order_id
WHERE o.status <> N'已取消'
GROUP BY oi.product_name
ORDER BY [销售额] DESC;
GO

-- 12. 各门店经营概况（只统计已成交的订单状态）
SELECT s.store_name AS [门店],
       COUNT(DISTINCT o.order_id) AS [订单数],
       SUM(o.total_amount) AS [销售额]
FROM dbo.orders o
JOIN dbo.stores s ON o.store_id = s.store_id
WHERE o.status IN (N'已支付', N'制作中', N'待取餐', N'已完成')
GROUP BY s.store_name;
GO

-- 13. 消费 2 单及以上的顾客（HAVING：对分组结果筛选，而非对单行筛选）
SELECT u.username AS [顾客],
       COUNT(o.order_id) AS [订单数],
       SUM(o.total_amount) AS [累计消费]
FROM dbo.users u
JOIN dbo.orders o ON u.user_id = o.user_id
WHERE o.status <> N'已取消'
GROUP BY u.username
HAVING COUNT(o.order_id) >= 2;
GO

-- 14. 从未下过单的注册用户（NOT EXISTS 相关子查询）
SELECT u.user_id, u.username, u.created_at
FROM dbo.users u
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.orders o WHERE o.user_id = u.user_id
);
GO

-- 15. 客单价高于全站平均客单价的订单（标量子查询）
SELECT o.order_no, u.username, o.total_amount
FROM dbo.orders o
JOIN dbo.users u ON o.user_id = u.user_id
WHERE o.status <> N'已取消'
  AND o.total_amount > (
      SELECT AVG(total_amount) FROM dbo.orders WHERE status <> N'已取消'
  )
ORDER BY o.total_amount DESC;
GO

-- 16. 每个门店库存最少的那个 SKU（相关子查询，逐门店比较）
SELECT s.store_name AS [门店], p.product_name AS [商品], k.sku_name AS [规格], i.quantity AS [库存]
FROM dbo.inventory i
JOIN dbo.skus     k ON i.sku_id    = k.sku_id
JOIN dbo.products p ON k.product_id = p.product_id
JOIN dbo.stores   s ON i.store_id  = s.store_id
WHERE i.quantity = (
    SELECT MIN(i2.quantity)
    FROM dbo.inventory i2
    WHERE i2.store_id = i.store_id
)
ORDER BY s.store_name;
GO
