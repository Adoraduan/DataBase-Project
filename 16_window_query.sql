/* ============================================================
   16_window_query.sql —— 第 11 周 窗口函数（排名 / 累计值 / 移动平均）
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   窗口函数不减少原始行数，而是在每一行旁边增加统计结果。
   本文件各查询的「排序字段」「窗口范围」均在注释中说明。

   执行前提：已执行 01 → 12_week10_12_schema.sql → 02
   ============================================================ */

USE CampusCoffee;
GO

/* ------------------------------------------------------------
   1. 排名查询
   业务含义：按「销售金额（成交）」给商品排名。
   - RANK / DENSE_RANK 保留并列（并列时 RANK 跳号、DENSE_RANK 不跳号）；
   - ROW_NUMBER 用 product_id 打破并列，保证名次唯一。
   排序字段：销售金额 DESC。
   ------------------------------------------------------------ */
SELECT p.product_id,
       p.product_name,
       SUM(oi.quantity)      AS sale_quantity,
       SUM(oi.actual_amount) AS sale_amount,
       RANK()       OVER (ORDER BY SUM(oi.actual_amount) DESC)               AS rank_amount,
       DENSE_RANK() OVER (ORDER BY SUM(oi.actual_amount) DESC)               AS dense_rank_amount,
       ROW_NUMBER() OVER (ORDER BY SUM(oi.actual_amount) DESC, p.product_id) AS row_num
FROM dbo.order_items oi
JOIN dbo.orders   o ON o.order_id = oi.order_id
JOIN dbo.skus     k ON k.sku_id   = oi.sku_id
JOIN dbo.products p ON p.product_id = k.product_id
WHERE o.status <> N'已取消'
GROUP BY p.product_id, p.product_name
ORDER BY rank_amount;
GO

/* ------------------------------------------------------------
   2. 累计值查询
   业务含义：按「下单日期」累计销售金额，观察销量逐日累计走势。
   排序字段：下单日期；窗口：当日及之前全部行（UNBOUNDED PRECEDING → CURRENT ROW）。
   ------------------------------------------------------------ */
WITH daily AS (
    SELECT CAST(o.created_at AS DATE) AS order_day,
           SUM(oi.actual_amount)      AS day_amount,
           SUM(oi.quantity)           AS day_quantity
    FROM dbo.order_items oi
    JOIN dbo.orders o ON o.order_id = oi.order_id
    WHERE o.status <> N'已取消'
    GROUP BY CAST(o.created_at AS DATE)
)
SELECT order_day,
       day_amount,
       day_quantity,
       SUM(day_amount) OVER (ORDER BY order_day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_amount
FROM daily
ORDER BY order_day;
GO

/* ------------------------------------------------------------
   3. 移动平均查询（最近 3 天）
   业务含义：含当日在内的最近 3 个「有销售的日期」的日均销售金额，
            用于观察短期销售波动。
   排序字段：下单日期；窗口大小 = 3（ROWS BETWEEN 2 PRECEDING AND CURRENT ROW）。
   ------------------------------------------------------------ */
WITH daily AS (
    SELECT CAST(o.created_at AS DATE) AS order_day,
           SUM(oi.actual_amount)      AS day_amount
    FROM dbo.order_items oi
    JOIN dbo.orders o ON o.order_id = oi.order_id
    WHERE o.status <> N'已取消'
    GROUP BY CAST(o.created_at AS DATE)
)
SELECT order_day,
       day_amount,
       AVG(day_amount) OVER (ORDER BY order_day ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3day
FROM daily
ORDER BY order_day;
GO

/* ------------------------------------------------------------
   附：最近 3 笔订单的移动平均（另一种窗口口径示例）
   排序字段：订单号；窗口大小 = 3。
   ------------------------------------------------------------ */
SELECT order_id,
       total_amount,
       AVG(total_amount) OVER (ORDER BY order_id ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3orders
FROM dbo.orders
WHERE status <> N'已取消'
ORDER BY order_id;
GO
