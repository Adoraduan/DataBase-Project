# week2：关系模式设计

> 承接 week1 的业务需求分析与数据边界，把「校园咖啡店线上点单自取系统」的业务对象转换为**关系模式**：表清单、字段（属性＋域）、主码、候选码、外码、样例元组。
> 本阶段只做关系设计，**不写 DDL/SQL**（建库留到 week3，查询/视图/约束/权限留到 week4）。

---

## 一、设计约定（域与命名）

| 类别 | 约定 |
| --- | --- |
| 主码 | `INT IDENTITY(1,1)` 自增整型；联合主码用组合键 |
| 文本 | `NVARCHAR(n)`（支持中文）；手机号 `VARCHAR(11)`；邮箱 `VARCHAR(100)` |
| 金额 | `DECIMAL(10,2)`；数量/分值 `INT`；时间 `DATETIME`；日期 `DATE` |
| 状态/枚举 | `NVARCHAR(20)`，枚举值写在字段说明中 |
| 命名 | 表名/字段名英文小写下划线；主码统一 `xxx_id`；外码与主码同名 |

---

## 二、表清单（进入数据库的实体与关系）

| # | 关系名 | 中文 | 对应 week1 数据项 |
| --- | --- | --- | --- |
| 1 | `users` | 用户账号 | 用户账号（含会员积分余额） |
| 2 | `roles` | 角色 | 角色与权限 |
| 3 | `permissions` | 权限 | 角色与权限 |
| 4 | `role_permissions` | 角色-权限关系 | 角色与权限 |
| 5 | `user_roles` | 用户-角色关系 | 角色与权限 |
| 6 | `stores` | 门店 | 门店信息 |
| 7 | `employees` | 员工 | 员工信息 |
| 8 | `categories` | 商品分类 | 商品分类 |
| 9 | `products` | 商品 | 商品、上下架状态 |
| 10 | `skus` | 商品规格(SKU) | 商品、SKU、规格、价格 |
| 11 | `inventory` | 库存 | 库存（SKU、门店、数量） |
| 12 | `orders` | 订单 | 订单 |
| 13 | `order_items` | 订单明细 | 订单明细、订单商品快照 |
| 14 | `payments` | 支付记录 | 支付记录 |
| 15 | `coupons` | 优惠券/活动 | 优惠券、活动 |
| 16 | `coupon_claims` | 优惠券领取记录 | 领取记录 |
| 17 | `pickup_codes` | 取餐码/核销 | 取餐码、核销记录 |
| 18 | `reviews` | 评价 | 评价 |
| 19 | `point_transactions` | 积分流水 | 积分流水 |
| 20 | `operation_logs` | 操作日志 | 操作日志 |

---

## 三、关系模式详表

### 1. `users` 用户账号
> 登录鉴权与身份识别；**会员 = 已注册顾客**，积分余额随账号存。

| 字段 | 域（类型） | 键/约束 | 说明 |
| --- | --- | --- | --- |
| user_id | INT | 主码 | 自增 |
| username | NVARCHAR(50) | 候选码，非空唯一 | 登录名 |
| phone | VARCHAR(11) | 候选码，唯一非空 | 手机号 |
| email | VARCHAR(100) | 候选码，唯一可空 | 邮箱 |
| password_hash | NVARCHAR(128) | 非空 | 密码哈希（不存明文） |
| status | NVARCHAR(20) | 非空，默认'正常' | 正常 / 停用 |
| points_balance | INT | 非空，默认 0 | 会员积分余额 |
| created_at | DATETIME | 非空 | 注册时间 |

- **主码**：`user_id`
- **候选码**：`username`、`phone`、`email`
- **外码**：无

```
样例元组：(1, 'alice', '13800000001', 'alice@stu.edu.cn', '…哈希…', '正常', 120, '2026-09-01 09:00:00')
```

### 2. `roles` 角色
> RBAC 的角色维度。

| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| role_id | INT | 主码 | 自增 |
| role_name | NVARCHAR(50) | 候选码，唯一非空 | 顾客/店员/店长/系统管理员 |
| description | NVARCHAR(200) | 可空 | 角色说明 |

- **主码**：`role_id`　**候选码**：`role_name`　**外码**：无

```
样例元组：(1,'顾客','注册用户，下单取餐评价'),(2,'店员','接单制作核销'),(3,'店长','管理商品库存优惠审批退款'),(4,'系统管理员','管账号角色权限与配置')
```

### 3. `permissions` 权限
> RBAC 的权限维度。

| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| permission_id | INT | 主码 | 自增 |
| permission_name | NVARCHAR(50) | 候选码，唯一非空 | 如 order:create / product:edit |
| description | NVARCHAR(200) | 可空 | 说明 |

- **主码**：`permission_id`　**候选码**：`permission_name`　**外码**：无

```
样例元组：(1,'order:create','下单'),(2,'order:verify','核销取餐'),(3,'product:edit','维护商品')
```

### 4. `role_permissions` 角色-权限关系
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| role_id | INT | 主码(组合)，外码→roles | 角色 |
| permission_id | INT | 主码(组合)，外码→permissions | 权限 |

- **主码**：`(role_id, permission_id)`　**候选码**：无　**外码**：`role_id→roles`、`permission_id→permissions`

```
样例元组：(2,2)  -- 店员拥有核销权限
```

### 5. `user_roles` 用户-角色关系
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| user_id | INT | 主码(组合)，外码→users | 用户 |
| role_id | INT | 主码(组合)，外码→roles | 角色 |

- **主码**：`(user_id, role_id)`　**候选码**：无　**外码**：`user_id→users`、`role_id→roles`

```
样例元组：(1,1)  -- alice 是顾客
```

### 6. `stores` 门店
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| store_id | INT | 主码 | 自增 |
| store_name | NVARCHAR(50) | 候选码，唯一非空 | 门店名 |
| address | NVARCHAR(200) | 可空 | 地址 |
| phone | VARCHAR(11) | 可空 | 门店电话 |
| status | NVARCHAR(20) | 非空，默认'营业' | 营业 / 停业 |

- **主码**：`store_id`　**候选码**：`store_name`　**外码**：无

```
样例元组：(1,'图书馆店','图书馆一楼','13800000100','营业')
```

### 7. `employees` 员工
> 店员/店长，归属门店，可关联登录账号。

| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| employee_id | INT | 主码 | 自增 |
| user_id | INT | 候选码，唯一可空，外码→users | 关联登录账号 |
| store_id | INT | 非空，外码→stores | 所属门店 |
| name | NVARCHAR(50) | 非空 | 姓名 |
| position | NVARCHAR(20) | 非空 | 店员 / 店长 |
| hire_date | DATE | 可空 | 入职日期 |

- **主码**：`employee_id`　**候选码**：`user_id`（已关联账号时）　**外码**：`user_id→users`、`store_id→stores`

```
样例元组：(1,10,1,'张伟','店长','2025-09-01'),(2,11,1,'李娜','店员','2026-03-01')
```

### 8. `categories` 商品分类
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| category_id | INT | 主码 | 自增 |
| parent_id | INT | 可空，外码→categories | 父分类（自引用） |
| category_name | NVARCHAR(50) | 候选码，唯一非空 | 分类名 |
| sort_order | INT | 非空，默认 0 | 排序 |

- **主码**：`category_id`　**候选码**：`category_name`　**外码**：`parent_id→categories`

```
样例元组：(1,NULL,'咖啡',1),(2,NULL,'甜点',2),(3,1,'拿铁系列',1)
```

### 9. `products` 商品
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| product_id | INT | 主码 | 自增 |
| category_id | INT | 非空，外码→categories | 所属分类 |
| product_name | NVARCHAR(100) | 非空 | 商品名 |
| description | NVARCHAR(500) | 可空 | 描述 |
| image_url | NVARCHAR(255) | 可空 | 图片 URL（原文件不入库） |
| status | NVARCHAR(20) | 非空，默认'上架' | 上架 / 下架 |
| created_at | DATETIME | 非空 | 创建时间 |

- **主码**：`product_id`　**候选码**：无　**外码**：`category_id→categories`

```
样例元组：(1,1,'拿铁咖啡','经典意式拿铁','https://.../latte.jpg','上架','2026-09-01 09:00:00')
```

### 10. `skus` 商品规格(SKU)
> 规格（杯型/冷热等）落在 SKU 上；价格挂在 SKU。

| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| sku_id | INT | 主码 | 自增 |
| product_id | INT | 非空，外码→products | 所属商品 |
| sku_name | NVARCHAR(50) | 非空 | 规格名，如'中杯/热' |
| price | DECIMAL(10,2) | 非空 | 售价 |
| status | NVARCHAR(20) | 非空，默认'上架' | 上架 / 下架 |

- **主码**：`sku_id`　**候选码**：`(product_id, sku_name)`　**外码**：`product_id→products`

```
样例元组：(1,1,'中杯/热',15.00,'上架'),(2,1,'大杯/冰',18.00,'上架')
```

### 11. `inventory` 库存
> 每个 SKU 在每个门店的数量，防超卖。

| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| sku_id | INT | 主码(组合)，外码→skus | 商品规格 |
| store_id | INT | 主码(组合)，外码→stores | 门店 |
| quantity | INT | 非空，默认 0 | 库存数量 |

- **主码**：`(sku_id, store_id)`　**候选码**：无　**外码**：`sku_id→skus`、`store_id→stores`

```
样例元组：(1,1,50)  -- 图书馆店 中杯/热拿铁 库存 50
```

### 12. `orders` 订单
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| order_id | INT | 主码 | 自增 |
| order_no | NVARCHAR(32) | 候选码，唯一非空 | 订单号 |
| user_id | INT | 非空，外码→users | 下单顾客 |
| store_id | INT | 非空，外码→stores | 取餐门店 |
| pickup_time | DATETIME | 可空 | 期望取餐时间 |
| remark | NVARCHAR(200) | 可空 | 备注 |
| total_amount | DECIMAL(10,2) | 非空 | 订单总额 |
| status | NVARCHAR(20) | 非空 | 待支付/已支付/制作中/待取餐/已完成/已取消/退款中/已退款 |
| created_at | DATETIME | 非空 | 下单时间 |
| paid_at | DATETIME | 可空 | 支付时间 |
| completed_at | DATETIME | 可空 | 完成时间 |

- **主码**：`order_id`　**候选码**：`order_no`　**外码**：`user_id→users`、`store_id→stores`

```
样例元组：(1,'202610060001',1,1,'2026-10-06 12:30','少糖',33.00,'待取餐','2026-10-06 10:05','2026-10-06 10:06',NULL)
```

### 13. `order_items` 订单明细（含商品快照）
> 存下单时的名称/价格快照，防止商品改价后历史订单变化。

| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| order_item_id | INT | 主码 | 自增 |
| order_id | INT | 非空，外码→orders | 所属订单 |
| sku_id | INT | 可空，外码→skus | 关联 SKU（删除后仍留快照） |
| product_name | NVARCHAR(100) | 非空 | 商品名快照 |
| sku_name | NVARCHAR(50) | 非空 | 规格名快照 |
| unit_price | DECIMAL(10,2) | 非空 | 单价快照 |
| quantity | INT | 非空 | 数量 |
| subtotal | DECIMAL(10,2) | 非空 | 小计 = unit_price × quantity |

- **主码**：`order_item_id`　**候选码**：无　**外码**：`order_id→orders`、`sku_id→skus`

```
样例元组：(1,1,1,'拿铁咖啡','中杯/热',15.00,1,15.00),(2,1,2,'拿铁咖啡','大杯/冰',18.00,1,18.00)
```

### 14. `payments` 支付记录
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| payment_id | INT | 主码 | 自增 |
| payment_no | NVARCHAR(32) | 候选码，唯一非空 | 支付单号 |
| order_id | INT | 非空，外码→orders | 订单 |
| channel | NVARCHAR(20) | 非空 | 微信/支付宝/校园卡 |
| channel_trade_no | NVARCHAR(64) | 候选码，唯一可空 | 渠道交易号 |
| amount | DECIMAL(10,2) | 非空 | 金额 |
| status | NVARCHAR(20) | 非空 | 待支付/成功/失败/已退款 |
| paid_at | DATETIME | 可空 | 支付时间 |

- **主码**：`payment_id`　**候选码**：`payment_no`、`channel_trade_no`　**外码**：`order_id→orders`

```
样例元组：(1,'P202610060001',1,'微信','420000123456',33.00,'成功','2026-10-06 10:06:00')
```

### 15. `coupons` 优惠券/活动
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| coupon_id | INT | 主码 | 自增 |
| coupon_name | NVARCHAR(50) | 非空 | 券名/活动名 |
| type | NVARCHAR(20) | 非空 | 满减 / 折扣 |
| value | DECIMAL(10,2) | 非空 | 满减金额或折扣率 |
| min_amount | DECIMAL(10,2) | 非空，默认 0 | 使用门槛 |
| valid_from | DATETIME | 非空 | 生效时间 |
| valid_to | DATETIME | 非空 | 失效时间 |
| total_count | INT | 非空 | 发行量 |
| status | NVARCHAR(20) | 非空，默认'启用' | 启用 / 停用 |

- **主码**：`coupon_id`　**候选码**：无　**外码**：无

```
样例元组：(1,'开学满30减5','满减',5.00,30.00,'2026-09-01 00:00','2026-09-30 23:59',1000,'启用')
```

### 16. `coupon_claims` 优惠券领取记录
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| claim_id | INT | 主码 | 自增 |
| coupon_id | INT | 非空，外码→coupons | 券 |
| user_id | INT | 非空，外码→users | 领取用户 |
| status | NVARCHAR(20) | 非空，默认'未使用' | 未使用/已使用/已过期 |
| claimed_at | DATETIME | 非空 | 领取时间 |
| used_at | DATETIME | 可空 | 使用时间 |

- **主码**：`claim_id`　**候选码**：`(coupon_id, user_id)`　**外码**：`coupon_id→coupons`、`user_id→users`

```
样例元组：(1,1,1,'已使用','2026-09-05 12:00','2026-09-10 09:30')
```

### 17. `pickup_codes` 取餐码/核销
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| pickup_id | INT | 主码 | 自增 |
| order_id | INT | 候选码，唯一，外码→orders | 订单（一单一码） |
| pickup_code | NVARCHAR(20) | 候选码，唯一非空 | 取餐码 |
| status | NVARCHAR(20) | 非空，默认'待取餐' | 待取餐/已核销 |
| verify_employee_id | INT | 可空，外码→employees | 核销店员 |
| verified_at | DATETIME | 可空 | 核销时间 |

- **主码**：`pickup_id`　**候选码**：`order_id`、`pickup_code`　**外码**：`order_id→orders`、`verify_employee_id→employees`

```
样例元组：(1,1,'A102','已核销',2,'2026-10-06 12:28:00')
```

### 18. `reviews` 评价
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| review_id | INT | 主码 | 自增 |
| order_id | INT | 候选码，唯一，外码→orders | 订单（一单一评） |
| user_id | INT | 非空，外码→users | 评价用户 |
| rating | INT | 非空 | 1–5 分 |
| content | NVARCHAR(500) | 可空 | 内容 |
| created_at | DATETIME | 非空 | 时间 |

- **主码**：`review_id`　**候选码**：`order_id`　**外码**：`order_id→orders`、`user_id→users`

```
样例元组：(1,1,1,5,'好喝，取餐快','2026-10-06 12:40:00')
```

### 19. `point_transactions` 积分流水
> 审计积分来源与消费，防止篡改。

| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| transaction_id | INT | 主码 | 自增 |
| user_id | INT | 非空，外码→users | 用户 |
| change_type | NVARCHAR(20) | 非空 | 消费获得/评价获得/兑换消耗/人工调整 |
| points_change | INT | 非空 | 变动分值（正增负减） |
| balance_after | INT | 非空 | 变动后余额 |
| order_id | INT | 可空，外码→orders | 关联订单 |
| created_at | DATETIME | 非空 | 时间 |

- **主码**：`transaction_id`　**候选码**：无　**外码**：`user_id→users`、`order_id→orders`

```
样例元组：(1,1,'消费获得',33,153,1,'2026-10-06 10:06:00'),(2,1,'评价获得',5,158,1,'2026-10-06 12:40:00')
```

### 20. `operation_logs` 操作日志
| 字段 | 域 | 键/约束 | 说明 |
| --- | --- | --- | --- |
| log_id | INT | 主码 | 自增 |
| operator_id | INT | 非空，外码→users | 操作人 |
| action | NVARCHAR(50) | 非空 | 动作 |
| object_type | NVARCHAR(50) | 非空 | 对象类型 |
| object_id | INT | 可空 | 对象 ID |
| detail | NVARCHAR(500) | 可空 | 详情 |
| created_at | DATETIME | 非空 | 时间 |

- **主码**：`log_id`　**候选码**：无　**外码**：`operator_id→users`

```
样例元组：(1,3,'下架商品','product',5,'库存不足临时下架','2026-10-06 11:00:00')
```

---

## 四、关系与码汇总

| 关系名 | 主码 | 候选码 | 外码 |
| --- | --- | --- | --- |
| users | user_id | username, phone, email | — |
| roles | role_id | role_name | — |
| permissions | permission_id | permission_name | — |
| role_permissions | (role_id, permission_id) | — | role_id, permission_id |
| user_roles | (user_id, role_id) | — | user_id, role_id |
| stores | store_id | store_name | — |
| employees | employee_id | user_id | user_id, store_id |
| categories | category_id | category_name | parent_id |
| products | product_id | — | category_id |
| skus | sku_id | (product_id, sku_name) | product_id |
| inventory | (sku_id, store_id) | — | sku_id, store_id |
| orders | order_id | order_no | user_id, store_id |
| order_items | order_item_id | — | order_id, sku_id |
| payments | payment_id | payment_no, channel_trade_no | order_id |
| coupons | coupon_id | — | — |
| coupon_claims | claim_id | (coupon_id, user_id) | coupon_id, user_id |
| pickup_codes | pickup_id | order_id, pickup_code | order_id, verify_employee_id |
| reviews | review_id | order_id | order_id, user_id |
| point_transactions | transaction_id | — | user_id, order_id |
| operation_logs | log_id | — | operator_id |

---

## 五、外码引用关系（核心链路）

```
users ──< user_roles >── roles ──< role_permissions >── permissions
users ──< orders ──< order_items >── skus >── products >── categories
stores ──< inventory >── skus
stores ──< employees >── users
orders ──< payments
orders ──< pickup_codes >── employees
orders ──< reviews >── users
users ──< coupon_claims >── coupons
users ──< point_transactions >── orders
users ──< operation_logs
```
