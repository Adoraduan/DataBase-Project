/* ============================================================
   18_order_transaction.sql —— 第 12 周 订单完成事务
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   业务口径（关键）：
     v1.0 Web 应用采用「下单即扣库存」——顾客下单时即在事务内扣减库存。
     因此本订单完成事务只做「校验 + 置已完成 + 核销取餐码 + 写日志」，
     绝不重复扣减库存，保证一次业务只扣减一次库存。

   事务边界：
     一次完成 = 更新订单状态 → 核销取餐码 → 写操作日志，三步要么全部提交、要么全部回滚。
     校验（不存在/已完成/无明细/金额不一致）在写数据之前执行；写数据之后失败则整体回滚。

   执行前提：已执行 01 → 12_week10_12_schema.sql → 02
   ============================================================ */

USE CampusCoffee;
GO
SET XACT_ABORT ON;
GO

/* ---------- 1. 测试数据准备（幂等复位） ---------- */
-- 复位订单 3 为「待取餐、金额一致、取餐码待核销」
UPDATE dbo.order_items SET discount_rate = 0, discount_amount = 0 WHERE order_id = 3;
UPDATE dbo.orders SET total_amount = 18, discount_amount = 0, status = N'待取餐', completed_at = NULL WHERE order_id = 3;
UPDATE dbo.pickup_codes SET status = N'待取餐', verified_at = NULL, verify_employee_id = NULL WHERE order_id = 3;
DELETE FROM dbo.operation_logs WHERE object_type = N'order' AND object_id = 3;

-- 初始状态（订单 / 取餐码 / 库存）
SELECT order_id, status, completed_at FROM dbo.orders WHERE order_id = 3;
SELECT pickup_id, order_id, status, verified_at FROM dbo.pickup_codes WHERE order_id = 3;
GO

/* ---------- 2. 订单完成事务（含提交/回滚） ---------- */
GO
CREATE OR ALTER PROCEDURE dbo.usp_order_complete_txn
    @order_id             INT,
    @operator_employee_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 校验① 订单存在
        IF NOT EXISTS (SELECT 1 FROM dbo.orders WHERE order_id = @order_id)
            THROW 50040, N'订单不存在', 1;

        -- 校验② 状态（已完成/非待取餐 拒绝）
        DECLARE @status NVARCHAR(20);
        SELECT @status = status FROM dbo.orders WITH (UPDLOCK) WHERE order_id = @order_id;
        IF @status = N'已完成' THROW 50041, N'订单已完成，不能重复完成', 1;
        IF @status <> N'待取餐' THROW 50042, N'只有「待取餐」订单可以完成', 1;

        -- 校验③ 有明细
        IF NOT EXISTS (SELECT 1 FROM dbo.order_items WHERE order_id = @order_id)
            THROW 50043, N'订单没有明细，不能完成', 1;

        -- 校验④ 金额核算
        IF (SELECT total_amount FROM dbo.orders WHERE order_id = @order_id)
           <> (SELECT ISNULL(SUM(actual_amount), 0) FROM dbo.order_items WHERE order_id = @order_id)
            THROW 50044, N'订单金额与明细成交金额不一致', 1;

        -- 校验⑤ 商品规格有效（下单即扣库存，此处只核验、不扣库存）
        IF EXISTS (
            SELECT 1 FROM dbo.order_items oi
            WHERE oi.order_id = @order_id
              AND oi.sku_id IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM dbo.skus k WHERE k.sku_id = oi.sku_id)
        )
            THROW 50045, N'订单含无效商品规格', 1;

        -- 写① 置为已完成
        UPDATE dbo.orders SET status = N'已完成', completed_at = GETDATE()
        WHERE order_id = @order_id;

        -- 写② 核销取餐码
        UPDATE dbo.pickup_codes
        SET status = N'已核销', verify_employee_id = @operator_employee_id, verified_at = GETDATE()
        WHERE order_id = @order_id;

        -- 写③ 操作日志
        INSERT INTO dbo.operation_logs (operator_id, [action], object_type, object_id, detail)
        SELECT e.user_id, N'完成订单', N'order', @order_id, N'订单完成事务：' + o.order_no
        FROM dbo.orders o
        JOIN dbo.employees e ON e.employee_id = @operator_employee_id
        WHERE o.order_id = @order_id;

        COMMIT TRANSACTION;
        PRINT N'[提交] 订单 ' + CAST(@order_id AS NVARCHAR) + N' 完成事务已提交。';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------- 3. 测试用例 ---------- */

-- T1 正常提交
EXEC dbo.usp_order_complete_txn @order_id = 3, @operator_employee_id = 2;
SELECT order_id, status, completed_at FROM dbo.orders WHERE order_id = 3;
SELECT pickup_id, order_id, status, verified_at FROM dbo.pickup_codes WHERE order_id = 3;
SELECT * FROM dbo.operation_logs WHERE object_type = N'order' AND object_id = 3;
GO

-- T2 重复调用（应拒绝，不重复完成）
BEGIN TRY
    EXEC dbo.usp_order_complete_txn @order_id = 3, @operator_employee_id = 2;
END TRY
BEGIN CATCH
    PRINT N'[预期错误·重复完成] ' + ERROR_MESSAGE();
END CATCH
GO

-- T3 订单不存在（应拒绝）
BEGIN TRY
    EXEC dbo.usp_order_complete_txn @order_id = 999, @operator_employee_id = 2;
END TRY
BEGIN CATCH
    PRINT N'[预期错误·不存在] ' + ERROR_MESSAGE();
END CATCH
GO

-- T4 无明细（应拒绝）：造一个无明细的待完成订单
INSERT INTO dbo.orders (order_no, user_id, store_id, total_amount, status)
VALUES (N'TXN-NOITEM', 1, 1, 0.00, N'待取餐');
DECLARE @tmp_order INT = SCOPE_IDENTITY();
BEGIN TRY
    EXEC dbo.usp_order_complete_txn @order_id = @tmp_order, @operator_employee_id = 2;
END TRY
BEGIN CATCH
    PRINT N'[预期错误·无明细] ' + ERROR_MESSAGE();
END CATCH
DELETE FROM dbo.orders WHERE order_id = @tmp_order;
GO

-- T5 回滚验证：写数据之后、提交之前触发错误，验证已写部分全部回滚
-- 复位订单 3 回「待取餐」
UPDATE dbo.orders SET total_amount = 18, status = N'待取餐', completed_at = NULL WHERE order_id = 3;
UPDATE dbo.pickup_codes SET status = N'待取餐', verified_at = NULL, verify_employee_id = NULL WHERE order_id = 3;

BEGIN TRY
    BEGIN TRANSACTION;
        -- 写① 已完成
        UPDATE dbo.orders SET status = N'已完成', completed_at = GETDATE() WHERE order_id = 3;
        -- 写② 核销取餐码
        UPDATE dbo.pickup_codes SET status = N'已核销', verified_at = GETDATE(), verify_employee_id = 2 WHERE order_id = 3;
        -- 模拟后续步骤失败（如写日志出错）
        THROW 50999, N'模拟：写入操作日志失败', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    PRINT N'[回滚] ' + ERROR_MESSAGE();
END CATCH

-- 验证：订单仍为「待取餐」、取餐码仍为「待取餐」（已写部分已回滚）
SELECT order_id, status, completed_at FROM dbo.orders WHERE order_id = 3;
SELECT pickup_id, order_id, status, verified_at FROM dbo.pickup_codes WHERE order_id = 3;
GO
