/* ============================================================
   12_week10_12_schema.sql —— 第 10—12 周结构扩展（v1.0 → v2.0）
   校园咖啡店线上点单自取系统 · SQL Server
   ============================================================
   作用：在 v1.0 的 20 张表之上，为第 10—12 周补齐业务所需结构：

     ① inventory      增加 最低库存(min_quantity) / 目标库存(target_quantity) 列
                       —— 供第 10 周「补货量函数」读取
     ② order_items    增加 折扣率(discount_rate) / 折扣金额(discount_amount) 列，
                       并新增计算列 成交金额(actual_amount) = subtotal - discount_amount
     ③ orders         增加 折扣总额(discount_amount) 列（total_amount 语义 = 成交总额）
     ④ 新表 inventory_adjustments —— 库存调整记录（第 10 周任务 2）
     ⑤ 新表 inventory_audit        —— 库存审计（第 11 周触发器写入，无外键，纯日志）
     ⑥ 新表 restock_orders / restock_items —— 补货单 / 补货明细（第 12 周任务 4）

   设计说明：
     - 成交金额 actual_amount 用「计算列」实现，恒等于 subtotal - discount_amount，
       因此 02_insert_sample_data.sql 重装基线数据后无需回填，永远自洽。
     - inventory_audit 是触发器写出的审计流水，刻意不加外键：它记录的是历史快照，
       不应反过来阻止 02 清空 skus/stores 等基础表（第 12 周提示亦要求审计表随事务回滚）。
     - 其余新表保留外键，保证完整性（与第 2 周设计、06 约束脚本口径一致）。

   幂等性：本脚本可重复执行（先按需建表/加列，再清空第 10—12 周新增表数据）。

   执行顺序（第 10 周起）：
       01_create_database.sql → 本文件 → 02_insert_sample_data.sql
       → 14_function.sql → 13_procedure.sql                       （第 10 周，先建函数，折扣过程依赖）
       → 15_trigger.sql / 16_window_query.sql                     （第 11 周）
       → 17_recursive_query.sql / 18_order_transaction.sql / 19_restock_transaction.sql （第 12 周）
   ============================================================ */

USE CampusCoffee;
GO
SET XACT_ABORT ON;
GO

/* ============================================================
   Part 1  新增表（幂等）
   ============================================================ */

-- 1. 库存调整记录
IF OBJECT_ID(N'dbo.inventory_adjustments', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.inventory_adjustments (
        adjustment_id        INT IDENTITY(1,1) NOT NULL,
        sku_id               INT               NOT NULL,
        store_id             INT               NOT NULL,
        adjust_quantity      INT               NOT NULL,   -- 正=增加，负=减少，不得为 0
        reason               NVARCHAR(200)     NULL,
        operator_employee_id INT               NOT NULL,   -- 操作员工编号
        quantity_before      INT               NOT NULL,
        quantity_after       INT               NOT NULL,
        created_at           DATETIME          NOT NULL CONSTRAINT DF_inventory_adjustments_created_at DEFAULT GETDATE(),

        CONSTRAINT PK_inventory_adjustments PRIMARY KEY (adjustment_id),
        CONSTRAINT FK_inventory_adjustments_skus      FOREIGN KEY (sku_id)   REFERENCES dbo.skus(sku_id),
        CONSTRAINT FK_inventory_adjustments_stores    FOREIGN KEY (store_id) REFERENCES dbo.stores(store_id),
        CONSTRAINT FK_inventory_adjustments_employees FOREIGN KEY (operator_employee_id) REFERENCES dbo.employees(employee_id),
        CONSTRAINT CK_inventory_adjustments_quantity   CHECK (adjust_quantity <> 0),
        CONSTRAINT CK_inventory_adjustments_after      CHECK (quantity_after >= 0)
    );
END
GO

-- 2. 库存审计（触发器写入，纯日志表，不加外键）
IF OBJECT_ID(N'dbo.inventory_audit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.inventory_audit (
        audit_id        INT IDENTITY(1,1) NOT NULL,
        sku_id          INT               NOT NULL,
        store_id        INT               NOT NULL,
        quantity_before INT               NULL,
        quantity_after  INT               NULL,
        change_quantity INT               NOT NULL,   -- 变化数量（+/-）
        operation_type  NVARCHAR(20)      NOT NULL,   -- INSERT / UPDATE / DELETE
        operator_name   NVARCHAR(128)     NOT NULL CONSTRAINT DF_inventory_audit_operator_name DEFAULT SUSER_SNAME(),
        created_at      DATETIME          NOT NULL CONSTRAINT DF_inventory_audit_created_at DEFAULT GETDATE(),

        CONSTRAINT PK_inventory_audit PRIMARY KEY (audit_id),
        CONSTRAINT CK_inventory_audit_operation_type CHECK (operation_type IN (N'INSERT', N'UPDATE', N'DELETE'))
    );
END
GO

-- 3. 补货单（表头）
IF OBJECT_ID(N'dbo.restock_orders', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.restock_orders (
        restock_order_id     INT IDENTITY(1,1) NOT NULL,
        restock_no           NVARCHAR(32)      NOT NULL,
        store_id             INT               NOT NULL,
        operator_employee_id INT               NOT NULL,
        status               NVARCHAR(20)      NOT NULL CONSTRAINT DF_restock_orders_status DEFAULT N'待入库',
        in_stock_at          DATETIME          NULL,
        created_at           DATETIME          NOT NULL CONSTRAINT DF_restock_orders_created_at DEFAULT GETDATE(),

        CONSTRAINT PK_restock_orders PRIMARY KEY (restock_order_id),
        CONSTRAINT UQ_restock_orders_no UNIQUE (restock_no),
        CONSTRAINT FK_restock_orders_stores    FOREIGN KEY (store_id) REFERENCES dbo.stores(store_id),
        CONSTRAINT FK_restock_orders_employees FOREIGN KEY (operator_employee_id) REFERENCES dbo.employees(employee_id),
        CONSTRAINT CK_restock_orders_status CHECK (status IN (N'待入库', N'已入库', N'已取消'))
    );
END
GO

-- 4. 补货明细（表体）
IF OBJECT_ID(N'dbo.restock_items', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.restock_items (
        restock_item_id INT IDENTITY(1,1) NOT NULL,
        restock_order_id INT              NOT NULL,
        sku_id           INT              NOT NULL,
        quantity         INT              NOT NULL,

        CONSTRAINT PK_restock_items PRIMARY KEY (restock_item_id),
        CONSTRAINT FK_restock_items_orders FOREIGN KEY (restock_order_id) REFERENCES dbo.restock_orders(restock_order_id),
        CONSTRAINT FK_restock_items_skus   FOREIGN KEY (sku_id)          REFERENCES dbo.skus(sku_id),
        CONSTRAINT CK_restock_items_quantity CHECK (quantity > 0)
    );
END
GO

/* ============================================================
   Part 2  已有表新增列（幂等）
   ============================================================ */

-- ① inventory：最低库存 / 目标库存
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.inventory') AND name = N'min_quantity')
    ALTER TABLE dbo.inventory ADD min_quantity INT NULL CONSTRAINT DF_inventory_min_quantity DEFAULT 5;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.inventory') AND name = N'target_quantity')
    ALTER TABLE dbo.inventory ADD target_quantity INT NULL CONSTRAINT DF_inventory_target_quantity DEFAULT 50;
GO

-- ② order_items：折扣率 / 折扣金额（先加，计算列 actual_amount 依赖 discount_amount）
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.order_items') AND name = N'discount_rate')
    ALTER TABLE dbo.order_items ADD discount_rate DECIMAL(5,4) NOT NULL CONSTRAINT DF_order_items_discount_rate DEFAULT 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.order_items') AND name = N'discount_amount')
    ALTER TABLE dbo.order_items ADD discount_amount DECIMAL(10,2) NOT NULL CONSTRAINT DF_order_items_discount_amount DEFAULT 0;
GO
-- 计算列：成交金额 = 原价小计 - 折扣金额（恒自洽，无需回填）
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.order_items') AND name = N'actual_amount')
    ALTER TABLE dbo.order_items ADD actual_amount AS (subtotal - discount_amount);
GO

-- ③ orders：折扣总额（total_amount 语义 = 成交总额 = 原价总额 - 折扣总额）
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.orders') AND name = N'discount_amount')
    ALTER TABLE dbo.orders ADD discount_amount DECIMAL(10,2) NOT NULL CONSTRAINT DF_orders_discount_amount DEFAULT 0;
GO

/* ============================================================
   Part 3  清空第 10—12 周新增表数据（幂等，便于重复测试前重置）
   ============================================================ */
DELETE FROM dbo.restock_items;
DELETE FROM dbo.restock_orders;
DELETE FROM dbo.inventory_adjustments;
DELETE FROM dbo.inventory_audit;
GO

PRINT N'[完成] 第 10—12 周结构已就绪（inventory/order_items/orders 加列，新增 4 张表）。';
GO
