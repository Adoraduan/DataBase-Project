# v0.1 基线副本（第六周迁移的起点）

> 本目录是第六周「数据迁移」任务的 **v0.1 数据库副本**
> 第六周只在这份副本上运行 `09_migration.sql`，
> 迁移到 v1.0 目标结构后，用 `10_regression.sql` 做回归对比。

## 文件

| 文件 | 说明 |
| --- | --- |
| `01_create_database.sql` | v0.1 建库建表（20 张表），`employees.user_id` 此时为 **NULL** |
| `02_insert_sample_data.sql` | v0.1 样例数据，员工「王强」此时 `user_id = NULL`（未开账号） |

## 与目标结构（v1.0）的差异

v0.1 → 目标结构只有两处实质变更，均由 `09_migration.sql` 完成：

| 项 | v0.1 | 目标（v1.0） |
| --- | --- | --- |
| `employees.user_id` | `NULL`（可空，员工可无登录账号） | `NOT NULL`（一员工一账号） |
| `products.product_name` | 无唯一约束 | `UNIQUE`（候选码，坐实 week2 文档声明） |

其余 20 张表结构保留、确认 4NF，不做拆分/合并/删除。

## 迁移前基准（迁移前结果，用于回归对照）

在 v0.1 副本上执行 `02_insert_sample_data.sql` 后，三个基准查询结果为：

- **订单明细**（`v_order_detail` 等价查询）：**5 行**（4 张订单展开）
- **商品销售统计**（排除已取消）：拿铁咖啡 销量 **4**、销售额 **66.00**；美式咖啡 销量 **1**、销售额 **12.00**
- **库存查询**（库存 < 10）：**1 行**（大杯/冰 · 宿舍区店 · 数量 8）

迁移后这些数值应保持不变（迁移只动了账号/员工，不碰交易与库存）。

## 如何重建 v0.1 副本（再次运行迁移所需的初始状态）

`09_migration.sql` 不要求可重复执行。若需重跑：

1. 用本目录的 `01_create_database.sql` 建库（或对现有库先 `DROP DATABASE CampusCoffee` 重建）；
2. 执行 `02_insert_sample_data.sql` 回到 v0.1 数据；
3. 再执行 `../09_migration.sql` 迁移、`../10_regression.sql` 回归。
