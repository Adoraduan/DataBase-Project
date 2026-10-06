/* ============================================================
   校园咖啡店线上点单自取系统 - 关系模式 DDL
   Microsoft SQL Server
   ============================================================ */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF DB_ID(N'CampusCoffee') IS NULL
    CREATE DATABASE CampusCoffee;
GO

USE CampusCoffee;
GO

/* ============================================================
   1. users 用户账号
   ============================================================ */
CREATE TABLE dbo.users (
    user_id         INT IDENTITY(1,1) NOT NULL,
    username        NVARCHAR(50)      NOT NULL,
    phone           VARCHAR(11)       NOT NULL,
    email           VARCHAR(100)      NULL,
    password_hash   NVARCHAR(128)     NOT NULL,
    status          NVARCHAR(20)      NOT NULL CONSTRAINT DF_users_status DEFAULT N'正常',
    points_balance  INT               NOT NULL CONSTRAINT DF_users_points_balance DEFAULT 0,
    created_at      DATETIME          NOT NULL CONSTRAINT DF_users_created_at DEFAULT GETDATE(),

    CONSTRAINT PK_users PRIMARY KEY (user_id),
    CONSTRAINT UQ_users_username UNIQUE (username),
    CONSTRAINT UQ_users_phone UNIQUE (phone),
    CONSTRAINT CK_users_status CHECK (status IN (N'正常', N'停用'))
);
GO

CREATE UNIQUE INDEX UX_users_email
ON dbo.users(email)
WHERE email IS NOT NULL;
GO

/* ============================================================
   2. roles 角色
   ============================================================ */
CREATE TABLE dbo.roles (
    role_id     INT IDENTITY(1,1) NOT NULL,
    role_name   NVARCHAR(50)      NOT NULL,
    description NVARCHAR(200)     NULL,

    CONSTRAINT PK_roles PRIMARY KEY (role_id),
    CONSTRAINT UQ_roles_role_name UNIQUE (role_name)
);
GO

/* ============================================================
   3. permissions 权限
   ============================================================ */
CREATE TABLE dbo.permissions (
    permission_id   INT IDENTITY(1,1) NOT NULL,
    permission_name NVARCHAR(50)      NOT NULL,
    description     NVARCHAR(200)     NULL,

    CONSTRAINT PK_permissions PRIMARY KEY (permission_id),
    CONSTRAINT UQ_permissions_permission_name UNIQUE (permission_name)
);
GO

/* ============================================================
   4. role_permissions 角色-权限关系
   ============================================================ */
CREATE TABLE dbo.role_permissions (
    role_id       INT NOT NULL,
    permission_id INT NOT NULL,

    CONSTRAINT PK_role_permissions PRIMARY KEY (role_id, permission_id),
    CONSTRAINT FK_role_permissions_roles
        FOREIGN KEY (role_id) REFERENCES dbo.roles(role_id),
    CONSTRAINT FK_role_permissions_permissions
        FOREIGN KEY (permission_id) REFERENCES dbo.permissions(permission_id)
);
GO

/* ============================================================
   5. user_roles 用户-角色关系
   ============================================================ */
CREATE TABLE dbo.user_roles (
    user_id INT NOT NULL,
    role_id INT NOT NULL,

    CONSTRAINT PK_user_roles PRIMARY KEY (user_id, role_id),
    CONSTRAINT FK_user_roles_users
        FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT FK_user_roles_roles
        FOREIGN KEY (role_id) REFERENCES dbo.roles(role_id)
);
GO

/* ============================================================
   6. stores 门店
   ============================================================ */
CREATE TABLE dbo.stores (
    store_id   INT IDENTITY(1,1) NOT NULL,
    store_name NVARCHAR(50)      NOT NULL,
    address    NVARCHAR(200)     NULL,
    phone      VARCHAR(11)       NULL,
    status     NVARCHAR(20)      NOT NULL CONSTRAINT DF_stores_status DEFAULT N'营业',

    CONSTRAINT PK_stores PRIMARY KEY (store_id),
    CONSTRAINT UQ_stores_store_name UNIQUE (store_name),
    CONSTRAINT CK_stores_status CHECK (status IN (N'营业', N'停业'))
);
GO

/* ============================================================
   7. employees 员工
   ============================================================ */
CREATE TABLE dbo.employees (
    employee_id INT IDENTITY(1,1) NOT NULL,
    user_id     INT               NULL,
    store_id    INT               NOT NULL,
    name        NVARCHAR(50)      NOT NULL,
    position    NVARCHAR(20)      NOT NULL,
    hire_date   DATE              NULL,

    CONSTRAINT PK_employees PRIMARY KEY (employee_id),
    CONSTRAINT FK_employees_users
        FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT FK_employees_stores
        FOREIGN KEY (store_id) REFERENCES dbo.stores(store_id),
    CONSTRAINT CK_employees_position CHECK (position IN (N'店员', N'店长'))
);
GO

CREATE UNIQUE INDEX UX_employees_user_id
ON dbo.employees(user_id)
WHERE user_id IS NOT NULL;
GO

/* ============================================================
   8. categories 商品分类
   ============================================================ */
CREATE TABLE dbo.categories (
    category_id   INT IDENTITY(1,1) NOT NULL,
    parent_id     INT               NULL,
    category_name NVARCHAR(50)      NOT NULL,
    sort_order    INT               NOT NULL CONSTRAINT DF_categories_sort_order DEFAULT 0,

    CONSTRAINT PK_categories PRIMARY KEY (category_id),
    CONSTRAINT UQ_categories_category_name UNIQUE (category_name),
    CONSTRAINT FK_categories_categories
        FOREIGN KEY (parent_id) REFERENCES dbo.categories(category_id)
);
GO

/* ============================================================
   9. products 商品
   ============================================================ */
CREATE TABLE dbo.products (
    product_id   INT IDENTITY(1,1) NOT NULL,
    category_id  INT               NOT NULL,
    product_name NVARCHAR(100)     NOT NULL,
    description  NVARCHAR(500)     NULL,
    image_url    NVARCHAR(255)     NULL,
    status       NVARCHAR(20)      NOT NULL CONSTRAINT DF_products_status DEFAULT N'上架',
    created_at   DATETIME          NOT NULL CONSTRAINT DF_products_created_at DEFAULT GETDATE(),

    CONSTRAINT PK_products PRIMARY KEY (product_id),
    CONSTRAINT FK_products_categories
        FOREIGN KEY (category_id) REFERENCES dbo.categories(category_id),
    CONSTRAINT CK_products_status CHECK (status IN (N'上架', N'下架'))
);
GO

/* ============================================================
   10. skus 商品规格(SKU)
   ============================================================ */
CREATE TABLE dbo.skus (
    sku_id     INT IDENTITY(1,1) NOT NULL,
    product_id INT               NOT NULL,
    sku_name   NVARCHAR(50)      NOT NULL,
    price      DECIMAL(10,2)     NOT NULL,
    status     NVARCHAR(20)      NOT NULL CONSTRAINT DF_skus_status DEFAULT N'上架',

    CONSTRAINT PK_skus PRIMARY KEY (sku_id),
    CONSTRAINT UQ_skus_product_sku_name UNIQUE (product_id, sku_name),
    CONSTRAINT FK_skus_products
        FOREIGN KEY (product_id) REFERENCES dbo.products(product_id),
    CONSTRAINT CK_skus_status CHECK (status IN (N'上架', N'下架')),
    CONSTRAINT CK_skus_price CHECK (price >= 0)
);
GO

/* ============================================================
   11. inventory 库存
   ============================================================ */
CREATE TABLE dbo.inventory (
    sku_id   INT NOT NULL,
    store_id INT NOT NULL,
    quantity INT NOT NULL CONSTRAINT DF_inventory_quantity DEFAULT 0,

    CONSTRAINT PK_inventory PRIMARY KEY (sku_id, store_id),
    CONSTRAINT FK_inventory_skus
        FOREIGN KEY (sku_id) REFERENCES dbo.skus(sku_id),
    CONSTRAINT FK_inventory_stores
        FOREIGN KEY (store_id) REFERENCES dbo.stores(store_id),
    CONSTRAINT CK_inventory_quantity CHECK (quantity >= 0)
);
GO

/* ============================================================
   12. orders 订单
   ============================================================ */
CREATE TABLE dbo.orders (
    order_id     INT IDENTITY(1,1) NOT NULL,
    order_no     NVARCHAR(32)      NOT NULL,
    user_id      INT               NOT NULL,
    store_id     INT               NOT NULL,
    pickup_time  DATETIME          NULL,
    remark       NVARCHAR(200)     NULL,
    total_amount DECIMAL(10,2)     NOT NULL,
    status       NVARCHAR(20)      NOT NULL CONSTRAINT DF_orders_status DEFAULT N'待支付',
    created_at   DATETIME          NOT NULL CONSTRAINT DF_orders_created_at DEFAULT GETDATE(),
    paid_at      DATETIME          NULL,
    completed_at DATETIME          NULL,

    CONSTRAINT PK_orders PRIMARY KEY (order_id),
    CONSTRAINT UQ_orders_order_no UNIQUE (order_no),
    CONSTRAINT FK_orders_users
        FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT FK_orders_stores
        FOREIGN KEY (store_id) REFERENCES dbo.stores(store_id),
    CONSTRAINT CK_orders_status CHECK (
        status IN (
            N'待支付', N'已支付', N'制作中', N'待取餐',
            N'已完成', N'已取消', N'退款中', N'已退款'
        )
    ),
    CONSTRAINT CK_orders_total_amount CHECK (total_amount >= 0)
);
GO

/* ============================================================
   13. order_items 订单明细（含商品快照）
   ============================================================ */
CREATE TABLE dbo.order_items (
    order_item_id INT IDENTITY(1,1) NOT NULL,
    order_id      INT               NOT NULL,
    sku_id        INT               NULL,
    product_name  NVARCHAR(100)     NOT NULL,
    sku_name      NVARCHAR(50)      NOT NULL,
    unit_price    DECIMAL(10,2)     NOT NULL,
    quantity      INT               NOT NULL,
    subtotal      DECIMAL(10,2)     NOT NULL,

    CONSTRAINT PK_order_items PRIMARY KEY (order_item_id),
    CONSTRAINT FK_order_items_orders
        FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),
    CONSTRAINT FK_order_items_skus
        FOREIGN KEY (sku_id) REFERENCES dbo.skus(sku_id),
    CONSTRAINT CK_order_items_unit_price CHECK (unit_price >= 0),
    CONSTRAINT CK_order_items_quantity CHECK (quantity > 0),
    CONSTRAINT CK_order_items_subtotal CHECK (subtotal >= 0)
);
GO

/* ============================================================
   14. payments 支付记录
   ============================================================ */
CREATE TABLE dbo.payments (
    payment_id       INT IDENTITY(1,1) NOT NULL,
    payment_no       NVARCHAR(32)      NOT NULL,
    order_id         INT               NOT NULL,
    channel          NVARCHAR(20)      NOT NULL,
    channel_trade_no NVARCHAR(64)      NULL,
    amount           DECIMAL(10,2)     NOT NULL,
    status           NVARCHAR(20)      NOT NULL CONSTRAINT DF_payments_status DEFAULT N'待支付',
    paid_at          DATETIME          NULL,

    CONSTRAINT PK_payments PRIMARY KEY (payment_id),
    CONSTRAINT UQ_payments_payment_no UNIQUE (payment_no),
    CONSTRAINT FK_payments_orders
        FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),
    CONSTRAINT CK_payments_channel CHECK (channel IN (N'微信', N'支付宝', N'校园卡')),
    CONSTRAINT CK_payments_status CHECK (status IN (N'待支付', N'成功', N'失败', N'已退款')),
    CONSTRAINT CK_payments_amount CHECK (amount >= 0)
);
GO

CREATE UNIQUE INDEX UX_payments_channel_trade_no
ON dbo.payments(channel_trade_no)
WHERE channel_trade_no IS NOT NULL;
GO

/* ============================================================
   15. coupons 优惠券/活动
   ============================================================ */
CREATE TABLE dbo.coupons (
    coupon_id   INT IDENTITY(1,1) NOT NULL,
    coupon_name NVARCHAR(50)      NOT NULL,
    [type]      NVARCHAR(20)      NOT NULL,
    [value]     DECIMAL(10,2)     NOT NULL,
    min_amount  DECIMAL(10,2)     NOT NULL CONSTRAINT DF_coupons_min_amount DEFAULT 0,
    valid_from  DATETIME          NOT NULL,
    valid_to    DATETIME          NOT NULL,
    total_count INT               NOT NULL,
    status      NVARCHAR(20)      NOT NULL CONSTRAINT DF_coupons_status DEFAULT N'启用',

    CONSTRAINT PK_coupons PRIMARY KEY (coupon_id),
    CONSTRAINT CK_coupons_type CHECK ([type] IN (N'满减', N'折扣')),
    CONSTRAINT CK_coupons_value CHECK ([value] >= 0),
    CONSTRAINT CK_coupons_min_amount CHECK (min_amount >= 0),
    CONSTRAINT CK_coupons_total_count CHECK (total_count >= 0),
    CONSTRAINT CK_coupons_status CHECK (status IN (N'启用', N'停用')),
    CONSTRAINT CK_coupons_valid CHECK (valid_to >= valid_from)
);
GO

/* ============================================================
   16. coupon_claims 优惠券领取记录
   ============================================================ */
CREATE TABLE dbo.coupon_claims (
    claim_id   INT IDENTITY(1,1) NOT NULL,
    coupon_id  INT               NOT NULL,
    user_id    INT               NOT NULL,
    status     NVARCHAR(20)      NOT NULL CONSTRAINT DF_coupon_claims_status DEFAULT N'未使用',
    claimed_at DATETIME          NOT NULL CONSTRAINT DF_coupon_claims_claimed_at DEFAULT GETDATE(),
    used_at    DATETIME          NULL,

    CONSTRAINT PK_coupon_claims PRIMARY KEY (claim_id),
    CONSTRAINT UQ_coupon_claims_coupon_user UNIQUE (coupon_id, user_id),
    CONSTRAINT FK_coupon_claims_coupons
        FOREIGN KEY (coupon_id) REFERENCES dbo.coupons(coupon_id),
    CONSTRAINT FK_coupon_claims_users
        FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT CK_coupon_claims_status CHECK (status IN (N'未使用', N'已使用', N'已过期'))
);
GO

/* ============================================================
   17. pickup_codes 取餐码/核销
   ============================================================ */
CREATE TABLE dbo.pickup_codes (
    pickup_id          INT IDENTITY(1,1) NOT NULL,
    order_id           INT               NOT NULL,
    pickup_code        NVARCHAR(20)      NOT NULL,
    status             NVARCHAR(20)      NOT NULL CONSTRAINT DF_pickup_codes_status DEFAULT N'待取餐',
    verify_employee_id INT               NULL,
    verified_at        DATETIME          NULL,

    CONSTRAINT PK_pickup_codes PRIMARY KEY (pickup_id),
    CONSTRAINT UQ_pickup_codes_order_id UNIQUE (order_id),
    CONSTRAINT UQ_pickup_codes_pickup_code UNIQUE (pickup_code),
    CONSTRAINT FK_pickup_codes_orders
        FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),
    CONSTRAINT FK_pickup_codes_employees
        FOREIGN KEY (verify_employee_id) REFERENCES dbo.employees(employee_id),
    CONSTRAINT CK_pickup_codes_status CHECK (status IN (N'待取餐', N'已核销'))
);
GO

/* ============================================================
   18. reviews 评价
   ============================================================ */
CREATE TABLE dbo.reviews (
    review_id  INT IDENTITY(1,1) NOT NULL,
    order_id   INT               NOT NULL,
    user_id    INT               NOT NULL,
    rating     INT               NOT NULL,
    content    NVARCHAR(500)     NULL,
    created_at DATETIME          NOT NULL CONSTRAINT DF_reviews_created_at DEFAULT GETDATE(),

    CONSTRAINT PK_reviews PRIMARY KEY (review_id),
    CONSTRAINT UQ_reviews_order_id UNIQUE (order_id),
    CONSTRAINT FK_reviews_orders
        FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),
    CONSTRAINT FK_reviews_users
        FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT CK_reviews_rating CHECK (rating BETWEEN 1 AND 5)
);
GO

/* ============================================================
   19. point_transactions 积分流水
   ============================================================ */
CREATE TABLE dbo.point_transactions (
    transaction_id INT IDENTITY(1,1) NOT NULL,
    user_id        INT               NOT NULL,
    change_type    NVARCHAR(20)      NOT NULL,
    points_change  INT               NOT NULL,
    balance_after  INT               NOT NULL,
    order_id       INT               NULL,
    created_at     DATETIME          NOT NULL CONSTRAINT DF_point_transactions_created_at DEFAULT GETDATE(),

    CONSTRAINT PK_point_transactions PRIMARY KEY (transaction_id),
    CONSTRAINT FK_point_transactions_users
        FOREIGN KEY (user_id) REFERENCES dbo.users(user_id),
    CONSTRAINT FK_point_transactions_orders
        FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),
    CONSTRAINT CK_point_transactions_change_type CHECK (
        change_type IN (N'消费获得', N'评价获得', N'兑换消耗', N'人工调整')
    ),
    CONSTRAINT CK_point_transactions_balance_after CHECK (balance_after >= 0)
);
GO

/* ============================================================
   20. operation_logs 操作日志
   ============================================================ */
CREATE TABLE dbo.operation_logs (
    log_id      INT IDENTITY(1,1) NOT NULL,
    operator_id INT               NOT NULL,
    [action]    NVARCHAR(50)      NOT NULL,
    object_type NVARCHAR(50)      NOT NULL,
    object_id   INT               NULL,
    detail      NVARCHAR(500)     NULL,
    created_at  DATETIME          NOT NULL CONSTRAINT DF_operation_logs_created_at DEFAULT GETDATE(),

    CONSTRAINT PK_operation_logs PRIMARY KEY (log_id),
    CONSTRAINT FK_operation_logs_users
        FOREIGN KEY (operator_id) REFERENCES dbo.users(user_id)
);
GO

/* ============================================================
   常用外键列索引（可选，提升查询性能）
   ============================================================ */
CREATE INDEX IX_user_roles_role_id ON dbo.user_roles(role_id);
CREATE INDEX IX_role_permissions_permission_id ON dbo.role_permissions(permission_id);
CREATE INDEX IX_employees_store_id ON dbo.employees(store_id);
CREATE INDEX IX_products_category_id ON dbo.products(category_id);
CREATE INDEX IX_skus_product_id ON dbo.skus(product_id);
CREATE INDEX IX_inventory_store_id ON dbo.inventory(store_id);
CREATE INDEX IX_orders_user_id ON dbo.orders(user_id);
CREATE INDEX IX_orders_store_id ON dbo.orders(store_id);
CREATE INDEX IX_order_items_order_id ON dbo.order_items(order_id);
CREATE INDEX IX_order_items_sku_id ON dbo.order_items(sku_id);
CREATE INDEX IX_payments_order_id ON dbo.payments(order_id);
CREATE INDEX IX_coupon_claims_user_id ON dbo.coupon_claims(user_id);
CREATE INDEX IX_pickup_codes_verify_employee_id ON dbo.pickup_codes(verify_employee_id);
CREATE INDEX IX_reviews_user_id ON dbo.reviews(user_id);
CREATE INDEX IX_point_transactions_user_id ON dbo.point_transactions(user_id);
CREATE INDEX IX_point_transactions_order_id ON dbo.point_transactions(order_id);
CREATE INDEX IX_operation_logs_operator_id ON dbo.operation_logs(operator_id);
GO