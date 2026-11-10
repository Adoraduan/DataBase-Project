/* ============================================================
   10_regression.sql —— 第六周迁移回归测试
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   作用：在 09_migration.sql 迁移完成后，验证迁移前后业务含义一致，
        覆盖关键标识、关系映射、订单金额、商品销量、库存、角色权限，
        以及合法写入 / 非法外码与数量 / 越权操作。

   运行前提：
     1) 已按 week6.v0.1基线/ 重建 v0.1 副本（01 + 02）；
     2) 已执行 09_migration.sql 完成迁移；
     3) Part 8（越权）另需先执行 08_app_db.sql（建 login_app / u_app / db_app）。

   说明：本脚本不开启全局 XACT_ABORT，对「预期失败」的语句用 TRY/CATCH
        逐个捕获并打印 [PASS]/[FAIL]，便于人工核对，不因预期报错中断。
   ============================================================ */

USE CampusCoffee;
GO

/* ============================================================
   Part 1  关键标识（主码 / 候选码 / 唯一性）
   ============================================================ */

-- 1.1 候选码唯一性：各唯一键不应有重复（以下查询全部应返回 0 行）
SELECT N'username 重复'  AS [检查], COUNT(*) AS [违规行数]
FROM (SELECT username FROM dbo.users GROUP BY username HAVING COUNT(*) > 1) t
UNION ALL
SELECT N'phone 重复', COUNT(*) FROM (SELECT phone FROM dbo.users GROUP BY phone HAVING COUNT(*) > 1) t
UNION ALL
SELECT N'product_name 重复', COUNT(*) FROM (SELECT product_name FROM dbo.products GROUP BY product_name HAVING COUNT(*) > 1) t
UNION ALL
SELECT N'order_no 重复', COUNT(*) FROM (SELECT order_no FROM dbo.orders GROUP BY order_no HAVING COUNT(*) > 1) t
UNION ALL
SELECT N'employees.user_id 重复', COUNT(*) FROM (SELECT user_id FROM dbo.employees WHERE user_id IS NOT NULL GROUP BY user_id HAVING COUNT(*) > 1) t;
GO

-- 1.2 employees ↔ users 为 1:1（员工数 = 3，且 user_id 非空、无重复）
SELECT COUNT(*) AS [员工数], COUNT(user_id) AS [有账号员工数],
       COUNT(DISTINCT user_id) AS [去重账号数]
FROM dbo.employees;
GO

-- 1.3 关键标识抽样（预期：4 张订单号、5 名用户、4 个角色）
SELECT (SELECT COUNT(DISTINCT order_no) FROM dbo.orders)   AS [订单号数],
       (SELECT COUNT(DISTINCT username) FROM dbo.users)     AS [用户数],
       (SELECT COUNT(*) FROM dbo.roles)                     AS [角色数];
GO

/* ============================================================
   Part 2  关系映射
   ============================================================ */

-- 2.1 用户 → 角色 → 权限 链路（预期 7 行）
SELECT u.username, r.role_name, p.permission_name
FROM dbo.users            u
JOIN dbo.user_roles       ur ON u.user_id  = ur.user_id
JOIN dbo.roles            r  ON ur.role_id = r.role_id
JOIN dbo.role_permissions rp ON r.role_id  = rp.role_id
JOIN dbo.permissions      p  ON rp.permission_id = p.permission_id
ORDER BY u.username, p.permission_name;
GO

-- 2.2 员工 → 门店 → 登录账号（预期 3 行，王强 ↔ wangqiang ↔ 宿舍区店）
SELECT e.name, e.position, s.store_name, u.username
FROM dbo.employees e
JOIN dbo.stores   s ON e.store_id = s.store_id
JOIN dbo.users    u ON e.user_id  = u.user_id
ORDER BY e.employee_id;
GO

-- 2.3 商品 → 分类 → 规格（预期 3 商品、4 SKU）
SELECT p.product_name, c.category_name, COUNT(k.sku_id) AS [规格数]
FROM dbo.products   p
JOIN dbo.categories c ON p.category_id = c.category_id
LEFT JOIN dbo.skus  k ON k.product_id  = p.product_id
GROUP BY p.product_name, c.category_name
ORDER BY p.product_name;
GO

-- 2.4 订单 → 明细（预期 4 订单、5 明细行）
SELECT o.order_no, COUNT(oi.order_item_id) AS [明细行数]
FROM dbo.orders o
LEFT JOIN dbo.order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_no
ORDER BY o.order_no;
GO

/* ============================================================
   Part 3  订单金额自洽（total_amount = Σ subtotal）
   ============================================================ */

-- 预期返回 0 行：不存在订单总额与明细小计之和不等的情况
SELECT o.order_id, o.total_amount AS [订单总额], SUM(oi.subtotal) AS [明细合计]
FROM dbo.orders o
JOIN dbo.order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.total_amount
HAVING o.total_amount <> SUM(oi.subtotal);
GO

/* ============================================================
   Part 4  商品销量 / 销售额（与迁移前基准一致）
   ============================================================ */

-- 预期：拿铁咖啡 销量 4 / 销售额 66.00；美式咖啡 销量 1 / 销售额 12.00
SELECT oi.product_name AS [商品],
       SUM(oi.quantity) AS [销量],
       SUM(oi.subtotal) AS [销售额]
FROM dbo.order_items oi
JOIN dbo.orders o ON oi.order_id = o.order_id
WHERE o.status <> N'已取消'
GROUP BY oi.product_name
ORDER BY [销售额] DESC;
GO

/* ============================================================
   Part 5  库存
   ============================================================ */

-- 5.1 库存总量（预期 7 行 SKU×门店）
SELECT COUNT(*) AS [库存记录数], SUM(quantity) AS [库存总量]
FROM dbo.inventory;
GO

-- 5.2 低库存（库存 < 10；预期 1 行：大杯/冰 · 宿舍区店 · 8）
SELECT s.store_name AS [门店], p.product_name AS [商品], k.sku_name AS [规格], i.quantity AS [库存]
FROM dbo.inventory i
JOIN dbo.skus     k ON i.sku_id    = k.sku_id
JOIN dbo.products p ON k.product_id = p.product_id
JOIN dbo.stores   s ON i.store_id  = s.store_id
WHERE i.quantity < 10
ORDER BY i.quantity;
GO

/* ============================================================
   Part 6  角色权限
   ============================================================ */

-- 6.1 角色-权限映射（预期 4 行）
SELECT r.role_name, p.permission_name
FROM dbo.roles            r
JOIN dbo.role_permissions rp ON r.role_id  = rp.role_id
JOIN dbo.permissions      p  ON rp.permission_id = p.permission_id
ORDER BY r.role_name, p.permission_name;
GO

-- 6.2 应用账号 db_app 的授权（需先执行 08_app_db.sql；预期列出 products/skus/inventory/orders/order_items 的写入权限）
SELECT p.name AS [角色], perm.permission_name AS [权限], OBJECT_NAME(perm.major_id) AS [对象]
FROM sys.database_permissions perm
JOIN sys.database_principals p ON p.principal_id = perm.grantee_principal_id
WHERE p.name = N'db_app'
ORDER BY [对象], [权限];
GO

/* ============================================================
   Part 7  合法性验证
   ============================================================ */

-- 7.1 合法写入成功（新增商品 → 核对 → 删除还原）
BEGIN TRY
    DELETE FROM dbo.products WHERE product_name = N'回归测试商品';  -- 清理残留
    INSERT INTO dbo.products (category_id, product_name, description, status)
    VALUES (1, N'回归测试商品', N'回归用临时商品', N'上架');
    IF EXISTS (SELECT 1 FROM dbo.products WHERE product_name = N'回归测试商品')
        PRINT N'[PASS] 合法写入成功：新增商品可查询到。';
    ELSE
        PRINT N'[FAIL] 合法写入失败：新增商品未查到。';
    DELETE FROM dbo.products WHERE product_name = N'回归测试商品';  -- 还原
END TRY
BEGIN CATCH
    PRINT N'[FAIL] 合法写入异常：' + ERROR_MESSAGE();
END CATCH;
GO

-- 7.2 非法外码被拒绝（order_items.sku_id 指向不存在的 9999，预期报错 547）
BEGIN TRY
    INSERT INTO dbo.order_items (order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal)
    VALUES (1, 9999, N'不存在', N'不存在', 1.00, 1, 1.00);
    PRINT N'[FAIL] 非法外码未被拒绝！';
END TRY
BEGIN CATCH
    PRINT N'[PASS] 非法外码被拒绝，错误号 ' + CONVERT(VARCHAR, ERROR_NUMBER());
END CATCH;
GO

-- 7.3 非法数量被拒绝（order_items.quantity = 0，预期报错 547）
BEGIN TRY
    INSERT INTO dbo.order_items (order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal)
    VALUES (1, 1, N'拿铁咖啡', N'中杯/热', 15.00, 0, 0.00);
    PRINT N'[FAIL] 非法数量未被拒绝！';
END TRY
BEGIN CATCH
    PRINT N'[PASS] 非法数量被拒绝，错误号 ' + CONVERT(VARCHAR, ERROR_NUMBER());
END CATCH;
GO

/* ============================================================
   Part 8  越权操作失败（需先执行 08_app_db.sql）
   ============================================================ */

-- 以应用账号 u_app 尝试读取未授权的表（employees 未授 SELECT，预期报错 229）
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'u_app')
BEGIN
    EXECUTE AS USER = N'u_app';
    BEGIN TRY
        SELECT employee_id, name FROM dbo.employees;   -- db_app 未授权
        PRINT N'[FAIL] 越权读取 employees 未被拒绝！';
    END TRY
    BEGIN CATCH
        PRINT N'[PASS] 越权读取被拒绝，错误号 ' + CONVERT(VARCHAR, ERROR_NUMBER());
    END CATCH;

    BEGIN TRY
        CREATE TABLE dbo.t_越权测试 (x INT);            -- 无 DDL 权限
        PRINT N'[FAIL] 越权 DDL 未被拒绝！';
    END TRY
    BEGIN CATCH
        PRINT N'[PASS] 越权 DDL 被拒绝，错误号 ' + CONVERT(VARCHAR, ERROR_NUMBER());
    END CATCH;
    REVERT;
END
ELSE
    PRINT N'[跳过] 未找到 u_app，请先执行 08_app_db.sql 再跑越权用例。';
GO

/* ============================================================
   Part 9  行数变化说明与结论
   ============================================================
   本次迁移无表拆分/合并，故无「拆表导致的合理行数变化」。
   唯一行数变化来自数据迁移（给无账号员工回填账号）：

       表          迁移前(v0.1)   迁移后(v1.0)   差异说明
       users            4             5         +1：新增 wangqiang
       user_roles       4             5         +1：wangqiang 授「店员」
       employees        3             3         不变（王强 user_id NULL→5）
       其余全部表        —             —         不变

   结论：迁移前后订单明细(5行)、商品销量(拿铁4/66、美式1/12)、
         库存(低库存1行) 完全一致，证明迁移只调整了账号/员工归属，
         未改变交易、商品、库存等业务含义。
   ============================================================ */
