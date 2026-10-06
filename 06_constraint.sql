/* ============================================================
   06_constraint.sql —— 完整性约束（补充 + 正反例验证）
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   前提：已执行 01_create_database.sql 与 02_insert_sample_data.sql。

   说明：
   1) 主码、外键、UNIQUE 及多数 CHECK 已在 01_create_database.sql 中建立；
   2) 本文件补充 4 个强化完整性的 CHECK 约束；
   3) 之后给出「合法数据成功」与「非法数据被拒绝」两组验证用例。
      注意：反例语句会真实执行并报错，这是预期结果；
      执行完不会改动任何数据（因为都被拒绝了）。

   注意：ALTER TABLE ADD CONSTRAINT 仅首次执行成功，
        重复执行需先 DROP CONSTRAINT（见文末重置段）。
   ============================================================ */

USE CampusCoffee;
GO

/* ============================================================
   Part 1  补充约束
   ============================================================ */

-- 1. 用户积分余额非负
ALTER TABLE dbo.users ADD CONSTRAINT CK_users_points_balance CHECK (points_balance >= 0);
GO

-- 2. 订单明细小计必须等于 单价 × 数量
ALTER TABLE dbo.order_items ADD CONSTRAINT CK_order_items_subtotal_calc CHECK (subtotal = unit_price * quantity);
GO

-- 3. 优惠券价值按类型约束：满减金额 >= 0；折扣率在 (0,1) 之间
ALTER TABLE dbo.coupons ADD CONSTRAINT CK_coupons_value_range CHECK (
    ([type] = N'满减' AND [value] >= 0)
    OR ([type] = N'折扣' AND [value] > 0 AND [value] < 1)
);
GO

-- 4. 取餐码核销一致性：已核销必须有核销店员与核销时间
ALTER TABLE dbo.pickup_codes ADD CONSTRAINT CK_pickup_codes_verify CHECK (
    (status = N'待取餐' AND verify_employee_id IS NULL AND verified_at IS NULL)
    OR (status = N'已核销' AND verify_employee_id IS NOT NULL AND verified_at IS NOT NULL)
);
GO

-- 补充完成后，确认约束已生效（这是"约束确实存在"的证据）
SELECT name AS [约束名], type_desc AS [类型]
FROM sys.check_constraints
WHERE parent_object_id IN (
    OBJECT_ID(N'dbo.users'), OBJECT_ID(N'dbo.order_items'),
    OBJECT_ID(N'dbo.coupons'), OBJECT_ID(N'dbo.pickup_codes')
)
ORDER BY name;
GO

/* ============================================================
   Part 2  正例：合法数据应当成功
   ============================================================ */

-- 正例：小计 = 15.00 × 1 = 15.00，满足 CK_order_items_subtotal_calc → 应插入成功
DECLARE @new_id INT;
INSERT INTO dbo.order_items (order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal)
VALUES (2, 1, N'拿铁咖啡', N'中杯/热', 15.00, 1, 15.00);
SET @new_id = SCOPE_IDENTITY();
SELECT N'正例：合法数据插入成功' AS [结果], @new_id AS [新行ID];

-- 验证后立即删除，保持数据基线不变
DELETE FROM dbo.order_items WHERE order_item_id = @new_id;
SELECT N'正例测试数据已清理' AS [结果], COUNT(*) AS [剩余行数] FROM dbo.order_items WHERE order_item_id = @new_id;
GO

/* ============================================================
   Part 3  反例：非法数据应被拒绝
   ★ 以下每条都应报错。建议逐条单独执行（Ctrl+Shift+E 单条执行），
     并逐条截图保存为「非法数据被拒绝」的证据。
   ============================================================ */

PRINT N'【反例①】把用户积分改成 -1 —— 预期：与 CK_users_points_balance 冲突';
GO
UPDATE dbo.users SET points_balance = -1 WHERE user_id = 1;
GO

PRINT N'【反例②】明细小计写成 15.00，但 单价 15.00 × 数量 2 = 30.00 —— 预期：与 CK_order_items_subtotal_calc 冲突';
GO
INSERT INTO dbo.order_items (order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal)
VALUES (2, 1, N'拿铁咖啡', N'中杯/热', 15.00, 2, 15.00);
GO

PRINT N'【反例③】折扣券折扣率填 5.00（不在 (0,1)）—— 预期：与 CK_coupons_value_range 冲突';
GO
INSERT INTO dbo.coupons (coupon_name, [type], [value], min_amount, valid_from, valid_to, total_count, status)
VALUES (N'五折券', N'折扣', 5.00, 0.00, '2026-10-01', '2026-10-31', 100, N'启用');
GO

PRINT N'【反例④】取餐码标成「已核销」却没有核销店员和时间 —— 预期：与 CK_pickup_codes_verify 冲突';
GO
INSERT INTO dbo.pickup_codes (order_id, pickup_code, status, verify_employee_id, verified_at)
VALUES (2, N'B200', N'已核销', NULL, NULL);
GO

PRINT N'【反例⑤】订单引用不存在的用户 999 —— 预期：与外键 FK_orders_users 冲突';
GO
INSERT INTO dbo.orders (order_no, user_id, store_id, total_amount, status)
VALUES (N'202610060099', 999, 1, 10.00, N'待支付');
GO

PRINT N'【反例⑥】用户名重复（alice 已存在）—— 预期：与唯一约束 UQ_users_username 冲突';
GO
INSERT INTO dbo.users (username, phone, email, password_hash, status, points_balance)
VALUES (N'alice', '13800000009', 'alice2@stu.edu.cn', N'hash_x', N'正常', 0);
GO

PRINT N'【反例⑦】给已有取餐码的订单 1 再插一个取餐码 —— 预期：与唯一约束 UQ_pickup_codes_order_id 冲突（一单一码）';
GO
INSERT INTO dbo.pickup_codes (order_id, pickup_code, status, verify_employee_id, verified_at)
VALUES (1, N'Z999', N'待取餐', NULL, NULL);
GO

-- 反例执行完后核对：数据未被改动（预期各表行数与 02 装载后一致）
SELECT N'users' AS tbl, COUNT(*) AS cnt FROM dbo.users            -- 4
UNION ALL SELECT N'orders',        COUNT(*) FROM dbo.orders       -- 4
UNION ALL SELECT N'order_items',   COUNT(*) FROM dbo.order_items  -- 5
UNION ALL SELECT N'pickup_codes',  COUNT(*) FROM dbo.pickup_codes -- 3
UNION ALL SELECT N'coupons',       COUNT(*) FROM dbo.coupons      -- 2
ORDER BY tbl;
GO

/* ============================================================
   Part 4  重置（仅在需要重复执行本文件时使用）
   先删掉 Part 1 补充的约束，再重新执行本文件即可。
   ============================================================ */
 --ALTER TABLE dbo.users         DROP CONSTRAINT CK_users_points_balance;
 --ALTER TABLE dbo.order_items   DROP CONSTRAINT CK_order_items_subtotal_calc;
 --ALTER TABLE dbo.coupons       DROP CONSTRAINT CK_coupons_value_range;
 --ALTER TABLE dbo.pickup_codes  DROP CONSTRAINT CK_pickup_codes_verify;
 --GO
