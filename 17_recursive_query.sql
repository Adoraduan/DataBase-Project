/* ============================================================
   17_recursive_query.sql —— 第 12 周 层级递归查询（商品分类）
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   已有结构：categories(category_id, parent_id, category_name, sort_order)
             parent_id 自引用（父级分类编号，NULL = 根节点）。

   本脚本包含：样例层级数据（自包含、可重复执行） + 递归 CTE 查询 +
              根节点 / 中间节点 / 叶子节点 / 不存在编号 四类查询。

   层级关系（在基线 3 个分类上扩充）：
     咖啡(1, NULL)
       ├─ 拿铁系列(3, 1)  ── 焦糖拿铁(4, 3) / 燕麦拿铁(5, 3)
       └─ 美式系列(6, 1)  ── 冰美式(7, 6)
     甜点(2, NULL)
       └─ 芝士蛋糕类(8, 2) ── 轻乳酪蛋糕(9, 8)

   执行前提：已执行 01 → 12_week10_12_schema.sql → 02
   ============================================================ */

USE CampusCoffee;
GO

/* ---------- 1. 样例层级数据（幂等：先删本脚本插入的分类，再插入） ---------- */
-- 先删叶子，再删父类（遵守自引用外键）
DELETE FROM dbo.categories WHERE category_id IN (4, 5, 7, 9);
DELETE FROM dbo.categories WHERE category_id IN (6, 8);
GO

SET IDENTITY_INSERT dbo.categories ON;
INSERT INTO dbo.categories (category_id, parent_id, category_name, sort_order) VALUES
(4, 3, N'焦糖拿铁',   1),
(5, 3, N'燕麦拿铁',   2),
(6, 1, N'美式系列',   2),
(7, 6, N'冰美式',     1),
(8, 2, N'芝士蛋糕类', 1),
(9, 8, N'轻乳酪蛋糕', 1);
SET IDENTITY_INSERT dbo.categories OFF;
GO

/* ---------- 2. 递归 CTE 查询（封装为可复用的过程） ---------- */
GO
CREATE OR ALTER PROCEDURE dbo.usp_category_descendants
    @category_id INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH cat_cte AS (
        -- 起点：指定分类
        SELECT category_id, parent_id, category_name,
               0 AS lvl,
               CAST(category_name AS NVARCHAR(500)) AS path
        FROM dbo.categories
        WHERE category_id = @category_id

        UNION ALL

        -- 递归连接：子分类（终止条件 = 找不到子分类时自然结束）
        SELECT c.category_id, c.parent_id, c.category_name,
               p.lvl + 1,
               CAST(p.path + N' > ' + c.category_name AS NVARCHAR(500))
        FROM dbo.categories c
        JOIN cat_cte p ON c.parent_id = p.category_id
    )
    SELECT category_id, parent_id, category_name, lvl, path
    FROM cat_cte
    OPTION (MAXRECURSION 20);
END
GO

/* ---------- 3. 四类查询 ---------- */

-- ① 根节点：咖啡(1) 的全部后代（拿铁系列、美式系列及其孙节点）
EXEC dbo.usp_category_descendants @category_id = 1;
GO

-- ② 中间节点：拿铁系列(3)（焦糖拿铁、燕麦拿铁）
EXEC dbo.usp_category_descendants @category_id = 3;
GO

-- ③ 叶子节点：焦糖拿铁(4)（只有它自己，层级 0）
EXEC dbo.usp_category_descendants @category_id = 4;
GO

-- ④ 不存在的编号：999（空结果集）
EXEC dbo.usp_category_descendants @category_id = 999;
GO

-- 对照样例关系：列出全部新增分类，检查 parent_id 指向是否正确
SELECT category_id, parent_id, category_name, sort_order
FROM dbo.categories
WHERE category_id >= 4
ORDER BY category_id;
GO
