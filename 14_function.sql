/* ============================================================
   14_function.sql —— 第 10 周 函数（纯计算 / 查询）
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   对象清单：
     ① fn_reorder_quantity   补货量（标量函数，返回目标库存 - 当前库存，非负）
     ② fn_discount_rate      折扣率（标量函数，按订单金额分档）
     ③ fn_discount_amount    折扣金额（标量函数，金额 × (1 - 折扣率)）
     ④ fn_sales_summary      销售汇总（内联表值函数，可在 SELECT 中调用）

   约定：
     - 函数适合「补货量、折扣、销售汇总」等计算/查询；改数据的业务放 13_procedure.sql。
     - 商品不存在等无法计算的情况：标量函数返回 NULL（明确处理），且返回值不为负。

   执行前提：已执行 01 → 12_week10_12_schema.sql → 02
   ============================================================ */

USE CampusCoffee;
GO

/* ------------------------------------------------------------
   ① 补货量函数
   返回：目标库存 - 当前库存（结果 >= 0）；已达目标返回 0；
         无库存记录或未配置目标库存返回 NULL（明确处理，不为负）。
   ------------------------------------------------------------ */
GO
CREATE OR ALTER FUNCTION dbo.fn_reorder_quantity
(
    @sku_id          INT,
    @store_id        INT,
    @target_quantity INT = NULL   -- 可覆盖 inventory.target_quantity
)
RETURNS INT
AS
BEGIN
    DECLARE @current INT, @target INT, @result INT;

    SELECT @current = quantity, @target = target_quantity
    FROM dbo.inventory
    WHERE sku_id = @sku_id AND store_id = @store_id;

    IF @current IS NULL
        RETURN NULL;                       -- 商品/门店无库存记录 → 明确返回 NULL

    IF @target_quantity IS NOT NULL
        SET @target = @target_quantity;    -- 显式指定目标库存优先

    IF @target IS NULL
        RETURN NULL;                       -- 未配置目标库存 → 明确返回 NULL

    SET @result = @target - @current;
    IF @result < 0 SET @result = 0;        -- 已达目标返回 0，保证非负

    RETURN @result;
END
GO

/* ------------------------------------------------------------
   ② 折扣率函数（按订单金额分档，规则为教学示例，可替换）
   档位：>=100 → 0.85；>=50 → 0.90；>=30 → 0.95；其余 → 1.00（无折扣）。
   注：任务允许按「会员身份 / 订单金额 / 商品分类」任一维度；本项目取订单金额，
       会员身份与商品分类维度可用同构函数扩展。
   ------------------------------------------------------------ */
GO
CREATE OR ALTER FUNCTION dbo.fn_discount_rate(@order_amount DECIMAL(10,2))
RETURNS DECIMAL(5,4)
AS
BEGIN
    IF @order_amount IS NULL OR @order_amount < 0
        RETURN NULL;

    RETURN CASE
        WHEN @order_amount >= 100 THEN 0.85
        WHEN @order_amount >= 50  THEN 0.90
        WHEN @order_amount >= 30  THEN 0.95
        ELSE 1.00
    END;
END
GO

/* ------------------------------------------------------------
   ③ 折扣金额函数：金额 × (1 - 折扣率)，保留两位小数。
   ------------------------------------------------------------ */
GO
CREATE OR ALTER FUNCTION dbo.fn_discount_amount
(
    @amount        DECIMAL(10,2),
    @discount_rate DECIMAL(5,4)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    IF @amount IS NULL OR @amount < 0
       OR @discount_rate IS NULL OR @discount_rate <= 0 OR @discount_rate > 1
        RETURN NULL;

    RETURN ROUND(@amount * (1 - @discount_rate), 2);
END
GO

/* ------------------------------------------------------------
   ④ 销售汇总表值函数（内联 TVF，可在 SELECT 中调用）
   返回：商品编号、商品名称、销售数量、销售金额（成交）、订单数量。
   口径：按下单时间，闭区间，排除「已取消」订单。
   ------------------------------------------------------------ */
GO
CREATE OR ALTER FUNCTION dbo.fn_sales_summary
(
    @start_date DATETIME,
    @end_date   DATETIME
)
RETURNS TABLE
AS
RETURN
(
    SELECT p.product_id,
           p.product_name,
           SUM(oi.quantity)      AS sale_quantity,
           SUM(oi.actual_amount) AS sale_amount,
           COUNT(DISTINCT oi.order_id) AS order_count
    FROM dbo.order_items oi
    JOIN dbo.orders   o ON o.order_id = oi.order_id
    JOIN dbo.skus     k ON k.sku_id   = oi.sku_id
    JOIN dbo.products p ON p.product_id = k.product_id
    WHERE o.status <> N'已取消'
      AND o.created_at >= @start_date
      AND o.created_at <  DATEADD(day, 1, @end_date)
    GROUP BY p.product_id, p.product_name
);
GO

/* ============================================================
   调用与测试脚本（第 10 周）
   ============================================================ */

-- ① 补货量：已达目标 → 0（SKU1 门店1 当前 50，目标 50；第三参显式传 NULL = 用 inventory.target_quantity）
SELECT dbo.fn_reorder_quantity(1, 1, NULL) AS [补货量_门店1];

-- ② 补货量：不足 → 补到目标（SKU1 门店2 当前 10，目标 50 → 40）
SELECT dbo.fn_reorder_quantity(1, 2, NULL) AS [补货量_门店2];

-- ③ 补货量：显式指定目标库存 100（SKU1 门店2 当前 10 → 90）
SELECT dbo.fn_reorder_quantity(1, 2, 100) AS [补货量_指定目标100];

-- ④ 补货量：商品不存在 → NULL（不为负）
SELECT dbo.fn_reorder_quantity(999, 1, NULL) AS [补货量_不存在];

-- ⑤ 折扣率 / 折扣金额（金额 60 → 9 折；金额 20 → 无折扣）
SELECT dbo.fn_discount_rate(60) AS rate, dbo.fn_discount_amount(60, dbo.fn_discount_rate(60)) AS discount;
SELECT dbo.fn_discount_rate(20) AS rate, dbo.fn_discount_amount(20, dbo.fn_discount_rate(20)) AS discount;

-- ⑥ 销售汇总：在 SELECT 中调用表值函数
SELECT * FROM dbo.fn_sales_summary('2026-10-05', '2026-10-06');

-- ⑦ 销售汇总：无记录 → 空结果集
SELECT * FROM dbo.fn_sales_summary('2026-01-01', '2026-01-31');
GO
