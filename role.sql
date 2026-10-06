/* ============================================================
   role.sql —— week4 角色权限（数据库角色 + 授权）
   ============================================================
   演示：创建数据库角色 → 授权/拒绝 → 创建登录与用户 → 越权操作失败。

   注意：
   1) CREATE LOGIN 需要 sysadmin 权限（课程环境通常以 sa 登录）；
   2) 若服务器为「仅 Windows 身份验证」，无法创建 SQL 登录，
      可改用现有 Windows 登录/用户做演示；
   3) 本文件含 CREATE LOGIN/USER，重复执行前需先 DROP 再执行；
   4) 第 7 部分「越权验证」会因无权限而报错（消息 229）——这正是预期结果。
   ============================================================ */

USE CampusCoffee;
GO

-- ===== 0. 重置（如需完整重跑本文件，先取消注释执行下面几行） =====
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

-- ===== 1. 创建数据库角色（对应业务角色） =====
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'db_customer') CREATE ROLE db_customer;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'db_staff')    CREATE ROLE db_staff;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'db_manager')  CREATE ROLE db_manager;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'db_admin')    CREATE ROLE db_admin;
GO

-- ===== 2. 授权：顾客（浏览商品、下自己的单、评价、查自己的积分） =====
GRANT SELECT ON dbo.categories TO db_customer;
GRANT SELECT ON dbo.products   TO db_customer;
GRANT SELECT ON dbo.skus       TO db_customer;
GRANT SELECT ON dbo.stores     TO db_customer;
GRANT SELECT ON dbo.coupons    TO db_customer;

GRANT SELECT, INSERT, UPDATE ON dbo.orders       TO db_customer;
GRANT SELECT, INSERT         ON dbo.order_items  TO db_customer;
GRANT INSERT                 ON dbo.coupon_claims TO db_customer;
GRANT INSERT                 ON dbo.reviews       TO db_customer;

-- 列级权限：顾客只能看自己账号的公开字段，不能看密码哈希
GRANT SELECT ON dbo.users (user_id, username, points_balance) TO db_customer;
DENY  SELECT ON dbo.users (password_hash) TO db_customer;
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

GRANT UPDATE ON dbo.orders (status) TO db_staff;                                  -- 改订单状态
GRANT UPDATE ON dbo.inventory (quantity) TO db_staff;                             -- 扣库存
GRANT UPDATE ON dbo.pickup_codes (status, verify_employee_id, verified_at) TO db_staff; -- 核销
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

GRANT UPDATE ON dbo.orders (status) TO db_manager;                                -- 审批退款/改状态
GO

-- ===== 5. 授权：系统管理员（全库管理） =====
ALTER ROLE db_owner ADD MEMBER db_admin;
GO

-- ===== 6. 创建登录与数据库用户（示例，密码请自行修改） =====
CREATE LOGIN login_customer WITH PASSWORD = N'Customer@123', CHECK_POLICY = OFF;
CREATE USER  u_customer FOR LOGIN login_customer;
ALTER ROLE db_customer ADD MEMBER u_customer;

CREATE LOGIN login_staff WITH PASSWORD = N'Staff@123', CHECK_POLICY = OFF;
CREATE USER  u_staff FOR LOGIN login_staff;
ALTER ROLE db_staff ADD MEMBER u_staff;
GO

-- ===== 7. 越权操作验证（预期失败） =====
-- ① 顾客尝试改商品价格 → 无 UPDATE 权限，应报错（消息 229）
EXECUTE AS USER = N'u_customer';
UPDATE dbo.skus SET price = 1.00 WHERE sku_id = 1;
REVERT;
GO

-- ② 店员尝试查看用户密码哈希 → 列级 DENY，应报错（消息 229）
EXECUTE AS USER = N'u_staff';
SELECT password_hash FROM dbo.users;
REVERT;
GO
