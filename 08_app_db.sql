/* ============================================================
   08_app_db.sql —— Web 应用的数据库账号与演示密码
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   作用：
     1) 建应用专用登录 login_app、数据库用户 u_app 与角色 db_app；
     2) 只授予应用用到的表和操作（含 users.password_hash 的 SELECT，
        应用登录时要校验密码），不授予 DDL，也不加入 db_owner；
     3) 把演示账号的占位密码统一换成 PBKDF2 哈希，密码为 Campus@2026。

   前提：已执行 01、02；建议 06、07 也已执行。
   注意：CREATE LOGIN 需要 sysadmin 权限；如果服务器只开了 Windows 身份验证，
        改用 Windows 登录并在 .env 里换成 Trusted_Connection。
   本文件可重复执行。
   ============================================================ */

USE CampusCoffee;
GO

-- ===== 1. 应用角色与授权 =====
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'db_app')
    CREATE ROLE db_app;
GO

-- 读取：登录、鉴权、页面查询用到的表
GRANT SELECT ON dbo.users       TO db_app;
GRANT SELECT ON dbo.roles       TO db_app;
GRANT SELECT ON dbo.user_roles  TO db_app;
GRANT SELECT ON dbo.stores      TO db_app;
GRANT SELECT ON dbo.categories  TO db_app;
GRANT SELECT ON dbo.products    TO db_app;
GRANT SELECT ON dbo.skus        TO db_app;
GRANT SELECT ON dbo.inventory   TO db_app;
GRANT SELECT ON dbo.orders      TO db_app;
GRANT SELECT ON dbo.order_items TO db_app;
GO

-- 写入：商品 / 规格 / 库存
GRANT INSERT, UPDATE, DELETE ON dbo.products  TO db_app;
GRANT INSERT, UPDATE ON dbo.skus         TO db_app;
GRANT INSERT, UPDATE ON dbo.inventory    TO db_app;
GO

-- 写入：订单 / 明细（删除只开放给明细，订单走取消）
GRANT INSERT, UPDATE ON dbo.orders      TO db_app;
GRANT INSERT, UPDATE, DELETE ON dbo.order_items TO db_app;
GO

-- ===== 2. 应用登录与数据库用户 =====
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_app')
    EXEC(N'CREATE LOGIN login_app WITH PASSWORD = N''App@Campus2026'', CHECK_POLICY = OFF;');
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'u_app')
    CREATE USER u_app FOR LOGIN login_app;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members rm
    JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
    JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
    WHERE r.name = N'db_app' AND m.name = N'u_app')
    ALTER ROLE db_app ADD MEMBER u_app;
GO

-- ===== 3. 演示账号密码（统一 Campus@2026） =====
-- 样例数据里原来是占位串，应用登录前换成可校验的 PBKDF2 哈希
UPDATE dbo.users SET password_hash = N'pbkdf2:sha256:600000$fLp4hNKDpu3g1idy$d2abe2a140eecf0bb67521d4333a71b0678a7dc9e5313e18532fd08799cbed9f' WHERE username = N'alice';
UPDATE dbo.users SET password_hash = N'pbkdf2:sha256:600000$n75BBbNaiXmy3HIg$865af36f3608085599307e607687fa14e77f3ecdee2e6eb4396146779634b76a' WHERE username = N'bob';
UPDATE dbo.users SET password_hash = N'pbkdf2:sha256:600000$MLybTx17kx94qQLr$c488daf70025c9dabb5afb48dc5348c9ef8bdf22050a5af9242d9ff7a707380f' WHERE username = N'carol';
UPDATE dbo.users SET password_hash = N'pbkdf2:sha256:600000$IbPoqfKQPsgSx0Ld$7bcd579f0e823639b23b6256c8e7718daf7e1f9845a2a62d64a52e7a6ce575fe' WHERE username = N'admin';
UPDATE dbo.users SET password_hash = N'pbkdf2:sha256:600000$ROFMyjqNyCbVomIQ$a83c69fd3b8e92a83e28b0dfda51da4ba7b4da51b83a856636386176106650fd' WHERE username = N'wangqiang';
GO

-- ===== 4. 核对：应用账号拿到的权限 =====
SELECT p.name AS [角色], perm.permission_name AS [权限], OBJECT_NAME(perm.major_id) AS [对象]
FROM sys.database_permissions perm
JOIN sys.database_principals p ON p.principal_id = perm.grantee_principal_id
WHERE p.name = N'db_app'
ORDER BY [对象], [权限];
GO
