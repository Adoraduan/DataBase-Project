/* ============================================================
   13_procedure.sql —— 第 10 周 存储过程（会改变数据的业务）
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   对象清单：
     ① usp_sales_statistics       销售统计（按日期范围，含汇总与商品明细）
     ② usp_adjust_inventory       库存调整（校验 + 更新库存 + 写调整记录）
     ③ usp_complete_order         订单完成（下单即扣库存，此处只核验并置完成）
     ④ usp_apply_order_discount   订单折扣落库（调用 14_function.sql 的折扣函数）

   约定：
     - 过程适合「会改变数据」的业务；纯计算/查询放 14_function.sql。
     - 日期统计为闭区间 [开始, 结束]（结束日含当天，见各过程注释）。
     - 全部对象带参数、做输入检查与错误处理（THROW），可重复调用。

   执行前提：已执行 01_create_database.sql → 12_week10_12_schema.sql → 02_insert_sample_data.sql
   依赖说明：④ usp_apply_order_discount 内部调用 dbo.fn_discount_amount，
             该函数定义在 14_function.sql 中，故需先执行 14_function.sql 再执行本脚本。
   ============================================================ */

USE CampusCoffee;
GO
SET XACT_ABORT ON;
GO

/* ------------------------------------------------------------
   ① 销售统计存储过程
   输入：开始日期、结束日期；输出：订单数量 / 销售数量 / 销售金额 + 商品销售明细。
   口径：按下单时间 created_at 统计，排除「已取消」订单；日期为闭区间。
   无销售记录时汇总返回 0 并给出提示。
   ------------------------------------------------------------ */
GO
CREATE OR ALTER PROCEDURE dbo.usp_sales_statistics
    @start_date DATETIME,
    @end_date   DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- 输入检查
    IF @start_date IS NULL OR @end_date IS NULL
        THROW 50001, N'开始日期和结束日期不能为空', 1;
    IF @start_date > @end_date
        THROW 50002, N'开始日期不能晚于结束日期', 1;

    -- 汇总（成交金额口径）
    DECLARE @order_count   INT,
            @sale_quantity INT,
            @sale_amount   DECIMAL(10,2);

    SELECT @order_count   = COUNT(DISTINCT o.order_id),
           @sale_quantity = ISNULL(SUM(oi.quantity), 0),
           @sale_amount   = ISNULL(SUM(oi.actual_amount), 0)
    FROM dbo.orders o
    JOIN dbo.order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> N'已取消'
      AND o.created_at >= @start_date
      AND o.created_at <  DATEADD(day, 1, @end_date);

    IF @order_count = 0
        PRINT N'[提示] 指定日期范围内没有销售记录。';

    -- 结果 1：汇总
    SELECT @order_count   AS order_count,
           @sale_quantity AS sale_quantity,
           @sale_amount   AS sale_amount;

    -- 结果 2：商品销售明细
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
    ORDER BY sale_amount DESC;
END
GO

/* ------------------------------------------------------------
   ② 库存调整存储过程
   输入：商品编号、调整数量（正增负减）、调整原因、操作员工编号。
   拒绝：商品/门店/员工不存在、调整数量为 0、库存不足（减少后为负）。
   成功：更新库存并写入 inventory_adjustments 调整记录（同一事务）。
   ------------------------------------------------------------ */
GO
CREATE OR ALTER PROCEDURE dbo.usp_adjust_inventory
    @sku_id               INT,
    @store_id             INT,
    @adjust_quantity      INT,                 -- 正=增加，负=减少，不得为 0
    @reason               NVARCHAR(200) = NULL,
    @operator_employee_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.skus WHERE sku_id = @sku_id)
            THROW 50010, N'商品规格不存在', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.stores WHERE store_id = @store_id)
            THROW 50011, N'门店不存在', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = @operator_employee_id)
            THROW 50012, N'操作员工不存在', 1;
        IF @adjust_quantity = 0
            THROW 50013, N'调整数量不能为 0', 1;

        -- 读取当前库存（加锁，避免并发下先查后改）
        DECLARE @before INT, @after INT;
        SELECT @before = quantity
        FROM dbo.inventory WITH (UPDLOCK)
        WHERE sku_id = @sku_id AND store_id = @store_id;

        IF @before IS NULL
            THROW 50014, N'该商品在该门店没有库存记录', 1;

        SET @after = @before + @adjust_quantity;
        IF @after < 0
            THROW 50015, N'库存不足，调整后库存不能为负数', 1;

        -- 更新库存 + 写调整记录
        UPDATE dbo.inventory SET quantity = @after
        WHERE sku_id = @sku_id AND store_id = @store_id;

        INSERT INTO dbo.inventory_adjustments
            (sku_id, store_id, adjust_quantity, reason, operator_employee_id, quantity_before, quantity_after)
        VALUES
            (@sku_id, @store_id, @adjust_quantity, @reason, @operator_employee_id, @before, @after);

        COMMIT TRANSACTION;
        PRINT N'[完成] 库存调整成功：' + CAST(@before AS NVARCHAR) + N' → ' + CAST(@after AS NVARCHAR);
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   ③ 订单完成存储过程
   说明：本项目 v1.0 采用「下单即扣库存」，库存已在下单时扣减，
         因此本过程只做完整性核验并置为已完成，绝不重复扣库存。
   拒绝：订单不存在、状态非「待取餐」、无明细、金额不一致、已重复完成。
   成功：订单置已完成 + 取餐码核销 + 写操作日志（同一事务）。
   ------------------------------------------------------------ */
GO
CREATE OR ALTER PROCEDURE dbo.usp_complete_order
    @order_id             INT,
    @operator_employee_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.orders WHERE order_id = @order_id)
            THROW 50020, N'订单不存在', 1;

        DECLARE @status NVARCHAR(20);
        SELECT @status = status FROM dbo.orders WITH (UPDLOCK) WHERE order_id = @order_id;
        IF @status = N'已完成'
            THROW 50021, N'订单已经完成，不能重复完成', 1;
        IF @status <> N'待取餐'
            THROW 50022, N'只有「待取餐」订单可以完成', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.order_items WHERE order_id = @order_id)
            THROW 50023, N'订单没有明细，不能完成', 1;

        IF (SELECT total_amount FROM dbo.orders WHERE order_id = @order_id)
           <> (SELECT ISNULL(SUM(actual_amount), 0) FROM dbo.order_items WHERE order_id = @order_id)
            THROW 50024, N'订单金额与明细成交金额不一致，不能完成', 1;

        -- 置为已完成
        UPDATE dbo.orders SET status = N'已完成', completed_at = GETDATE()
        WHERE order_id = @order_id;

        -- 核销取餐码
        UPDATE dbo.pickup_codes
        SET status = N'已核销', verify_employee_id = @operator_employee_id, verified_at = GETDATE()
        WHERE order_id = @order_id;

        -- 写操作日志
        INSERT INTO dbo.operation_logs (operator_id, [action], object_type, object_id, detail)
        SELECT e.user_id, N'完成订单', N'order', @order_id, N'订单 ' + o.order_no + N' 已完成'
        FROM dbo.orders o
        JOIN dbo.employees e ON e.employee_id = @operator_employee_id
        WHERE o.order_id = @order_id;

        COMMIT TRANSACTION;
        PRINT N'[完成] 订单 ' + CAST(@order_id AS NVARCHAR) + N' 已完成。';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   ④ 订单折扣应用存储过程（折扣率与金额由 14_function.sql 的函数计算）
   输入：订单编号、折扣率（如 0.90 = 9 折，1.00 = 无折扣）。
   成功：逐明细写入 discount_rate / discount_amount，成交金额自动由计算列得出；
         订单级折扣总额与成交总额同步更新。
   ------------------------------------------------------------ */
GO
CREATE OR ALTER PROCEDURE dbo.usp_apply_order_discount
    @order_id      INT,
    @discount_rate DECIMAL(5,4)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.orders WHERE order_id = @order_id)
            THROW 50030, N'订单不存在', 1;
        IF @discount_rate IS NULL OR @discount_rate <= 0 OR @discount_rate > 1
            THROW 50031, N'折扣率必须在 (0, 1] 之间', 1;

        -- 逐明细写折扣率与折扣金额（成交金额 actual_amount 为计算列，自动更新）
        UPDATE dbo.order_items
        SET discount_rate   = @discount_rate,
            discount_amount = dbo.fn_discount_amount(subtotal, @discount_rate)
        WHERE order_id = @order_id;

        -- 订单级：折扣总额 + 成交总额
        UPDATE dbo.orders
        SET discount_amount = (SELECT ISNULL(SUM(discount_amount), 0) FROM dbo.order_items WHERE order_id = @order_id),
            total_amount    = (SELECT ISNULL(SUM(actual_amount), 0)    FROM dbo.order_items WHERE order_id = @order_id)
        WHERE order_id = @order_id;

        COMMIT TRANSACTION;
        PRINT N'[完成] 订单 ' + CAST(@order_id AS NVARCHAR) + N' 已应用折扣率 ' + CAST(@discount_rate AS NVARCHAR);
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ============================================================
   调用与测试脚本（第 10 周）
   说明：正常与异常用例分开；预期报错的用例用 TRY/CATCH 包裹，
         避免整段脚本因一次 THROW 中断。测试会改数据，跑完重跑 02 复位。
   ============================================================ */

-- ① 销售统计：正常（2026-10-05 ~ 10-06，闭区间含当天）
EXEC dbo.usp_sales_statistics @start_date = '2026-10-05', @end_date = '2026-10-06';
GO

-- ② 销售统计：无记录
EXEC dbo.usp_sales_statistics @start_date = '2026-01-01', @end_date = '2026-01-31';
GO

-- ③ 销售统计：非法日期（开始晚于结束）
BEGIN TRY
    EXEC dbo.usp_sales_statistics @start_date = '2026-10-06', @end_date = '2026-10-05';
END TRY
BEGIN CATCH
    PRINT N'[预期错误] ' + ERROR_MESSAGE();
END CATCH
GO

-- ④ 库存调整：正常（SKU 1 / 门店 1 增加 10）
EXEC dbo.usp_adjust_inventory @sku_id = 1, @store_id = 1, @adjust_quantity = 10,
                              @reason = N'人工盘点补录', @operator_employee_id = 2;
SELECT * FROM dbo.inventory_adjustments ORDER BY adjustment_id DESC;
GO

-- ⑤ 库存调整：库存不足（SKU 2 / 门店 2 现有 8，减少 999）
BEGIN TRY
    EXEC dbo.usp_adjust_inventory @sku_id = 2, @store_id = 2, @adjust_quantity = -999,
                                  @reason = N'测试', @operator_employee_id = 2;
END TRY
BEGIN CATCH
    PRINT N'[预期错误] ' + ERROR_MESSAGE();
END CATCH
GO

-- ⑥ 库存调整：调整数量为 0 / 商品不存在
BEGIN TRY
    EXEC dbo.usp_adjust_inventory @sku_id = 1, @store_id = 1, @adjust_quantity = 0,
                                  @operator_employee_id = 2;
END TRY
BEGIN CATCH
    PRINT N'[预期错误·数量为0] ' + ERROR_MESSAGE();
END CATCH
GO
BEGIN TRY
    EXEC dbo.usp_adjust_inventory @sku_id = 999, @store_id = 1, @adjust_quantity = 1,
                                  @operator_employee_id = 2;
END TRY
BEGIN CATCH
    PRINT N'[预期错误·商品不存在] ' + ERROR_MESSAGE();
END CATCH
GO

-- ⑦ 折扣：订单 3（待取餐，原价 18.00）应用 9 折
EXEC dbo.usp_apply_order_discount @order_id = 3, @discount_rate = 0.90;
SELECT order_id, product_name, sku_name, unit_price, quantity, subtotal,
       discount_rate, discount_amount, actual_amount
FROM dbo.order_items WHERE order_id = 3;
SELECT order_id, total_amount, discount_amount, status FROM dbo.orders WHERE order_id = 3;
GO

-- ⑧ 订单完成：正常（订单 3 待取餐，金额已核算一致）
EXEC dbo.usp_complete_order @order_id = 3, @operator_employee_id = 2;
SELECT order_id, status, completed_at FROM dbo.orders WHERE order_id = 3;
GO

-- ⑨ 订单完成：重复完成（应拒绝）
BEGIN TRY
    EXEC dbo.usp_complete_order @order_id = 3, @operator_employee_id = 2;
END TRY
BEGIN CATCH
    PRINT N'[预期错误·重复完成] ' + ERROR_MESSAGE();
END CATCH
GO
