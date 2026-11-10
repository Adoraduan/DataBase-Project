# 第六周　函数依赖与规范化分析（ch7）

> 分析对象：`01_create_database.sql` 的 20 张表（v0.1 基线）。
> 配套产物：`09_migration.sql`（迁移）、`10_regression.sql`（回归）、`week6.v0.1基线/`（v0.1 副本）。

## 0. 结论摘要

逐表核查 1NF / 2NF / 3NF（并顺带确认 BCNF / 4NF）后，**20 张表无需大规模重构**，仅两处需修正：

| 问题 | v0.1 状态 | 目标状态 | 性质 |
| --- | --- | --- | --- |
| `employees.user_id` 可空 | 无账号员工也可建档，`user_id` 不该作候选码 | 收紧为 `NOT NULL`，一员工一账号 | 候选码选取错误 |
| `products.product_name` 无唯一约束 | 文档标了候选码但库不认可 | 加 `UNIQUE` 约束坐实候选码 | 候选码未落地 |

其余 18 张表因遵循四条设计规则（见 §2），已满足高范式要求，保留并给出分析证据，不做「为规范化而拆表」的破坏性重构。

> 另有两处**文档级**候选码误标（不涉及 DDL 变更，仅 week2 文档措辞）：`users.email` 与 `payments.channel_trade_no` 均为可空列、用过滤唯一索引约束，**可空列不能作候选码**，已从候选码清单中删除，保留「唯一可空」约束说明。v0.1 的 `users.email` 已随 week6 修正，`channel_trade_no` 本次一并修正。

## 1. 分析对象与基线

对照第五周 ER 图，20 张表与实体一一对应，无 ER 图与表结构不一致之处：

| 模块 | 表 | 对应实体/联系 |
| --- | --- | --- |
| 账号权限 | users、roles、permissions、user_roles、role_permissions | 用户、角色、权限、两对 M:N 联系 |
| 组织 | stores、employees | 门店、员工 |
| 商品库存 | categories、products、skus、inventory | 分类、商品、规格、库存(M:N) |
| 交易 | orders、order_items、payments、pickup_codes | 订单、明细、支付、取餐码 |
| 营销反馈 | coupons、coupon_claims、reviews、point_transactions | 优惠券、领取、评价、积分流水 |
| 审计 | operation_logs | 操作日志 |

v0.1 副本已存于 `week6.v0.1基线/`（来自 git `e4e7716`），迁移前基准（订单明细 5 行、商品销量 拿铁4/66·美式1/12、低库存 1 行）已记录在该目录 README 与 `09_migration.sql` Part 0。

## 2. 四条设计规则（为何大部分表已是高范式）

1. **关系实体分离**：多对一/一对一联系用「外码引用」，多对多用「关联表承载两个主码」，不在双方各自塞对方主码，避免重复与冗余。
2. **候选键元素唯一**：绝大多数表用单列自增代理码作主码，候选码也多为单列；复合码只出现在关联表（`user_roles`、`role_permissions`、`inventory`、`coupon_claims`）与 `skus`，而这些复合码的每个分量都是外码。
3. **逻辑关系分离**：非码属性之间不存在与主码无关的必然决定关系，即不出现 `A → B → C` 的传递依赖。
4. **快照隔离**：`order_items` 存下单时的 `product_name` / `sku_name` / `unit_price` 快照，切断「历史订单 ↔ 当前商品价格」的依赖，避免改价污染历史订单。

## 3. 逐表范式分析

> 通用结论先行：所有表字段均原子（无多值字段、无重复组），**1NF 全部满足**。
> 2NF 只对「复合候选码」的表有意义；本项目单列候选码的表天然无部分依赖。

### 3.1 单列候选码表（直接满足 2NF/3NF）

`users`、`roles`、`permissions`、`stores`、`employees`、`categories`、`products`、`orders`、`payments`、`pickup_codes`、`coupons`、`reviews`、`point_transactions`、`operation_logs`、`order_items` 这 15 张表，主码为单列自增 ID（或单列唯一键）：

- **候选码**：见 §1 与下表「关键字段」；多张表另有单列候选码（如 `username`、`phone`、`store_name`、`order_no`、`payment_no`、`pickup_code`）。
- **2NF**：主码为单属性，不存在「非主属性部分函数依赖候选码」的可能 → 天然满足 2NF。
- **3NF**：非码属性之间无传递依赖。核心例子见下：

  - `products`：`product_id → category_id`，而 `category_id → category_name` 落在 `categories` 表，`products` 里 **不冗余** `category_name`，故不存在 `product_id → category_id → category_name` 的传递依赖。若当初把类别名称冗余进 `products`，就会违反 3NF（见 §5 反例演示）。
  - `order_items`：`product_name` / `sku_name` / `unit_price` 虽可由 `sku_id` 推出，但这是**有意快照**（§4 冗余取舍），不代表传递依赖——它们语义上「凝固在订单这一时刻」，决定因素是 `order_item_id`（一笔明细），不是「当前」的 `sku_id`。
  - `employees`：`user_id` 是候选码（唯一），`user_id → store_id`、`user_id → name` 等完全函数依赖成立，无传递依赖。v0.1 让它可空是错误（见 §4）。

### 3.2 复合码表（需检查 2NF 的部分依赖）

| 表 | 主码 | 非码属性 | 2NF 判断 |
| --- | --- | --- | --- |
| `user_roles` | (user_id, role_id) | 无 | 无非码属性，平凡满足 2NF/3NF |
| `role_permissions` | (role_id, permission_id) | 无 | 同上 |
| `inventory` | (sku_id, store_id) | quantity | `quantity` 同时由 `sku_id` 与 `store_id` 共同决定（同一 SKU 在不同门店数量不同），**不部分依赖**任一单独分量 → 2NF 满足 |
| `coupon_claims` | claim_id（候选码 (coupon_id, user_id)） | status, claimed_at, used_at | 非码属性完全依赖 `claim_id`（或复合候选码整体），无部分依赖 → 2NF 满足 |

### 3.3 范式结论

全部 20 张表满足 1NF/2NF/3NF；因各表最多一个非平凡候选码、且无多值依赖（MVD），进一步满足 **BCNF / 4NF**（与 week2 文档标记一致）。

## 4. 更新异常讨论与重构方案

### 4.1 两处修正（本项目实际重构）

**修正一：`employees.user_id` 可空 → 非空**

- 函数依赖：`user_id` 是 `employees` 的候选码（`user_id → (employee_id, store_id, name, position, hire_date)`）。候选码不允许取 NULL。
- 异常：v0.1 里员工「王强」`user_id = NULL`，既无法作为候选码，也让「员工 ↔ 登录账号」的 1:1 关系出现缺口（有员工无账号）。
- 方案：迁移时给王强回填账号 `wangqiang`(user_id=5) + 店员角色，再 `ALTER COLUMN user_id INT NOT NULL`。
- 结果：一员工一账号，候选码与 1:1 基数都坐实。

**修正二：`products.product_name` 加唯一约束**

- 函数依赖：`product_name → product_id`（业务上商品名全库唯一）。
- 方案：`ALTER TABLE products ADD CONSTRAINT UQ_products_product_name UNIQUE (product_name)`。

### 4.2 已满足要求的表的「保留理由」与异常免疫

| 表 | 保留理由（为何无插入/修改/删除异常） |
| --- | --- |
| `categories` | 分类独立成表，可先插入「尚无商品的分类」，不出现插入异常；改分类名只改一行，无修改异常 |
| `products` | 只存 `category_id` 不存 `category_name`，改分类名不波及商品行（无修改异常） |
| `skus` / `inventory` | 价格挂 SKU、数量挂 inventory，改价/改库存各自单点修改 |
| `order_items` | 存快照，商品改名/改价**不**影响历史订单明细（避免经典「改价污染历史订单」的修改异常） |
| `orders` / `payments` / `pickup_codes` / `reviews` | 1:1 / 1:N 用外码表达，无冗余属性，删除订单明细不会连带丢失商品/门店信息 |
| RBAC 五表 | 角色、权限、用户两两独立 + 关联表，无冗余；删除某角色不影响用户与权限本身 |

### 4.3 独立反例演示（说明「为何不拆」与「何时该拆」）

为说明异常与分解的判断方法、又不破坏本项目，用**独立假设关系**演示：若当初 `products` 冗余了类别名称，变成

```
PRODUCT(product_id, product_name, category_id, category_name, …)
```

则存在传递依赖 `product_id → category_id → category_name`（3NF 违例），会引发：

- **插入异常**：想登记一个「还没有任何商品」的新分类（如「新品尝鲜」），因为 `product_id` 非空且是主码的一部分，插不进去。
- **修改异常**：把分类「咖啡」改名「咖啡饮品」，必须更新所有属于该分类的商品行，漏一行即不一致。
- **删除异常**：删掉某分类下最后一个商品，会连带丢失该分类信息。

**分解**：拆成 `PRODUCT(product_id, product_name, category_id, …)` + `CATEGORY(category_id, category_name, …)`，三类异常同时消除。本项目 `products`/`categories` 正是此分解后的形态，故保留。

## 5. 无损连接与依赖保持

- 本项目无表拆分，仅两处属性级修正（列非空 + 唯一约束），**不改变任何表的结构性关系**，无损连接（所有原表原样保留、外码不变）与依赖保持（原有函数依赖集合不变，且新增 `product_name → product_id` 的唯一约束反而**加强**了依赖）天然成立。
- `categories`/`products` 的父子结构：通过 `products.category_id = categories.category_id` 自然连接即可还原「商品 + 分类名」的完整视图，不丢信息。

## 6. 冗余维护方式（反规范化取舍）

本项目有两处**有意冗余**，均有明确维护手段：

| 冗余 | 目的 | 维护方式 |
| --- | --- | --- |
| `order_items` 存 `product_name`/`sku_name`/`unit_price` 快照 | 隔离历史订单与当前价格，防止改价污染 | 下单时从 `skus`/`products` 一次性快照写入，之后商品改名/改价不再回写明细 |
| `orders.total_amount` = Σ `order_items.subtotal` | 免每次订单列表都聚合明细 | 下单/改明细/删明细时同步重算；`02` 脚本与 `10_regression` Part 3 均有「订单总额=明细合计」自洽核对（0 行差异）兜底 |

## 7. 迁移与回归

- `09_migration.sql`：基线检查 → 重复检查 → 回填王强账号 → `user_id` 收紧非空 → `product_name` 加唯一 → 迁移后核对，整体事务、失败回滚。
- `10_regression.sql`：关键标识、关系映射、订单金额、销量、库存、角色权限 + 合法写/非法外码/非法数量/越权；迁移前后业务结果一致。
- 结果：订单明细 5 行、商品销量（拿铁 4/66、美式 1/12）、低库存 1 行，迁移前后**完全一致**；行数变化仅 `users` 4→5、`user_roles` 4→5（回填账号）。
