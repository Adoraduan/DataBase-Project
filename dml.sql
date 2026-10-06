/* ============================================================
   dml.sql —— week3 增删改（DML）验证方案
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================

   目的：在 ddl.sql 建好的空库 CampusCoffee 上，验证 INSERT / UPDATE /
         DELETE 可用、可复现，并通过 SELECT 核对每步结果。

   复现步骤：
     1) 先执行 ddl.sql 建立空库；
     2) 执行本 dml.sql。脚本顶部会先清空数据，因此可反复执行（幂等）。

   验证方法：每个增/删/改之后紧跟一条 SELECT，注释里写「预期结果」，
             逐条核对是否一致。

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
   Part 1  增（INSERT）：装载基础数据
   用显式主码 + IDENTITY_INSERT，保证数据确定、可复现。
   ============================================================ */

-- 角色
SET IDENTITY_INSERT dbo.roles ON;
INSERT INTO dbo.roles (role_id, role_name, description) VALUES
(1, N'顾客',     N'注册用户，下单取餐评价'),
(2, N'店员',     N'接单制作核销'),
(3, N'店长',     N'管理商品库存优惠审批退款'),
(4, N'系统管理员', N'管账号角色权限与配置');
SET IDENTITY_INSERT dbo.roles OFF;
GO

-- 权限
SET IDENTITY_INSERT dbo.permissions ON;
INSERT INTO dbo.permissions (permission_id, permission_name, description) VALUES
(1, 'order:create',   N'下单'),
(2, 'order:verify',   N'核销取餐'),
(3, 'product:edit',   N'维护商品'),
(4, 'coupon:manage',  N'管理优惠券');
SET IDENTITY_INSERT dbo.permissions OFF;
GO

-- 角色-权限
INSERT INTO dbo.role_permissions (role_id, permission_id) VALUES
(1, 1),   -- 顾客：下单
(2, 2),   -- 店员：核销
(3, 3),   -- 店长：维护商品
(3, 4);   -- 店长：管理优惠券
GO

-- 用户（会员=已注册顾客）
SET IDENTITY_INSERT dbo.users ON;
INSERT INTO dbo.users (user_id, username, phone, email, password_hash, status, points_balance, created_at) VALUES
(1, N'alice', '13800000001', 'alice@stu.edu.cn', N'hash_alice', N'正常', 120, '2026-09-01 09:00:00'),
(2, N'bob',   '13800000002', 'bob@stu.edu.cn',   N'hash_bob',   N'正常',   0, '2026-09-01 09:00:00'),
(3, N'carol', '13800000003', 'carol@stu.edu.cn', N'hash_carol', N'正常',   0, '2026-09-01 09:00:00'),
(4, N'admin', '13800000004', 'admin@coffee.cn',  N'hash_admin', N'正常',   0, '2026-09-01 09:00:00');
SET IDENTITY_INSERT dbo.users OFF;
GO

-- 用户-角色
INSERT INTO dbo.user_roles (user_id, role_id) VALUES
(1, 1), (2, 2), (3, 3), (4, 4);
GO

-- 门店
SET IDENTITY_INSERT dbo.stores ON;
INSERT INTO dbo.stores (store_id, store_name, address, phone, status) VALUES
(1, N'图书馆店', N'图书馆一楼', '13800000100', N'营业'),
(2, N'宿舍区店', N'宿舍区',     '13800000200', N'营业');
SET IDENTITY_INSERT dbo.stores OFF;
GO

-- 员工
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, user_id, store_id, name, position, hire_date) VALUES
(1, 3,    1, N'张伟', N'店长', '2025-09-01'),
(2, 2,    1, N'李娜', N'店员', '2026-03-01'),
(3, NULL, 2, N'王强', N'店员', '2026-06-01');
SET IDENTITY_INSERT dbo.employees OFF;
GO

-- 商品分类
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
(1, 3, N'拿铁咖啡', N'经典意式拿铁', N'https://img/latte.jpg', N'上架', '2026-09-01 09:00:00'),
(2, 1, N'美式咖啡', N'醇香美式',     N'https://img/americano.jpg', N'上架', '2026-09-01 09:00:00'),
(3, 2, N'芝士蛋糕', N'轻乳酪蛋糕',   N'https://img/cheese.jpg', N'上架', '2026-09-01 09:00:00');
SET IDENTITY_INSERT dbo.products OFF;
GO

-- SKU（规格+价格）
SET IDENTITY_INSERT dbo.skus ON;
INSERT INTO dbo.skus (sku_id, product_id, sku_name, price, status) VALUES
(1, 1, N'中杯/热', 15.00, N'上架'),
(2, 1, N'大杯/冰', 18.00, N'上架'),
(3, 2, N'中杯',    12.00, N'上架'),
(4, 3, N'单份',    22.00, N'上架');
SET IDENTITY_INSERT dbo.skus OFF;
GO

-- 库存（SKU × 门店）
INSERT INTO dbo.inventory (sku_id, store_id, quantity) VALUES
(1, 1, 50), (2, 1, 30), (3, 1, 40), (4, 1, 20),
(1, 2, 10), (2, 2,  8);
GO

-- 订单
SET IDENTITY_INSERT dbo.orders ON;
INSERT INTO dbo.orders (order_id, order_no, user_id, store_id, pickup_time, remark, total_amount, status, created_at, paid_at, completed_at) VALUES
(1, N'202610060001', 1, 1, '2026-10-06 12:30:00', N'少糖', 33.00, N'已完成', '2026-10-06 10:05:00', '2026-10-06 10:06:00', '2026-10-06 12:28:00'),
(2, N'202610060002', 1, 1, NULL,                  NULL,   15.00, N'待支付', '2026-10-06 11:00:00', NULL, NULL);
SET IDENTITY_INSERT dbo.orders OFF;
GO

-- 订单明细（含商品快照）
SET IDENTITY_INSERT dbo.order_items ON;
INSERT INTO dbo.order_items (order_item_id, order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal) VALUES
(1, 1, 1, N'拿铁咖啡', N'中杯/热', 15.00, 1, 15.00),
(2, 1, 2, N'拿铁咖啡', N'大杯/冰', 18.00, 1, 18.00),
(3, 2, 1, N'拿铁咖啡', N'中杯/热', 15.00, 1, 15.00);
SET IDENTITY_INSERT dbo.order_items OFF;
GO

-- 支付记录
SET IDENTITY_INSERT dbo.payments ON;
INSERT INTO dbo.payments (payment_id, payment_no, order_id, channel, channel_trade_no, amount, status, paid_at) VALUES
(1, N'P202610060001', 1, N'微信', N'420000123456', 33.00, N'成功', '2026-10-06 10:06:00');
SET IDENTITY_INSERT dbo.payments OFF;
GO

-- 取餐码/核销
SET IDENTITY_INSERT dbo.pickup_codes ON;
INSERT INTO dbo.pickup_codes (pickup_id, order_id, pickup_code, status, verify_employee_id, verified_at) VALUES
(1, 1, N'A102', N'已核销', 2, '2026-10-06 12:28:00');
SET IDENTITY_INSERT dbo.pickup_codes OFF;
GO

-- 评价
SET IDENTITY_INSERT dbo.reviews ON;
INSERT INTO dbo.reviews (review_id, order_id, user_id, rating, content, created_at) VALUES
(1, 1, 1, 5, N'好喝，取餐快', '2026-10-06 12:40:00');
SET IDENTITY_INSERT dbo.reviews OFF;
GO

-- 积分流水（alice：82 → 115 → 120，与 users.points_balance=120 一致）
SET IDENTITY_INSERT dbo.point_transactions ON;
INSERT INTO dbo.point_transactions (transaction_id, user_id, change_type, points_change, balance_after, order_id, created_at) VALUES
(1, 1, N'消费获得', 33, 115, 1, '2026-10-06 10:06:00'),
(2, 1, N'评价获得',  5, 120, 1, '2026-10-06 12:40:00');
SET IDENTITY_INSERT dbo.point_transactions OFF;
GO

-- 优惠券
SET IDENTITY_INSERT dbo.coupons ON;
INSERT INTO dbo.coupons (coupon_id, coupon_name, [type], [value], min_amount, valid_from, valid_to, total_count, status) VALUES
(1, N'开学满30减5', N'满减', 5.00, 30.00, '2026-09-01 00:00:00', '2026-09-30 23:59:59', 1000, N'启用');
SET IDENTITY_INSERT dbo.coupons OFF;
GO

-- 优惠券领取记录
SET IDENTITY_INSERT dbo.coupon_claims ON;
INSERT INTO dbo.coupon_claims (claim_id, coupon_id, user_id, status, claimed_at, used_at) VALUES
(1, 1, 1, N'未使用', '2026-09-05 12:00:00', NULL);
SET IDENTITY_INSERT dbo.coupon_claims OFF;
GO

-- 操作日志
SET IDENTITY_INSERT dbo.operation_logs ON;
INSERT INTO dbo.operation_logs (log_id, operator_id, [action], object_type, object_id, detail, created_at) VALUES
(1, 3, N'修改价格', N'sku', 1, N'拿铁中杯涨价', '2026-10-06 11:00:00');
SET IDENTITY_INSERT dbo.operation_logs OFF;
GO

-- 装载完成后核对（预期：返回各表行数）
SELECT N'roles' AS tbl, COUNT(*) AS cnt FROM dbo.roles
UNION ALL SELECT N'users', COUNT(*) FROM dbo.users
UNION ALL SELECT N'products', COUNT(*) FROM dbo.products
UNION ALL SELECT N'skus', COUNT(*) FROM dbo.skus
UNION ALL SELECT N'orders', COUNT(*) FROM dbo.orders
UNION ALL SELECT N'order_items', COUNT(*) FROM dbo.order_items;
GO

/* ============================================================
   Part 2  改（UPDATE）：典型修改 + 验证
   ============================================================ */

-- ① 修改 SKU 价格（预期：sku_id=1 的 price 由 15.00 变为 16.00）
UPDATE dbo.skus SET price = 16.00 WHERE sku_id = 1;
SELECT sku_id, product_id, sku_name, price FROM dbo.skus WHERE sku_id = 1;
GO

-- ② 库存扣减（预期：sku1@store1 的 quantity 由 50 变为 48）
UPDATE dbo.inventory SET quantity = quantity - 2 WHERE sku_id = 1 AND store_id = 1;
SELECT sku_id, store_id, quantity FROM dbo.inventory WHERE sku_id = 1 AND store_id = 1;
GO

-- ③ 订单状态推进（预期：order_id=2 状态由 待支付 变 已支付，paid_at 非空）
UPDATE dbo.orders SET status = N'已支付', paid_at = GETDATE() WHERE order_id = 2;
SELECT order_id, status, paid_at FROM dbo.orders WHERE order_id = 2;
GO

-- ④ 商品下架（预期：product_id=3 的 status 变 下架）
UPDATE dbo.products SET status = N'下架' WHERE product_id = 3;
SELECT product_id, product_name, status FROM dbo.products WHERE product_id = 3;
GO

-- ⑤ 会员积分增加（预期：user_id=1 的 points_balance 由 120 变为 125）
UPDATE dbo.users SET points_balance = points_balance + 5 WHERE user_id = 1;
SELECT user_id, username, points_balance FROM dbo.users WHERE user_id = 1;
GO

/* ============================================================
   Part 3  删（DELETE）：典型删除 + 验证
   ============================================================ */

-- ① 删除评价（预期：reviews 表中 review_id=1 行消失，返回 0 行）
DELETE FROM dbo.reviews WHERE review_id = 1;
SELECT * FROM dbo.reviews WHERE review_id = 1;
GO

-- ② 删除优惠券领取记录（预期：coupon_claims 表返回 0 行）
DELETE FROM dbo.coupon_claims WHERE claim_id = 1;
SELECT * FROM dbo.coupon_claims WHERE claim_id = 1;
GO

-- ③ 删除一条订单明细（预期：order_item_id=3 行消失）
DELETE FROM dbo.order_items WHERE order_item_id = 3;
SELECT * FROM dbo.order_items WHERE order_item_id = 3;
GO

-- ④ 删除一条操作日志（预期：log_id=1 行消失）
DELETE FROM dbo.operation_logs WHERE log_id = 1;
SELECT * FROM dbo.operation_logs WHERE log_id = 1;
GO

/* ============================================================
   Part 4  约束验证（预期失败，可选）
   以下语句应被约束拒绝；建议逐条执行，观察报错信息。
   ============================================================ */

-- ① 非法库存（负数）→ 应触发 CHECK 失败
-- INSERT INTO dbo.inventory (sku_id, store_id, quantity) VALUES (3, 2, -5);

-- ② 删除还有订单的用户 → 应触发外键失败
-- DELETE FROM dbo.users WHERE user_id = 1;

-- ③ 非法订单状态 → 应触发 CHECK 失败
-- UPDATE dbo.orders SET status = N'不存在状态' WHERE order_id = 1;
GO
