/* ============================================================
   constraint.sql —— week4 完整性约束（主外键/检查约束）
   ============================================================
   说明：
   1) 主码、外键、UNIQUE 及多数 CHECK 已在 ddl.sql 中建立；
   2) 本文件补充若干强化完整性的 CHECK 约束；
   3) 末尾给出「非法数据被拒绝」验证（预期失败，建议逐条执行）。
   注意：ALTER TABLE ADD CONSTRAINT 仅首次执行，重复执行需先 DROP CONSTRAINT。
   ============================================================ */

USE CampusCoffee;
GO

-- ===== 补充约束 =====

-- 1. 用户积分余额非负
ALTER TABLE dbo.users ADD CONSTRAINT CK_users_points_balance CHECK (points_balance >= 0);
GO

-- 2. 订单明细小计 = 单价 × 数量
ALTER TABLE dbo.order_items ADD CONSTRAINT CK_order_items_subtotal_calc CHECK (subtotal = unit_price * quantity);
GO

-- 3. 优惠券价值约束：满减金额>=0；折扣率在(0,1)
ALTER TABLE dbo.coupons ADD CONSTRAINT CK_coupons_value_range CHECK (
    ([type] = N'满减' AND [value] >= 0)
    OR ([type] = N'折扣' AND [value] > 0 AND [value] < 1)
);
GO

-- 4. 取餐码核销一致性：已核销必须有核销店员与时间
ALTER TABLE dbo.pickup_codes ADD CONSTRAINT CK_pickup_codes_verify CHECK (
    (status = N'待取餐' AND verify_employee_id IS NULL AND verified_at IS NULL)
    OR (status = N'已核销' AND verify_employee_id IS NOT NULL AND verified_at IS NOT NULL)
);
GO

-- ===== 非法数据被拒绝验证（预期失败，建议逐条执行观察报错） =====

-- ① 负积分余额 → 触发 CK_users_points_balance
-- UPDATE dbo.users SET points_balance = -1 WHERE user_id = 1;

-- ② 小计与单价×数量不符 → 触发 CK_order_items_subtotal_calc（应为 30.00）
-- INSERT INTO dbo.order_items (order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal)
-- VALUES (2, 1, N'拿铁咖啡', N'中杯/热', 15.00, 2, 15.00);

-- ③ 折扣率越界 → 触发 CK_coupons_value_range（5 不在 (0,1)）
-- INSERT INTO dbo.coupons (coupon_name, [type], [value], min_amount, valid_from, valid_to, total_count, status)
-- VALUES (N'五折券', N'折扣', 5.00, 0.00, '2026-10-01', '2026-10-31', 100, N'启用');

-- ④ 已核销却无核销店员/时间 → 触发 CK_pickup_codes_verify
-- INSERT INTO dbo.pickup_codes (order_id, pickup_code, status, verify_employee_id, verified_at)
-- VALUES (2, N'B200', N'已核销', NULL, NULL);

-- ⑤ 引用不存在的用户 → 触发外键 FK
-- INSERT INTO dbo.orders (order_no, user_id, store_id, total_amount, status)
-- VALUES (N'202610060099', 999, 1, 10.00, N'待支付');
GO
