/* ============================================================
   19_restock_transaction.sql —— 第 12 周 模拟补货入库事务
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   业务口径：
     - 用人工填写的补货单（restock_orders 表头 + restock_items 明细）与数量入库。
     - 同一事务内：增加库存 → 更新补货单状态与入库时间，全部成功才提交。
     - 已入库的单据再次执行不能重复加库存；失败回滚后库存与单据状态恢复。

   涉及表：restock_orders、restock_items、inventory（另：库存审计触发器
           trg_inventory_audit 会自动记录库存变化，且随本事务回滚）。

   执行前提：已执行 01 → 12_week10_12_schema.sql → 02
   ============================================================ */

USE CampusCoffee;
GO
SET XACT_ABORT ON;
GO

/* ---------- 1. 测试数据准备（幂等） ---------- */
DELETE FROM dbo.restock_items;
DELETE FROM dbo.restock_orders;

-- 一张待入库补货单（门店 1），两条明细：SKU1 +20、SKU2 +10
INSERT INTO dbo.restock_orders (restock_no, store_id, operator_employee_id, status)
VALUES (N'RS20261118001', 1, 2, N'待入库');
DECLARE @ro_id INT = SCOPE_IDENTITY();

INSERT INTO dbo.restock_items (restock_order_id, sku_id, quantity) VALUES
(@ro_id, 1, 20),
(@ro_id, 2, 10);

-- 初始库存
SELECT sku_id, store_id, quantity AS before_qty
FROM dbo.inventory WHERE store_id = 1 AND sku_id IN (1, 2);
GO

/* ---------- 2. 补货入库事务（含提交/回滚） ---------- */
GO
CREATE OR ALTER PROCEDURE dbo.usp_restock_in_txn
    @restock_order_id     INT,
    @operator_employee_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 校验① 补货单存在
        IF NOT EXISTS (SELECT 1 FROM dbo.restock_orders WHERE restock_order_id = @restock_order_id)
            THROW 50060, N'补货单不存在', 1;

        -- 校验② 状态（已入库 → 重复执行拒绝）
        DECLARE @status NVARCHAR(20);
        SELECT @status = status FROM dbo.restock_orders WITH (UPDLOCK) WHERE restock_order_id = @restock_order_id;
        IF @status = N'已入库' THROW 50061, N'补货单已入库，不能重复入库', 1;
        IF @status <> N'待入库' THROW 50062, N'只有「待入库」补货单可以入库', 1;

        -- 校验③ 操作员工存在
        IF NOT EXISTS (SELECT 1 FROM dbo.employees WHERE employee_id = @operator_employee_id)
            THROW 50063, N'操作员工不存在', 1;

        -- 校验④ 有明细、数量为正、商品存在
        IF NOT EXISTS (SELECT 1 FROM dbo.restock_items WHERE restock_order_id = @restock_order_id)
            THROW 50064, N'补货单没有明细', 1;
        IF EXISTS (SELECT 1 FROM dbo.restock_items WHERE restock_order_id = @restock_order_id AND quantity <= 0)
            THROW 50065, N'补货数量必须为正数', 1;
        IF EXISTS (
            SELECT 1 FROM dbo.restock_items ri
            WHERE ri.restock_order_id = @restock_order_id
              AND NOT EXISTS (SELECT 1 FROM dbo.skus k WHERE k.sku_id = ri.sku_id)
        )
            THROW 50066, N'补货明细含不存在的商品', 1;

        -- 写① 增加库存（逐明细，库存审计触发器自动记录，且随本事务回滚）
        DECLARE @store_id INT;
        SELECT @store_id = store_id FROM dbo.restock_orders WHERE restock_order_id = @restock_order_id;

        UPDATE i
        SET i.quantity = i.quantity + ri.quantity
        FROM dbo.inventory i
        JOIN dbo.restock_items ri ON ri.sku_id = i.sku_id
        WHERE ri.restock_order_id = @restock_order_id
          AND i.store_id = @store_id;

        -- 若某 SKU 在该门店没有库存行，则插入新行
        INSERT INTO dbo.inventory (sku_id, store_id, quantity)
        SELECT ri.sku_id, @store_id, ri.quantity
        FROM dbo.restock_items ri
        WHERE ri.restock_order_id = @restock_order_id
          AND NOT EXISTS (SELECT 1 FROM dbo.inventory i WHERE i.sku_id = ri.sku_id AND i.store_id = @store_id);

        -- 写② 更新补货单状态与入库时间
        UPDATE dbo.restock_orders
        SET status = N'已入库', in_stock_at = GETDATE()
        WHERE restock_order_id = @restock_order_id;

        COMMIT TRANSACTION;
        PRINT N'[提交] 补货单 ' + CAST(@restock_order_id AS NVARCHAR) + N' 入库完成。';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------- 3. 测试用例 ---------- */

-- T1 正常入库
DECLARE @ro_id INT = (SELECT restock_order_id FROM dbo.restock_orders WHERE restock_no = N'RS20261118001');
EXEC dbo.usp_restock_in_txn @restock_order_id = @ro_id, @operator_employee_id = 2;
SELECT sku_id, store_id, quantity FROM dbo.inventory WHERE store_id = 1 AND sku_id IN (1, 2);
SELECT restock_order_id, restock_no, status, in_stock_at FROM dbo.restock_orders WHERE restock_order_id = @ro_id;
GO

-- T2 重复调用（应拒绝，库存不再增加）
DECLARE @ro_id INT = (SELECT restock_order_id FROM dbo.restock_orders WHERE restock_no = N'RS20261118001');
BEGIN TRY
    EXEC dbo.usp_restock_in_txn @restock_order_id = @ro_id, @operator_employee_id = 2;
END TRY
BEGIN CATCH
    PRINT N'[预期错误·重复入库] ' + ERROR_MESSAGE();
END CATCH
GO

-- T3 回滚验证：新建一张待入库单，在「加库存后、改状态前」触发错误
DELETE FROM dbo.restock_items;
DELETE FROM dbo.restock_orders;

INSERT INTO dbo.restock_orders (restock_no, store_id, operator_employee_id, status)
VALUES (N'RS20261118002', 1, 2, N'待入库');
DECLARE @ro2 INT = SCOPE_IDENTITY();
INSERT INTO dbo.restock_items (restock_order_id, sku_id, quantity) VALUES (@ro2, 3, 5);

-- 加库存前
SELECT sku_id, quantity AS before FROM dbo.inventory WHERE sku_id = 3 AND store_id = 1;

BEGIN TRY
    BEGIN TRANSACTION;
        -- 写① 加库存（已写部分数据）
        UPDATE dbo.inventory SET quantity = quantity + 5 WHERE sku_id = 3 AND store_id = 1;
        -- 模拟改状态前出错
        THROW 50998, N'模拟：更新补货单状态失败', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    PRINT N'[回滚] ' + ERROR_MESSAGE();
END CATCH

-- 验证：库存恢复、单据仍为待入库
SELECT sku_id, quantity AS after FROM dbo.inventory WHERE sku_id = 3 AND store_id = 1;
SELECT restock_order_id, status FROM dbo.restock_orders WHERE restock_order_id = @ro2;
GO

-- T4 补货量非正数（应被 CHECK 约束拒绝）
DECLARE @ro2 INT = (SELECT restock_order_id FROM dbo.restock_orders WHERE restock_no = N'RS20261118002');
BEGIN TRY
    INSERT INTO dbo.restock_items (restock_order_id, sku_id, quantity) VALUES (@ro2, 4, 0);
END TRY
BEGIN CATCH
    PRINT N'[预期错误·数量非正] ' + ERROR_MESSAGE();
END CATCH
GO

-- T5 商品不存在：restock_items.sku_id 有外键约束，插入不存在商品会被 FK 拒绝（数据库层校验）；过程内④为防御性校验
DECLARE @ro2 INT = (SELECT restock_order_id FROM dbo.restock_orders WHERE restock_no = N'RS20261118002');
BEGIN TRY
    INSERT INTO dbo.restock_items (restock_order_id, sku_id, quantity) VALUES (@ro2, 999, 1);
    EXEC dbo.usp_restock_in_txn @restock_order_id = @ro2, @operator_employee_id = 2;
END TRY
BEGIN CATCH
    PRINT N'[预期错误·商品不存在] ' + ERROR_MESSAGE();
END CATCH
GO
