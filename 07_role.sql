/* ============================================================
   07_role.sql —— 角色与权限（最小权限原则）
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   前提：已执行 01_create_database.sql 与 02_insert_sample_data.sql。

   演示流程：创建数据库角色 → 按角色授权 / 拒绝 → 建登录与用户
             → 正常操作成功（对照）→ 越权操作失败（证据）。

   注意：
   1) CREATE LOGIN 需要 sysadmin 权限（课程环境通常以 sa 或本机管理员登录）；
   2) 若服务器为「仅 Windows 身份验证」，无法创建 SQL 登录，
      可改用现有 Windows 登录/用户做演示；
   3) 本文件含 CREATE LOGIN/USER，重复执行前需先执行第 0 部分的重置语句；
   4) 第 9 部分「越权验证」会因权限不足而报错（消息 229）——这正是预期结果。
   ============================================================ */

USE CampusCoffee;
GO

-- ===== 0. 重置（如需完整重跑本文件，逐行取消注释后执行） =====
-- DROP USER IF EXISTS u_customer;
-- DROP USER IF EXISTS u_staff;
-- DROP LOGIN IF EXISTS login_customer;
-- DROP LOGIN IF EXISTS login_staff;
-- ALTER ROLE db_owner DROP MEMBER db_admin;
-- DROP ROLE IF EXISTS db_customer;
-- DROP ROLE IF EXISTS db_staff;
-- DROP ROLE IF EXISTS db_manager;
-- DROP ROLE IF EXISTS db_admin;
GO

-- ===== 1. 创建数据库角色（对应第一周识别的业务角色） =====
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'db_customer') CREATE ROLE db_customer;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'db_staff')    CREATE ROLE db_staff;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'db_manager')  CREATE ROLE db_manager;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'db_admin')    CREATE ROLE db_admin;
GO

/* ===== 2. 授权：顾客（浏览商品、下自己的单、评价、领券、查积分） =====
   设计边界说明：数据库权限只到「表 / 列」粒度，表达不了「只能看自己的订单」
   这种行级条件；行级过滤（WHERE user_id = 当前登录用户）由应用层实现，
   这一点在阶段报告里有明确说明。 */
GRANT SELECT ON dbo.categories TO db_customer;
GRANT SELECT ON dbo.products   TO db_customer;
GRANT SELECT ON dbo.skus       TO db_customer;
GRANT SELECT ON dbo.stores     TO db_customer;
GRANT SELECT ON dbo.coupons    TO db_customer;

GRANT SELECT, INSERT ON dbo.orders      TO db_customer;   -- 下单、查订单
GRANT UPDATE ON dbo.orders (status)     TO db_customer;   -- 只允许改状态（取消订单），不能改金额、所属人
GRANT SELECT, INSERT ON dbo.order_items TO db_customer;   -- 加购转明细
GRANT INSERT ON dbo.coupon_claims TO db_customer;         -- 领券
GRANT INSERT ON dbo.reviews       TO db_customer;         -- 评价

-- 列级权限：顾客只看得到账号的公开字段
GRANT SELECT ON dbo.users (user_id, username, points_balance) TO db_customer;
DENY  SELECT ON dbo.users (password_hash) TO db_customer;  -- DENY 优先于任何 GRANT，密码哈希不可见
GO

-- ===== 3. 授权：店员（查看订单/库存，改订单状态、扣库存、核销） =====
GRANT SELECT ON dbo.orders       TO db_staff;
GRANT SELECT ON dbo.order_items  TO db_staff;
GRANT SELECT ON dbo.inventory    TO db_staff;
GRANT SELECT ON dbo.pickup_codes TO db_staff;

GRANT SELECT ON dbo.products   TO db_staff;
GRANT SELECT ON dbo.skus       TO db_staff;
GRANT SELECT ON dbo.categories TO db_staff;
GRANT SELECT ON dbo.stores     TO db_staff;
GRANT SELECT ON dbo.reviews    TO db_staff;

-- 店员需要联系顾客，所以可以看用户的基本信息（同样不含密码哈希）
GRANT SELECT ON dbo.users (user_id, username, phone) TO db_staff;
DENY  SELECT ON dbo.users (password_hash) TO db_staff;

GRANT UPDATE ON dbo.orders (status) TO db_staff;                                          -- 只改订单状态
GRANT UPDATE ON dbo.inventory (quantity) TO db_staff;                                     -- 只改库存数量
GRANT UPDATE ON dbo.pickup_codes (status, verify_employee_id, verified_at) TO db_staff;   -- 核销
GO

-- ===== 4. 授权：店长（维护商品/库存/优惠，审批退款） =====
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.products  TO db_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.skus      TO db_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.inventory TO db_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.coupons   TO db_manager;

GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.stores    TO db_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.employees TO db_manager;

GRANT SELECT ON dbo.orders        TO db_manager;
GRANT SELECT ON dbo.order_items   TO db_manager;
GRANT SELECT ON dbo.reviews       TO db_manager;
GRANT SELECT ON dbo.coupon_claims TO db_manager;
GRANT SELECT ON dbo.users (user_id, username, phone, email, points_balance) TO db_manager;
DENY  SELECT ON dbo.users (password_hash) TO db_manager;

GRANT UPDATE ON dbo.orders (status) TO db_manager;   -- 审批退款 / 推进状态
GO

-- ===== 5. 授权：系统管理员（数据库层最高权限） =====
IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON rm.role_principal_id  = r.principal_id
    JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
    WHERE r.name = N'db_owner' AND m.name = N'db_admin')
    ALTER ROLE db_owner ADD MEMBER db_admin;
GO

-- ===== 6. 权限总览（作为「授权确实生效」的证据） =====
SELECT p.name AS [角色], perm.state_desc AS [授权类型], perm.permission_name AS [权限],
       perm.class_desc AS [粒度], OBJECT_NAME(perm.major_id) AS [对象]
FROM sys.database_permissions perm
JOIN sys.database_principals p ON perm.grantee_principal_id = p.principal_id
WHERE p.name IN (N'db_customer', N'db_staff', N'db_manager', N'db_admin')
ORDER BY p.name, OBJECT_NAME(perm.major_id), perm.permission_name;
GO

-- ===== 7. 创建登录与数据库用户（示例，密码请自行修改） =====
-- 用 IF NOT EXISTS 保护，重复执行不会报错
-- 说明：CREATE LOGIN 的存在性检查在批处理编译期完成，直接用 IF NOT EXISTS 包住
-- 拦不住重复创建；改用 EXEC(动态 SQL) 把创建推迟到运行时，本文件才可反复执行。
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_customer')
    EXEC(N'CREATE LOGIN login_customer WITH PASSWORD = N''Customer@123'', CHECK_POLICY = OFF;');
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'u_customer')
    CREATE USER u_customer FOR LOGIN login_customer;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON rm.role_principal_id  = r.principal_id
    JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
    WHERE r.name = N'db_customer' AND m.name = N'u_customer')
    ALTER ROLE db_customer ADD MEMBER u_customer;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_staff')
    EXEC(N'CREATE LOGIN login_staff WITH PASSWORD = N''Staff@123'', CHECK_POLICY = OFF;');
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'u_staff')
    CREATE USER u_staff FOR LOGIN login_staff;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON rm.role_principal_id  = r.principal_id
    JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
    WHERE r.name = N'db_staff' AND m.name = N'u_staff')
    ALTER ROLE db_staff ADD MEMBER u_staff;
GO

/* ============================================================
   Part 8  正常操作：有权限，应当成功（与下面的越权失败做对照）
   ============================================================ */

-- ① 顾客浏览在售商品 —— 预期成功，返回商品列表
EXECUTE AS USER = N'u_customer';
SELECT product_id, product_name, status FROM dbo.products;
REVERT;
GO

-- ② 顾客查看自己的账号信息（不含密码哈希）—— 预期成功
EXECUTE AS USER = N'u_customer';
SELECT user_id, username, points_balance FROM dbo.users WHERE user_id = 1;
REVERT;
GO

-- ③ 店员查询待取餐的订单 —— 预期成功
EXECUTE AS USER = N'u_staff';
SELECT order_id, order_no, status FROM dbo.orders;
REVERT;
GO

/* ============================================================
   Part 9  越权操作：无权限，应当失败
   ★ 以下每条都应报错（消息 229）。逐条单独执行并截图。
   ============================================================ */

PRINT N'【越权①】顾客想改商品价格 —— 预期：拒绝 UPDATE 权限（消息 229）';
GO
EXECUTE AS USER = N'u_customer';
UPDATE dbo.skus SET price = 1.00 WHERE sku_id = 1;
REVERT;
GO

PRINT N'【越权②】顾客想改订单金额（订单表只有 status 列的 UPDATE 权限）—— 预期：拒绝';
GO
EXECUTE AS USER = N'u_customer';
UPDATE dbo.orders SET total_amount = 0.01 WHERE order_id = 1;
REVERT;
GO

PRINT N'【越权③】店员想查看用户密码哈希 —— 预期：拒绝 SELECT 权限（列级 DENY）';
GO
EXECUTE AS USER = N'u_staff';
SELECT password_hash FROM dbo.users;
REVERT;
GO

PRINT N'【越权④】店员想删除订单 —— 预期：拒绝 DELETE 权限';
GO
EXECUTE AS USER = N'u_staff';
DELETE FROM dbo.orders WHERE order_id = 2;
REVERT;
GO
