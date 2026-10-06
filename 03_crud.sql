/* ============================================================
   03_crud.sql —— 增删改（DML）演示
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   前提：已执行 01（建库建表）与 02（装载样例数据）。

   本文件演示 INSERT / UPDATE / DELETE，每个操作后紧跟 SELECT 核对，
   注释里写「预期结果」，逐条比对。

   设计原则（重要）：
     增删改会改变数据，所以本文件刻意让它「不破坏 02 建立的基线」——
       - INSERT 新增的是演示数据（dave、订单 5）；
       - DELETE 删掉的是本文件自己新增的演示数据，不删 02 装载的基线数据；
       - UPDATE 只改「当前值」（价格、库存、状态），不制造孤儿行或对不上账。
     Part 0 在开头把这些改动逐一还原，所以本文件可反复执行；
     这样跑完本文件，数据即回到 02 建立的基线，04_query.sql / 05_view.sql
     仍然跑在完整数据上。

   约束反例（预期失败）统一放在 06_constraint.sql，本文件不重复。
   ============================================================ */

USE CampusCoffee;
GO

/* ============================================================
   Part 0  把数据恢复到 02 建立的基线（保证本文件可重复执行）
   本文件会新增 user_id = 5、order_id = 5 的一组数据（账号、订单、明细、
   支付、评价、领券、积分流水），并在 Part 2 修改若干「当前值」。
   开头先把改动逐个还原，使本文件可反复执行、每次结果一致：
     ① 按外键逆序删掉新增的演示数据；
     ② 把 Part 2 改过的价格 / 库存 / 商品状态写回基线值
        （库存是「减 2」这类相对运算，不还原就会一次比一次少）。
   首次执行时，这些语句都不改动任何实际数据。
   ============================================================ */
DELETE FROM dbo.point_transactions WHERE user_id  = 5;
DELETE FROM dbo.reviews            WHERE user_id  = 5;
DELETE FROM dbo.coupon_claims      WHERE user_id  = 5;
DELETE FROM dbo.payments           WHERE order_id = 5;
DELETE FROM dbo.order_items        WHERE order_id = 5;
DELETE FROM dbo.orders             WHERE order_id = 5;
DELETE FROM dbo.users              WHERE user_id  = 5;

UPDATE dbo.skus      SET price    = 15.00   WHERE sku_id     = 1;
UPDATE dbo.inventory SET quantity = 50      WHERE sku_id     = 1 AND store_id = 1;
UPDATE dbo.products  SET status   = N'上架' WHERE product_id = 3;
GO

/* ============================================================
   Part 1  增（INSERT）
   场景：新会员 dave 注册并下了一单（拿铁中杯 × 2）
   ============================================================ */

-- ① 新增会员账号（预期：插入 1 行，user_id = 5）
SET IDENTITY_INSERT dbo.users ON;
INSERT INTO dbo.users (user_id, username, phone, email, password_hash, status, points_balance, created_at)
VALUES (5, N'dave', '13800000005', 'dave@stu.edu.cn', N'hash_dave', N'正常', 0, '2026-10-06 14:00:00');
SET IDENTITY_INSERT dbo.users OFF;
GO

SELECT user_id, username, phone, status, points_balance FROM dbo.users WHERE user_id = 5;
GO

-- ② 新增订单（预期：插入 1 行，order_id = 5，状态「待支付」）
SET IDENTITY_INSERT dbo.orders ON;
INSERT INTO dbo.orders (order_id, order_no, user_id, store_id, pickup_time, remark, total_amount, status, created_at)
VALUES (5, N'202610060003', 5, 1, '2026-10-06 15:00:00', N'常温', 30.00, N'待支付', '2026-10-06 14:05:00');
SET IDENTITY_INSERT dbo.orders OFF;
GO

SELECT order_id, order_no, user_id, status, total_amount FROM dbo.orders WHERE order_id = 5;
GO

-- ③ 新增订单明细（预期：插入 1 行；小计 = 15.00 × 2 = 30.00，与订单总额一致）
SET IDENTITY_INSERT dbo.order_items ON;
INSERT INTO dbo.order_items (order_item_id, order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal)
VALUES (6, 5, 1, N'拿铁咖啡', N'中杯/热', 15.00, 2, 30.00);
SET IDENTITY_INSERT dbo.order_items OFF;
GO

SELECT order_item_id, order_id, product_name, sku_name, unit_price, quantity, subtotal
FROM dbo.order_items WHERE order_id = 5;
GO

-- ④ 新增支付记录（预期：插入 1 行）
SET IDENTITY_INSERT dbo.payments ON;
INSERT INTO dbo.payments (payment_id, payment_no, order_id, channel, channel_trade_no, amount, status, paid_at)
VALUES (4, N'P202610060003', 5, N'微信', N'420000123459', 30.00, N'成功', '2026-10-06 14:06:00');
SET IDENTITY_INSERT dbo.payments OFF;
GO

SELECT payment_id, payment_no, order_id, channel, amount, status FROM dbo.payments WHERE order_id = 5;
GO

-- ⑤ 新增评价（预期：插入 1 行。reviews 对 order_id 有唯一约束，一单一评）
SET IDENTITY_INSERT dbo.reviews ON;
INSERT INTO dbo.reviews (review_id, order_id, user_id, rating, content, created_at)
VALUES (3, 5, 5, 5, N'出餐快，温度刚好', '2026-10-06 14:30:00');
SET IDENTITY_INSERT dbo.reviews OFF;
GO

SELECT review_id, order_id, user_id, rating, content FROM dbo.reviews WHERE review_id = 3;
GO

-- ⑥ 新增领券记录（预期：插入 1 行。coupon_claims 对 (coupon_id, user_id) 有唯一约束）
SET IDENTITY_INSERT dbo.coupon_claims ON;
INSERT INTO dbo.coupon_claims (claim_id, coupon_id, user_id, status, claimed_at)
VALUES (3, 1, 5, N'未使用', '2026-10-06 14:02:00');
SET IDENTITY_INSERT dbo.coupon_claims OFF;
GO

SELECT claim_id, coupon_id, user_id, status FROM dbo.coupon_claims WHERE claim_id = 3;
GO

/* ============================================================
   Part 2  改（UPDATE）
   ============================================================ */

-- ① 调价：拿铁中杯 15.00 → 16.00（预期：price 变为 16.00）
UPDATE dbo.skus SET price = 16.00 WHERE sku_id = 1;
SELECT sku_id, sku_name, price FROM dbo.skus WHERE sku_id = 1;
GO

-- 验证快照机制：SKU 现价已变，但历史订单明细里的单价快照不变（应仍是 15.00）
SELECT k.sku_id, k.sku_name, k.price AS [SKU现价],
       oi.order_id, oi.unit_price AS [明细内单价快照]
FROM dbo.skus k
JOIN dbo.order_items oi ON k.sku_id = oi.sku_id
WHERE k.sku_id = 1
ORDER BY oi.order_id;
GO

-- ② 扣减库存：图书馆店 拿铁中杯 50 → 48（预期：quantity 变为 48）
UPDATE dbo.inventory SET quantity = quantity - 2 WHERE sku_id = 1 AND store_id = 1;
SELECT sku_id, store_id, quantity FROM dbo.inventory WHERE sku_id = 1 AND store_id = 1;
GO

-- ③ 推进订单状态：演示订单 5 由「待支付」→「已支付」（预期：paid_at 非空）
--    刻意不用基线订单 2，避免影响 05_view.sql 里的销售额统计
UPDATE dbo.orders SET status = N'已支付', paid_at = GETDATE() WHERE order_id = 5;
SELECT order_id, status, paid_at FROM dbo.orders WHERE order_id = 5;
GO

-- ④ 商品下架：芝士蛋糕（预期：status 变为「下架」）
UPDATE dbo.products SET status = N'下架' WHERE product_id = 3;
SELECT product_id, product_name, status FROM dbo.products WHERE product_id = 3;
GO

-- ⑤ 发放积分：dave 消费 30 元得 30 分（预期：余额 0 → 30）
--    注意：改余额的同时必须写一笔积分流水，否则「余额」与「流水末笔」对不上账
UPDATE dbo.users SET points_balance = points_balance + 30 WHERE user_id = 5;
SET IDENTITY_INSERT dbo.point_transactions ON;
INSERT INTO dbo.point_transactions (transaction_id, user_id, change_type, points_change, balance_after, order_id, created_at)
VALUES (5, 5, N'消费获得', 30, 30, 5, '2026-10-06 14:06:00');
SET IDENTITY_INSERT dbo.point_transactions OFF;
GO

SELECT u.user_id, u.username, u.points_balance AS [账号余额],
       t.points_change, t.balance_after AS [流水末笔余额]
FROM dbo.users u
JOIN dbo.point_transactions t ON u.user_id = t.user_id
WHERE u.user_id = 5;
GO

/* ============================================================
   Part 3  删（DELETE）
   删除前先 SELECT 出目标行，删完再 SELECT 验证为空。
   ============================================================ */

-- ① 删除演示订单的明细（先看到它存在）
SELECT order_item_id, order_id, product_name, subtotal FROM dbo.order_items WHERE order_id = 5;
GO
DELETE FROM dbo.order_items WHERE order_id = 5;
GO
SELECT order_item_id, order_id FROM dbo.order_items WHERE order_id = 5;   -- 预期：0 行
GO

-- ② 删除演示订单的支付记录
DELETE FROM dbo.payments WHERE order_id = 5;
SELECT payment_id, order_id FROM dbo.payments WHERE order_id = 5;         -- 预期：0 行
GO

-- ③ 删除 dave 的积分流水（其 order_id 指向订单 5，故先于订单删除）
DELETE FROM dbo.point_transactions WHERE user_id = 5;
SELECT transaction_id, order_id FROM dbo.point_transactions WHERE user_id = 5;  -- 预期：0 行
GO

-- ④ 删除演示评价（引用订单 5 与 dave，故先于两者删除）
SELECT review_id, order_id, rating, content FROM dbo.reviews WHERE review_id = 3;
GO
DELETE FROM dbo.reviews WHERE review_id = 3;
SELECT review_id, order_id, rating FROM dbo.reviews WHERE review_id = 3;  -- 预期：0 行
GO

-- ⑤ 删除演示领券记录（引用 dave，故先于用户删除）
SELECT claim_id, coupon_id, user_id, status FROM dbo.coupon_claims WHERE claim_id = 3;
GO
DELETE FROM dbo.coupon_claims WHERE claim_id = 3;
SELECT claim_id, coupon_id, user_id, status FROM dbo.coupon_claims WHERE claim_id = 3;  -- 预期：0 行
GO

-- ⑥ 删除演示订单本身
DELETE FROM dbo.orders WHERE order_id = 5;
SELECT order_id, order_no FROM dbo.orders WHERE order_id = 5;             -- 预期：0 行
GO

-- ⑦ 删除演示用户 dave
DELETE FROM dbo.users WHERE user_id = 5;
SELECT user_id, username FROM dbo.users WHERE user_id = 5;                -- 预期：0 行
GO

/* ============================================================
   Part 4  收尾核对
   ============================================================ */

-- 每张表仍有数据，04_query.sql / 05_view.sql 不会查空
SELECT N'orders' AS tbl, COUNT(*) AS cnt FROM dbo.orders
UNION ALL SELECT N'order_items',     COUNT(*) FROM dbo.order_items
UNION ALL SELECT N'reviews',         COUNT(*) FROM dbo.reviews
UNION ALL SELECT N'coupon_claims',   COUNT(*) FROM dbo.coupon_claims
UNION ALL SELECT N'point_transactions', COUNT(*) FROM dbo.point_transactions
ORDER BY tbl;
GO

-- 自洽性复核：订单总额 = 明细小计之和（预期 0 行）、积分余额 = 流水末笔（预期 0 行）
SELECT o.order_id, o.total_amount, SUM(oi.subtotal) AS items_sum
FROM dbo.orders o
JOIN dbo.order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.total_amount
HAVING o.total_amount <> SUM(oi.subtotal);
GO

WITH last_tx AS (
    SELECT user_id, balance_after,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY transaction_id DESC) AS rn
    FROM dbo.point_transactions
)
SELECT u.user_id, u.username, u.points_balance, t.balance_after
FROM dbo.users u
JOIN last_tx t ON u.user_id = t.user_id AND t.rn = 1
WHERE u.points_balance <> t.balance_after;
GO
