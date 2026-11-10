/* ============================================================
   09_migration.sql —— 第六周数据迁移（v0.1 → v1.0 目标结构）
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   作用：在 **v0.1 副本** 上，把数据库从 v0.1 结构迁移到第六周
        规范化后的目标结构，并保留基线数据，验证迁移前后业务含义一致。

   运行前提（重要）：
     1) 先备份或复制数据库。本脚本假定在「v0.1 副本」上运行，
        即用 week6.v0.1基线/ 目录下的 01 + 02 重建出的 CampusCoffee：
           01_create_database.sql  → 建库建表（employees.user_id 为 NULL）
           02_insert_sample_data.sql → 装载 v0.1 样例数据（王强 user_id = NULL）
     2) 目标结构见 01_create_database.sql（当前版）：
           employees.user_id 收紧为 NOT NULL；
           products.product_name 加唯一约束（候选码）。

   执行顺序：
       01 → 02（v0.1 副本）→ 本脚本 → 10_regression.sql

   失败恢复：
       本脚本整体开启 XACT_ABORT ON，数据迁移与字段调整在同一事务内，
       任一步 RAISERROR / 出错即自动回滚，回到 v0.1 原始状态。
       本脚本不要求可重复执行；如需重跑，请按 week6.v0.1基线/README.md
       「重建 v0.1 副本」回到初始状态后再执行。

   迁移内容一览：
       · 新表创建：无（20 张表结构全部保留，无拆分/合并/新增）
       · 字段调整：employees.user_id NULL → NOT NULL
       · 码设置：  products 新增候选码 product_name（UNIQUE 约束）；
                   其余主码/候选码/外码 v0.1 已正确，保持不变
       · 数据迁移：给无登录账号的员工「王强」回填账号 wangqiang(5)+店员角色
       · 重复检查：product_name 加唯一前查重、employees.user_id 查重
       · 旧表处理：全部保留，无删除/改名（见 Part 4 说明）
   ============================================================ */

USE CampusCoffee;
GO

SET XACT_ABORT ON;
GO

/* ============================================================
   Part 0  基线检查（迁移前基准，逐项留证）
   ============================================================ */

-- 0.1 基线护栏：employees.user_id 必须是「可空」，否则不是 v0.1 基线，中止
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.tables  t ON c.object_id = t.object_id
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'dbo' AND t.name = N'employees'
      AND c.name = N'user_id' AND c.is_nullable = 1
)
BEGIN
    RAISERROR(N'基线不符：employees.user_id 已非空，请在 v0.1 副本上运行（见 week6.v0.1基线/README.md）', 16, 1);
END
PRINT N'[基线] employees.user_id 为可空，符合 v0.1 基线。';
GO

-- 0.2 迁移前各表行数（预期：users=4, user_roles=4, employees=3, products=3, orders=4, order_items=5）
SELECT N'users' AS tbl, COUNT(*) AS cnt FROM dbo.users
UNION ALL SELECT N'user_roles',        COUNT(*) FROM dbo.user_roles
UNION ALL SELECT N'employees',         COUNT(*) FROM dbo.employees
UNION ALL SELECT N'products',          COUNT(*) FROM dbo.products
UNION ALL SELECT N'skus',              COUNT(*) FROM dbo.skus
UNION ALL SELECT N'inventory',         COUNT(*) FROM dbo.inventory
UNION ALL SELECT N'orders',            COUNT(*) FROM dbo.orders
UNION ALL SELECT N'order_items',       COUNT(*) FROM dbo.order_items
ORDER BY tbl;
GO

-- 0.3 迁移前「无账号员工」清单（预期：仅员工 3 王强，user_id 为 NULL）
SELECT employee_id, name, position, user_id
FROM dbo.employees
WHERE user_id IS NULL;
GO

-- 0.4 迁移前基准①：订单明细（预期 5 行）
SELECT oi.order_id, oi.product_name, oi.sku_name, oi.unit_price, oi.quantity, oi.subtotal
FROM dbo.order_items oi
ORDER BY oi.order_item_id;
GO

-- 0.5 迁移前基准②：商品销售统计（排除已取消；预期 拿铁咖啡 销量4/66.00，美式咖啡 销量1/12.00）
SELECT oi.product_name AS [商品],
       SUM(oi.quantity) AS [销量],
       SUM(oi.subtotal) AS [销售额]
FROM dbo.order_items oi
JOIN dbo.orders o ON oi.order_id = o.order_id
WHERE o.status <> N'已取消'
GROUP BY oi.product_name
ORDER BY [销售额] DESC;
GO

-- 0.6 迁移前基准③：库存查询（库存 < 10；预期 1 行：大杯/冰 · 宿舍区店 · 8）
SELECT s.store_name AS [门店], p.product_name AS [商品], k.sku_name AS [规格], i.quantity AS [库存]
FROM dbo.inventory i
JOIN dbo.skus     k ON i.sku_id    = k.sku_id
JOIN dbo.products p ON k.product_id = p.product_id
JOIN dbo.stores   s ON i.store_id  = s.store_id
WHERE i.quantity < 10
ORDER BY i.quantity;
GO

/* ============================================================
   Part 1 + Part 2  数据迁移 + 字段调整（同一事务，任一步失败整体回滚）
   ============================================================ */
BEGIN TRANSACTION;

-- ---------- 1. 重复数据检查 ----------

-- 1.1 product_name 加唯一约束前查重（预期 0 行，否则无法加唯一）
IF EXISTS (
    SELECT product_name FROM dbo.products
    GROUP BY product_name HAVING COUNT(*) > 1
)
BEGIN
    RAISERROR(N'存在重复商品名，无法为 products.product_name 加唯一约束', 16, 1);
END
PRINT N'[检查] products.product_name 无重复。';

-- 1.2 employees.user_id 非空值查重（一员工一账号；预期 0 行）
IF EXISTS (
    SELECT user_id FROM dbo.employees
    WHERE user_id IS NOT NULL
    GROUP BY user_id HAVING COUNT(*) > 1
)
BEGIN
    RAISERROR(N'存在多名员工共用一个登录账号，违反 employees.user_id 唯一约束', 16, 1);
END
PRINT N'[检查] employees.user_id 非空值无重复。';

-- ---------- 2. 数据迁移：给无账号员工回填登录账号 ----------
-- v0.1 样例中唯一无账号员工是「王强」(employee_id=3)，目标账号 wangqiang / 店员(role_id=2)
-- 回填后结果与 02_insert_sample_data.sql（当前版）一致。

IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE username = N'wangqiang')
BEGIN
    SET IDENTITY_INSERT dbo.users ON;
    INSERT INTO dbo.users (user_id, username, phone, email, password_hash, status, points_balance, created_at)
    VALUES (5, N'wangqiang', '13800000005', N'wangqiang@stu.edu.cn',
            N'pbkdf2:sha256:600000$ROFMyjqNyCbVomIQ$a83c69fd3b8e92a83e28b0dfda51da4ba7b4da51b83a856636386176106650fd',
            N'正常', 0, '2026-09-20 09:00:00');
    SET IDENTITY_INSERT dbo.users OFF;
    PRINT N'[迁移] 已回填员工「王强」登录账号 wangqiang (user_id=5)。';
END
ELSE
    PRINT N'[迁移] wangqiang 账号已存在，跳过创建。';

IF NOT EXISTS (SELECT 1 FROM dbo.user_roles WHERE user_id = 5 AND role_id = 2)
BEGIN
    INSERT INTO dbo.user_roles (user_id, role_id) VALUES (5, 2);
    PRINT N'[迁移] 已授予 wangqiang「店员」角色。';
END

UPDATE dbo.employees
SET user_id = 5
WHERE employee_id = 3 AND user_id IS NULL;

-- 迁移后必须无 NULL user_id，否则收紧非空会失败
IF EXISTS (SELECT 1 FROM dbo.employees WHERE user_id IS NULL)
BEGIN
    RAISERROR(N'仍有员工无登录账号，数据迁移未完成，中止', 16, 1);
END
PRINT N'[迁移] 员工「王强」user_id 已指向 5，无 NULL 剩余。';

-- ---------- 3. 字段调整 ----------

-- 3.1 employees.user_id 收紧为 NOT NULL
--     先卸下 v0.1 的「过滤唯一索引」，避免对带过滤索引的列执行 ALTER COLUMN 受约束；
--     列收紧非空后，原 WHERE user_id IS NOT NULL 过滤条件已无意义，重建为普通唯一索引。
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_employees_user_id' AND object_id = OBJECT_ID(N'dbo.employees'))
    DROP INDEX UX_employees_user_id ON dbo.employees;
ALTER TABLE dbo.employees ALTER COLUMN user_id INT NOT NULL;
CREATE UNIQUE INDEX UX_employees_user_id ON dbo.employees(user_id);
PRINT N'[结构] employees.user_id 已收紧为 NOT NULL，唯一索引已重建。';

-- 3.2 products.product_name 加唯一约束（候选码）
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_products_product_name' AND object_id = OBJECT_ID(N'dbo.products')
)
BEGIN
    ALTER TABLE dbo.products ADD CONSTRAINT UQ_products_product_name UNIQUE (product_name);
    PRINT N'[结构] products.product_name 已加唯一约束（候选码）。';
END
ELSE
    PRINT N'[结构] products.product_name 唯一约束已存在。';

COMMIT TRANSACTION;
PRINT N'迁移事务已提交。';
GO

/* ============================================================
   Part 3  主码 / 候选码 / 外码设置说明（无需变更项）
   ============================================================
   v0.1 已正确设置以下码，本脚本保持不动：
   · users        主码 user_id；候选码 username、phone（email 可空，不再作候选码）
   · roles/permissions/stores/categories/orders/payments/pickup_codes/reviews
                  均为单列自增主码 + 各自唯一候选码
   · products     主码 product_id；本次新增候选码 product_name
   · skus         主码 sku_id；候选码 (product_id, sku_name)
   · employees    主码 employee_id；候选码 user_id（唯一，本次收紧非空）
   · 关联表 user_roles / role_permissions / inventory / coupon_claims 组合主码
   · 全部外码均已在 v0.1 声明并指向对应表，无需改动
   ============================================================ */

/* ============================================================
   Part 4  旧表处理说明
   ============================================================
   · 20 张表全部保留，无拆分、无合并、无删除、无改名。
   · 变更仅两处：employees.user_id 可空→非空；products 新增 product_name 唯一约束。
   · 无「拆表导致的合理行数变化」——唯一行数变化来自数据迁移：
        users       4 → 5  （新增 wangqiang）
        user_roles  4 → 5  （wangqiang 授「店员」）
        其余表行数不变。
   ============================================================ */

/* ============================================================
   Part 5  迁移后核对（应与 Part 0 迁移前一致，仅 users/user_roles +1）
   ============================================================ */

-- 5.1 迁移后各表行数（预期：users=5, user_roles=5, 其余与 0.2 相同）
SELECT N'users' AS tbl, COUNT(*) AS cnt FROM dbo.users
UNION ALL SELECT N'user_roles',        COUNT(*) FROM dbo.user_roles
UNION ALL SELECT N'employees',         COUNT(*) FROM dbo.employees
UNION ALL SELECT N'products',          COUNT(*) FROM dbo.products
UNION ALL SELECT N'skus',              COUNT(*) FROM dbo.skus
UNION ALL SELECT N'inventory',         COUNT(*) FROM dbo.inventory
UNION ALL SELECT N'orders',            COUNT(*) FROM dbo.orders
UNION ALL SELECT N'order_items',       COUNT(*) FROM dbo.order_items
ORDER BY tbl;
GO

-- 5.2 员工 ↔ 登录账号（预期：3 行，王强 user_id=5，无 NULL）
SELECT e.employee_id, e.name, e.position, e.user_id, u.username
FROM dbo.employees e
LEFT JOIN dbo.users u ON e.user_id = u.user_id
ORDER BY e.employee_id;
GO

-- 5.3 迁移后基准①：订单明细（应与 0.4 一致，5 行）
SELECT oi.order_id, oi.product_name, oi.sku_name, oi.unit_price, oi.quantity, oi.subtotal
FROM dbo.order_items oi
ORDER BY oi.order_item_id;
GO

-- 5.4 迁移后基准②：商品销售统计（应与 0.5 一致）
SELECT oi.product_name AS [商品], SUM(oi.quantity) AS [销量], SUM(oi.subtotal) AS [销售额]
FROM dbo.order_items oi
JOIN dbo.orders o ON oi.order_id = o.order_id
WHERE o.status <> N'已取消'
GROUP BY oi.product_name
ORDER BY [销售额] DESC;
GO

-- 5.5 迁移后基准③：库存查询（应与 0.6 一致）
SELECT s.store_name AS [门店], p.product_name AS [商品], k.sku_name AS [规格], i.quantity AS [库存]
FROM dbo.inventory i
JOIN dbo.skus     k ON i.sku_id    = k.sku_id
JOIN dbo.products p ON k.product_id = p.product_id
JOIN dbo.stores   s ON i.store_id  = s.store_id
WHERE i.quantity < 10
ORDER BY i.quantity;
GO
