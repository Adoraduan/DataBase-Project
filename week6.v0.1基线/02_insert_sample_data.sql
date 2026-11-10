/* ============================================================
   02_insert_sample_data.sql —— 样例数据（唯一数据源）
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   作用：把数据库重置为「确定的初始状态」。
        顶部先按外键逆序清空全部表，再插入样例数据。

   为什么这样设计：
     - 清空 + 装载绑定在同一文件，跑一遍就回到同一个起点，
       因此本文件可反复执行（幂等），是 query/view 等脚本的可信基线。
     - 用显式主码 + IDENTITY_INSERT，保证每次重建后主码完全一致。

   执行顺序：01_create_database.sql → 本文件 → 04_query.sql → 05_view.sql
             → 06_constraint.sql → 07_role.sql
             （03_crud.sql 是增删改演示，跑完它之后重跑本文件即可回到基线）

   注意（AI 使用边界）：本脚本由 AI 生成候选 SQL，必须由你在 SQL Server
             中亲自执行并核对结果，不能以 AI 结果替代人工测试。
   ============================================================ */

USE CampusCoffee;
GO

/* ============================================================
   Part 0  清空数据（按外键依赖逆序，保证可重复执行）
   ============================================================ */
DELETE FROM dbo.operation_logs;
DELETE FROM dbo.point_transactions;
DELETE FROM dbo.reviews;
DELETE FROM dbo.coupon_claims;
DELETE FROM dbo.payments;
DELETE FROM dbo.pickup_codes;
DELETE FROM dbo.order_items;
DELETE FROM dbo.inventory;
DELETE FROM dbo.orders;
DELETE FROM dbo.skus;
DELETE FROM dbo.products;
DELETE FROM dbo.categories WHERE parent_id IS NOT NULL; -- 先删子分类
DELETE FROM dbo.categories;                              -- 再删根分类
DELETE FROM dbo.employees;
DELETE FROM dbo.user_roles;
DELETE FROM dbo.role_permissions;
DELETE FROM dbo.coupons;
DELETE FROM dbo.stores;
DELETE FROM dbo.permissions;
DELETE FROM dbo.roles;
DELETE FROM dbo.users;
GO

/* ============================================================
   Part 1  装载样例数据
   ============================================================ */

-- ---------- 账号与权限（RBAC） ----------

-- 角色
SET IDENTITY_INSERT dbo.roles ON;
INSERT INTO dbo.roles (role_id, role_name, description) VALUES
(1, N'顾客',       N'注册用户，下单取餐评价'),
(2, N'店员',       N'接单制作核销'),
(3, N'店长',       N'管理商品库存优惠审批退款'),
(4, N'系统管理员', N'管账号角色权限与配置');
SET IDENTITY_INSERT dbo.roles OFF;
GO

-- 权限
SET IDENTITY_INSERT dbo.permissions ON;
INSERT INTO dbo.permissions (permission_id, permission_name, description) VALUES
(1, 'order:create',  N'下单'),
(2, 'order:verify',  N'核销取餐'),
(3, 'product:edit',  N'维护商品'),
(4, 'coupon:manage', N'管理优惠券');
SET IDENTITY_INSERT dbo.permissions OFF;
GO

-- 角色-权限
INSERT INTO dbo.role_permissions (role_id, permission_id) VALUES
(1, 1),   -- 顾客：下单
(2, 2),   -- 店员：核销
(3, 3),   -- 店长：维护商品
(3, 4);   -- 店长：管理优惠券
GO

-- 用户（会员 = 已注册顾客；points_balance 与积分流水末笔余额一致）
SET IDENTITY_INSERT dbo.users ON;
INSERT INTO dbo.users (user_id, username, phone, email, password_hash, status, points_balance, created_at) VALUES
(1, N'alice', '13800000001', 'alice@stu.edu.cn', N'hash_alice', N'正常', 120, '2026-09-01 09:00:00'),
(2, N'bob',   '13800000002', 'bob@stu.edu.cn',   N'hash_bob',   N'正常',  17, '2026-09-01 09:00:00'),
(3, N'carol', '13800000003', 'carol@stu.edu.cn', N'hash_carol', N'正常',   0, '2026-09-01 09:00:00'),
(4, N'admin', '13800000004', 'admin@coffee.cn',  N'hash_admin', N'正常',   0, '2026-09-01 09:00:00');
SET IDENTITY_INSERT dbo.users OFF;
GO

-- 用户-角色
INSERT INTO dbo.user_roles (user_id, role_id) VALUES
(1, 1),   -- alice：顾客
(2, 2),   -- bob：店员
(3, 3),   -- carol：店长
(4, 4);   -- admin：系统管理员
GO

-- ---------- 组织（门店 / 员工） ----------

-- 门店
SET IDENTITY_INSERT dbo.stores ON;
INSERT INTO dbo.stores (store_id, store_name, address, phone, status) VALUES
(1, N'图书馆店', N'图书馆一楼',   '13800000100', N'营业'),
(2, N'宿舍区店', N'宿舍区三号楼', '13800000200', N'营业');
SET IDENTITY_INSERT dbo.stores OFF;
GO

-- 员工（user_id 可空：没发工号账号的店员也能建档）
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, user_id, store_id, name, position, hire_date) VALUES
(1, 3,    1, N'张伟', N'店长', '2025-09-01'),
(2, 2,    1, N'李娜', N'店员', '2026-03-01'),
(3, NULL, 2, N'王强', N'店员', '2026-06-01');
SET IDENTITY_INSERT dbo.employees OFF;
GO

-- ---------- 商品与库存 ----------

-- 商品分类（parent_id 自引用，支持层级）
SET IDENTITY_INSERT dbo.categories ON;
INSERT INTO dbo.categories (category_id, parent_id, category_name, sort_order) VALUES
(1, NULL, N'咖啡',     1),
(2, NULL, N'甜点',     2),
(3, 1,    N'拿铁系列', 1);
SET IDENTITY_INSERT dbo.categories OFF;
GO

-- 商品
SET IDENTITY_INSERT dbo.products ON;
INSERT INTO dbo.products (product_id, category_id, product_name, description, image_url, status, created_at) VALUES
(1, 3, N'拿铁咖啡', N'经典意式拿铁', N'https://img/latte.jpg',     N'上架', '2026-09-01 09:00:00'),
(2, 1, N'美式咖啡', N'醇香美式',     N'https://img/americano.jpg', N'上架', '2026-09-01 09:00:00'),
(3, 2, N'芝士蛋糕', N'轻乳酪蛋糕',   N'https://img/cheese.jpg',    N'上架', '2026-09-01 09:00:00');
SET IDENTITY_INSERT dbo.products OFF;
GO

-- SKU（规格 + 价格；价格挂在 SKU 上）
SET IDENTITY_INSERT dbo.skus ON;
INSERT INTO dbo.skus (sku_id, product_id, sku_name, price, status) VALUES
(1, 1, N'中杯/热', 15.00, N'上架'),
(2, 1, N'大杯/冰', 18.00, N'上架'),
(3, 2, N'中杯',    12.00, N'上架'),
(4, 3, N'单份',    22.00, N'上架');
SET IDENTITY_INSERT dbo.skus OFF;
GO

-- 库存（SKU × 门店，防超卖）
INSERT INTO dbo.inventory (sku_id, store_id, quantity) VALUES
(1, 1, 50), (2, 1, 30), (3, 1, 40), (4, 1, 20),
(1, 2, 10), (2, 2,  8), (3, 2, 15);
GO

-- ---------- 交易（订单 / 明细 / 支付 / 取餐） ----------

-- 订单（total_amount 与下方明细小计之和一致）
SET IDENTITY_INSERT dbo.orders ON;
INSERT INTO dbo.orders (order_id, order_no, user_id, store_id, pickup_time, remark, total_amount, status, created_at, paid_at, completed_at) VALUES
(1, N'202610060001', 1, 1, '2026-10-06 12:30:00', N'少糖', 33.00, N'已完成', '2026-10-06 10:05:00', '2026-10-06 10:06:00', '2026-10-06 12:28:00'),
(2, N'202610060002', 1, 1, NULL,                  NULL,   15.00, N'待支付', '2026-10-06 11:00:00', NULL,                  NULL),
(3, N'202610050001', 2, 2, '2026-10-05 16:00:00', NULL,   18.00, N'待取餐', '2026-10-05 15:20:00', '2026-10-05 15:21:00', NULL),
(4, N'202610050002', 2, 1, NULL,                  NULL,   12.00, N'已完成', '2026-10-05 09:30:00', '2026-10-05 09:31:00', '2026-10-05 09:50:00');
SET IDENTITY_INSERT dbo.orders OFF;
GO

-- 订单明细（含下单时的名称/单价快照，防止商品改价影响历史订单）
SET IDENTITY_INSERT dbo.order_items ON;
INSERT INTO dbo.order_items (order_item_id, order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal) VALUES
(1, 1, 1, N'拿铁咖啡', N'中杯/热', 15.00, 1, 15.00),
(2, 1, 2, N'拿铁咖啡', N'大杯/冰', 18.00, 1, 18.00),
(3, 2, 1, N'拿铁咖啡', N'中杯/热', 15.00, 1, 15.00),
(4, 3, 2, N'拿铁咖啡', N'大杯/冰', 18.00, 1, 18.00),
(5, 4, 3, N'美式咖啡', N'中杯',    12.00, 1, 12.00);
SET IDENTITY_INSERT dbo.order_items OFF;
GO

-- 支付记录（不存卡号等敏感信息）
SET IDENTITY_INSERT dbo.payments ON;
INSERT INTO dbo.payments (payment_id, payment_no, order_id, channel, channel_trade_no, amount, status, paid_at) VALUES
(1, N'P202610060001', 1, N'微信',   N'420000123456', 33.00, N'成功', '2026-10-06 10:06:00'),
(2, N'P202610050001', 3, N'校园卡', N'420000123457', 18.00, N'成功', '2026-10-05 15:21:00'),
(3, N'P202610050002', 4, N'支付宝', N'420000123458', 12.00, N'成功', '2026-10-05 09:31:00');
SET IDENTITY_INSERT dbo.payments OFF;
GO

-- 取餐码 / 核销（一单一码）
SET IDENTITY_INSERT dbo.pickup_codes ON;
INSERT INTO dbo.pickup_codes (pickup_id, order_id, pickup_code, status, verify_employee_id, verified_at) VALUES
(1, 1, N'A102', N'已核销', 2,    '2026-10-06 12:28:00'),
(2, 3, N'B205', N'待取餐', NULL, NULL),
(3, 4, N'C307', N'已核销', 2,    '2026-10-05 09:50:00');
SET IDENTITY_INSERT dbo.pickup_codes OFF;
GO

-- ---------- 营销与反馈（优惠券 / 评价 / 积分） ----------

-- 评价（一单一评）
SET IDENTITY_INSERT dbo.reviews ON;
INSERT INTO dbo.reviews (review_id, order_id, user_id, rating, content, created_at) VALUES
(1, 1, 1, 5, N'好喝，取餐快',   '2026-10-06 12:40:00'),
(2, 4, 2, 4, N'味道不错，稍甜', '2026-10-05 10:10:00');
SET IDENTITY_INSERT dbo.reviews OFF;
GO

-- 积分流水（每笔记录变动后余额；用户余额 = 本人最后一笔的 balance_after）
-- alice：82 + 33（消费）= 115，+ 5（评价）= 120
-- bob  ： 0 + 12（消费）=  12，+ 5（评价）=  17
SET IDENTITY_INSERT dbo.point_transactions ON;
INSERT INTO dbo.point_transactions (transaction_id, user_id, change_type, points_change, balance_after, order_id, created_at) VALUES
(1, 1, N'消费获得', 33, 115, 1, '2026-10-06 10:06:00'),
(2, 1, N'评价获得',  5, 120, 1, '2026-10-06 12:40:00'),
(3, 2, N'消费获得', 12,  12, 4, '2026-10-05 09:31:00'),
(4, 2, N'评价获得',  5,  17, 4, '2026-10-05 10:10:00');
SET IDENTITY_INSERT dbo.point_transactions OFF;
GO

-- 优惠券 / 活动
SET IDENTITY_INSERT dbo.coupons ON;
INSERT INTO dbo.coupons (coupon_id, coupon_name, [type], [value], min_amount, valid_from, valid_to, total_count, status) VALUES
(1, N'开学满30减5', N'满减', 5.00, 30.00, '2026-09-01 00:00:00', '2026-09-30 23:59:59', 1000, N'启用'),
(2, N'十月九折券',  N'折扣', 0.90,  0.00, '2026-10-01 00:00:00', '2026-10-31 23:59:59',  500, N'启用');
SET IDENTITY_INSERT dbo.coupons OFF;
GO

-- 优惠券领取记录（每用户每券限领一次）
SET IDENTITY_INSERT dbo.coupon_claims ON;
INSERT INTO dbo.coupon_claims (claim_id, coupon_id, user_id, status, claimed_at, used_at) VALUES
(1, 1, 1, N'未使用', '2026-09-05 12:00:00', NULL),
(2, 2, 2, N'未使用', '2026-10-01 10:00:00', NULL);
SET IDENTITY_INSERT dbo.coupon_claims OFF;
GO

-- ---------- 审计 ----------

-- 操作日志
SET IDENTITY_INSERT dbo.operation_logs ON;
INSERT INTO dbo.operation_logs (log_id, operator_id, [action], object_type, object_id, detail, created_at) VALUES
(1, 3, N'新增商品', N'product',   3,    N'上架芝士蛋糕',        '2026-09-20 10:00:00'),
(2, 3, N'修改库存', N'inventory', NULL, N'图书馆店补货 20 份',  '2026-10-05 08:30:00');
SET IDENTITY_INSERT dbo.operation_logs OFF;
GO

/* ============================================================
   Part 2  装载后核对
   ============================================================ */

-- ① 各表行数（预期见注释）
SELECT N'users' AS tbl, COUNT(*) AS cnt FROM dbo.users            -- 4
UNION ALL SELECT N'roles',            COUNT(*) FROM dbo.roles            -- 4
UNION ALL SELECT N'stores',           COUNT(*) FROM dbo.stores           -- 2
UNION ALL SELECT N'employees',        COUNT(*) FROM dbo.employees        -- 3
UNION ALL SELECT N'products',         COUNT(*) FROM dbo.products         -- 3
UNION ALL SELECT N'skus',             COUNT(*) FROM dbo.skus             -- 4
UNION ALL SELECT N'inventory',        COUNT(*) FROM dbo.inventory        -- 7
UNION ALL SELECT N'orders',           COUNT(*) FROM dbo.orders           -- 4
UNION ALL SELECT N'order_items',      COUNT(*) FROM dbo.order_items      -- 5
UNION ALL SELECT N'payments',         COUNT(*) FROM dbo.payments         -- 3
UNION ALL SELECT N'pickup_codes',     COUNT(*) FROM dbo.pickup_codes     -- 3
UNION ALL SELECT N'reviews',          COUNT(*) FROM dbo.reviews          -- 2
UNION ALL SELECT N'coupon_claims',    COUNT(*) FROM dbo.coupon_claims    -- 2
UNION ALL SELECT N'point_transactions', COUNT(*) FROM dbo.point_transactions -- 4
UNION ALL SELECT N'operation_logs',   COUNT(*) FROM dbo.operation_logs   -- 2
UNION ALL SELECT N'coupons',          COUNT(*) FROM dbo.coupons          -- 2
ORDER BY tbl;
GO

-- ② 自洽性核对：订单总额 = 该订单明细小计之和（预期返回 0 行）
SELECT o.order_id, o.total_amount AS [订单总额], SUM(oi.subtotal) AS [明细合计]
FROM dbo.orders o
JOIN dbo.order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.total_amount
HAVING o.total_amount <> SUM(oi.subtotal);
GO

-- ③ 自洽性核对：用户积分余额 = 本人最后一笔流水的 balance_after（预期返回 0 行）
WITH last_tx AS (
    SELECT user_id, balance_after,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY transaction_id DESC) AS rn
    FROM dbo.point_transactions
)
SELECT u.user_id, u.username, u.points_balance AS [账号余额], t.balance_after AS [流水末笔余额]
FROM dbo.users u
JOIN last_tx t ON u.user_id = t.user_id AND t.rn = 1
WHERE u.points_balance <> t.balance_after;
GO
