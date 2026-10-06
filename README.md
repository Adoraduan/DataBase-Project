# 校园咖啡店线上点单自取系统（数据库课程项目）

> 数据库实验课程 · 第一阶段 **v0.1**（第 1—4 周）：把经营场景转成可运行的关系数据库，完成建库、装载、增删改查、连接查询、视图、完整性与授权。

## 项目范围

一个校园咖啡店线上点单自取系统：顾客在线下单并支付，店员接单制作、核销取餐码，店长管理商品/库存/优惠并审批退款，系统管理员管理账号与权限。业务覆盖「顾客 → 完成交易 → 售后」的主链路，并保留会员积分、优惠券、评价等经营数据。会员 = 已注册顾客，积分随账号存、留流水。

## 环境

- 数据库：Microsoft SQL Server（示例库名 `CampusCoffee`）
- 脚本为 T-SQL；`CREATE OR ALTER VIEW` 需 SQL Server 2016+
- 建议以 `sa` / `db_owner` 权限执行（`role.sql` 的 `CREATE LOGIN` 需 sysadmin）

## 目录结构

| 文件 | 说明 |
| --- | --- |
| `ddl.sql` | 建库建表 + 主外键/唯一/检查约束 |
| `dml.sql` | 装载样例数据 + 增删改验证 |
| `query.sql` | 多表连接查询 |
| `view.sql` | 统计视图 |
| `constraint.sql` | 补充完整性约束 + 非法数据验证 |
| `role.sql` | 数据库角色 + 授权 + 越权验证 |
| `week1：项目设计.md` | 业务流程 / 角色 / 数据边界 |
| `week2：关系模式设计.md` | 关系模式（字段/域/码，详细） |
| `关系表说明.md` | 表功能与关系速览（易读版） |
| `阶段报告.md` | 阶段报告（设计思路/实验过程/总结） |
| `AI使用记录.md` | AI 使用记录 |
| `组内分工表.md` | 组内分工表 |

## 整体链路

顾客注册登录 → 浏览商品/规格 → 加购 → 提交订单 → 支付 → 店员接单制作 → 待取餐 → 核销取餐码 → 完成 → 评价/积分/退款。

数据侧对应：`users/roles`（账号权限）→ `products/skus/inventory`（商品库存）→ `orders/order_items/payments/pickup_codes`（交易）→ `reviews/point_transactions`（评价积分）。

## 复现步骤

1. 新建查询窗口，按顺序执行：
   `ddl.sql` → `dml.sql` → `query.sql` → `view.sql` → `constraint.sql` → `role.sql`
2. 各脚本均以 `USE CampusCoffee;` 开头。`dml.sql` 顶部会先清空数据，可重复执行；`constraint.sql`、`role.sql` 首次执行（重复执行见脚本内注释）。
3. 验证要点：
   - `constraint.sql` 末尾非法语句应被拒绝；
   - `role.sql` 末尾越权语句应报错（消息 229，属预期）；
   - `query.sql` / `view.sql` 返回正确结果。
