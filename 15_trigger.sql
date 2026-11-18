/* ============================================================
   15_trigger.sql —— 第 11 周 触发器
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   对象清单：
     ① trg_inventory_audit        库存审计触发器（inventory 增/改/删时记录前后量、变化量、类型、操作人）
     ② trg_orders_complete_check  订单完成规则触发器（状态改「已完成」时校验明细/商品/金额，拒绝非法完成与重复完成）

   要点：
     - 触发器一次可能处理多行，必须结合 inserted / deleted 用集合方式判断，
       不能只用一个变量保存单行。
     - 库存审计触发器写入的 inventory_audit 是纯日志表，随事务回滚（见第 12 周说明）。

   执行前提：已执行 01 → 12_week10_12_schema.sql → 02
   ============================================================ */

USE CampusCoffee;
GO

/* ------------------------------------------------------------
   ① 库存审计触发器
   - INSERT：before=NULL，after=quantity，change=+quantity
   - UPDATE：before=deleted.quantity，after=inserted.quantity，change=after-before
   - DELETE：before=quantity，after=NULL，change=-quantity
   ------------------------------------------------------------ */
GO
CREATE OR ALTER TRIGGER dbo.trg_inventory_audit
ON dbo.inventory
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- UPDATE（inserted 与 deleted 同时存在的行）
    INSERT INTO dbo.inventory_audit
        (sku_id, store_id, quantity_before, quantity_after, change_quantity, operation_type, operator_name)
    SELECT i.sku_id, i.store_id, d.quantity, i.quantity, i.quantity - d.quantity,
           N'UPDATE', SUSER_SNAME()
    FROM inserted i
    JOIN deleted d ON i.sku_id = d.sku_id AND i.store_id = d.store_id;

    -- INSERT（只在 inserted、不在 deleted）
    INSERT INTO dbo.inventory_audit
        (sku_id, store_id, quantity_before, quantity_after, change_quantity, operation_type, operator_name)
    SELECT i.sku_id, i.store_id, NULL, i.quantity, i.quantity,
           N'INSERT', SUSER_SNAME()
    FROM inserted i
    WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.sku_id = i.sku_id AND d.store_id = i.store_id);

    -- DELETE（只在 deleted、不在 inserted）
    INSERT INTO dbo.inventory_audit
        (sku_id, store_id, quantity_before, quantity_after, change_quantity, operation_type, operator_name)
    SELECT d.sku_id, d.store_id, d.quantity, NULL, -d.quantity,
           N'DELETE', SUSER_SNAME()
    FROM deleted d
    WHERE NOT EXISTS (SELECT 1 FROM inserted i WHERE i.sku_id = d.sku_id AND i.store_id = d.store_id);
END
GO

/* ------------------------------------------------------------
   ② 订单完成规则触发器
   触发时机：orders 状态被改为「已完成」时（AFTER UPDATE）。
   校验：已有明细、金额与明细成交金额一致、商品规格有效；已完成的订单不能重复完成。
   说明：本项目「下单即扣库存」，库存已在下单时扣减，此处只做完整性核验、不重复扣减。
   ------------------------------------------------------------ */
GO
CREATE OR ALTER TRIGGER dbo.trg_orders_complete_check
ON dbo.orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 仅处理「状态变为已完成」的行
    IF NOT EXISTS (
        SELECT 1 FROM inserted i JOIN deleted d ON i.order_id = d.order_id
        WHERE i.status = N'已完成' AND d.status <> N'已完成'
    )
        RETURN;

    -- 重复完成：原本已是「已完成」却再次置为已完成
    IF EXISTS (
        SELECT 1 FROM inserted i JOIN deleted d ON i.order_id = d.order_id
        WHERE i.status = N'已完成' AND d.status = N'已完成'
    )
    BEGIN
        RAISERROR(N'该订单已经完成，不能重复完成', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 无明细
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.status = N'已完成'
          AND NOT EXISTS (SELECT 1 FROM dbo.order_items oi WHERE oi.order_id = i.order_id)
    )
    BEGIN
        RAISERROR(N'订单没有明细，不能置为已完成', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 金额核算：订单总额 = 明细成交金额之和
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.status = N'已完成'
          AND i.total_amount <> (SELECT ISNULL(SUM(oi.actual_amount), 0) FROM dbo.order_items oi WHERE oi.order_id = i.order_id)
    )
    BEGIN
        RAISERROR(N'订单金额与明细成交金额不一致，不能置为已完成', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 商品规格有效性（明细引用的 SKU 必须存在）
    IF EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.status = N'已完成'
          AND EXISTS (
              SELECT 1 FROM dbo.order_items oi
              WHERE oi.order_id = i.order_id
                AND (oi.sku_id IS NULL
                     OR NOT EXISTS (SELECT 1 FROM dbo.skus k WHERE k.sku_id = oi.sku_id))
          )
    )
    BEGIN
        RAISERROR(N'订单含无效商品规格，不能置为已完成', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

/* ============================================================
   测试脚本（第 11 周）
   ============================================================ */

-- ---------- A. 库存审计触发器 ----------
-- 清空审计，便于观察本次操作产生的记录
DELETE FROM dbo.inventory_audit;

-- A1 单条插入（SKU4 门店2 为测试新增，基线不存在）
INSERT INTO dbo.inventory (sku_id, store_id, quantity) VALUES (4, 2, 5);

-- A2 单条修改
UPDATE dbo.inventory SET quantity = 8 WHERE sku_id = 4 AND store_id = 2;

-- A3 多条修改（同一语句影响门店 1 的全部 4 行）
UPDATE dbo.inventory SET quantity = quantity + 1 WHERE store_id = 1;

-- A4 删除（删除刚才的测试行）
DELETE FROM dbo.inventory WHERE sku_id = 4 AND store_id = 2;

-- A5 查看审计结果（应含 INSERT / UPDATE / UPDATE×4 / DELETE）
SELECT audit_id, sku_id, store_id, quantity_before, quantity_after,
       change_quantity, operation_type, operator_name
FROM dbo.inventory_audit
ORDER BY audit_id;
GO

-- ---------- B. 订单完成规则触发器 ----------
-- 复位订单 3 为已知状态（待取餐、金额一致），便于重复测试
UPDATE dbo.order_items SET discount_rate = 0, discount_amount = 0 WHERE order_id = 3;
UPDATE dbo.orders SET total_amount = 18, discount_amount = 0, status = N'待取餐', completed_at = NULL WHERE order_id = 3;
UPDATE dbo.pickup_codes SET status = N'待取餐', verified_at = NULL, verify_employee_id = NULL WHERE order_id = 3;

-- B1 正常完成（订单 3 待取餐，金额一致）→ 应成功
UPDATE dbo.orders SET status = N'已完成', completed_at = GETDATE() WHERE order_id = 3;
SELECT order_id, status, completed_at FROM dbo.orders WHERE order_id = 3;

-- B2 重复完成 → 应被触发器拒绝
BEGIN TRY
    UPDATE dbo.orders SET status = N'已完成' WHERE order_id = 3;
END TRY
BEGIN CATCH
    PRINT N'[预期错误·重复完成] ' + ERROR_MESSAGE();
END CATCH
GO

-- B3 金额不一致 → 应被触发器拒绝
UPDATE dbo.orders SET status = N'待取餐', completed_at = NULL, total_amount = 999 WHERE order_id = 3;
BEGIN TRY
    UPDATE dbo.orders SET status = N'已完成' WHERE order_id = 3;
END TRY
BEGIN CATCH
    PRINT N'[预期错误·金额不一致] ' + ERROR_MESSAGE();
END CATCH

-- 复位
UPDATE dbo.orders SET total_amount = 18, status = N'待取餐', completed_at = NULL WHERE order_id = 3;
GO
