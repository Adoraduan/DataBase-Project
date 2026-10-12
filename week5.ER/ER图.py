# -*- coding: utf-8 -*-
"""
校园咖啡店线上点单自取系统 — ER 图（箭头记号版）

关系两端规则（仅“箭头 / 无箭头”两种形式）：
  箭头  = 一（1）
  无箭头 = 多（N）
  · 1 : 1       -> 两端都打箭头
  · 1 : N / N:1 -> 在“一”的实体打箭头
  · M : N       -> 不用箭头，直接一根线连接
  · 严格非一数量（如 3 : 2）-> 在对应实体接口旁写数字（见 RELATIONS 的 count 字段）

使用：python ER图.py
输出：ER图.png
依赖：matplotlib, networkx
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import networkx as nx

# 中文字体（仅关系标签使用）
plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei", "Arial"]
plt.rcParams["axes.unicode_minus"] = False

# ---------------- 实体 ----------------
# (名称, [属性行...])  属性行保留 PK / FK / UK 注释
ENTITIES = [
    ("users", ["user_id : int  PK", "username : varchar  UK", "phone : varchar  UK",
               "email : varchar  UK", "points_balance : int", "status : varchar"]),
    ("roles", ["role_id : int  PK", "role_name : varchar  UK"]),
    ("permissions", ["permission_id : int  PK", "permission_name : varchar  UK"]),
    ("user_roles", ["user_id : int  PK  FK→users", "role_id : int  PK  FK→roles"]),
    ("role_permissions", ["role_id : int  PK  FK→roles", "permission_id : int  PK  FK→permissions"]),
    ("stores", ["store_id : int  PK", "store_name : varchar  UK", "status : varchar"]),
    ("employees", ["employee_id : int  PK", "user_id : int  FK  UK", "store_id : int  FK", "position : varchar"]),
    ("categories", ["category_id : int  PK", "parent_id : int  FK", "category_name : varchar  UK"]),
    ("products", ["product_id : int  PK", "category_id : int  FK", "product_name : varchar", "status : varchar"]),
    ("skus", ["sku_id : int  PK", "product_id : int  FK", "sku_name : varchar", "price : decimal", "status : varchar"]),
    ("inventory", ["sku_id : int  PK  FK→skus", "store_id : int  PK  FK→stores", "quantity : int"]),
    ("orders", ["order_id : int  PK", "order_no : varchar  UK", "user_id : int  FK", "store_id : int  FK",
                "total_amount : decimal", "status : varchar"]),
    ("order_items", ["order_item_id : int  PK", "order_id : int  FK", "sku_id : int  FK",
                     "unit_price : decimal", "quantity : int", "subtotal : decimal"]),
    ("payments", ["payment_id : int  PK", "payment_no : varchar  UK", "order_id : int  FK",
                  "channel : varchar", "amount : decimal", "status : varchar"]),
    ("pickup_codes", ["pickup_id : int  PK", "order_id : int  UK  FK→orders", "pickup_code : varchar  UK",
                      "verify_employee_id : int  FK", "status : varchar"]),
    ("coupons", ["coupon_id : int  PK", "type : varchar", "value : decimal", "min_amount : decimal", "status : varchar"]),
    ("coupon_claims", ["claim_id : int  PK", "coupon_id : int  FK", "user_id : int  FK", "status : varchar"]),
    ("reviews", ["review_id : int  PK", "order_id : int  UK  FK→orders", "user_id : int  FK", "rating : int"]),
    ("point_transactions", ["transaction_id : int  PK", "user_id : int  FK", "order_id : int  FK",
                            "points_change : int", "balance_after : int"]),
    ("operation_logs", ["log_id : int  PK", "operator_id : int  FK", "action : varchar"]),
]

# 关联实体（join 表）单独着色，便于识别
JOIN = {"user_roles", "role_permissions", "inventory", "coupon_claims"}

# ---------------- 关系 ----------------
# (实体A, 实体B, 箭头端, 标签, A端数量, B端数量)
#   箭头端: "both"=两端箭头(1:1) / "a"=A端箭头(A为“一”) / "b"=B端箭头(B为“一”) / "none"=无线(M:N)
#   数量: 仅“严格的非一数量”时填写(如 3:2 -> "3", "2")，普通 1/N 留空 ""
RELATIONS = [
    ("users",          "user_roles",        "a",    "拥有角色",   "", ""),
    ("roles",          "user_roles",        "a",    "赋予用户",   "", ""),
    ("roles",          "role_permissions",  "a",    "具备权限",   "", ""),
    ("permissions",    "role_permissions",  "a",    "授予角色",   "", ""),
    ("stores",         "employees",         "a",    "拥有员工",   "", ""),
    ("users",          "employees",         "both", "登录账号",   "", ""),
    ("categories",     "categories",        "a",    "父子分类",   "", ""),
    ("categories",     "products",          "a",    "分类",       "", ""),
    ("products",       "skus",              "a",    "规格",       "", ""),
    ("skus",           "inventory",         "a",    "库存",       "", ""),
    ("stores",         "inventory",         "a",    "库存",       "", ""),
    ("users",          "orders",            "a",    "下单",       "", ""),
    ("stores",         "orders",            "a",    "取餐门店",   "", ""),
    ("orders",         "order_items",       "a",    "明细",       "", ""),
    ("skus",           "order_items",       "a",    "快照来源",   "", ""),
    ("orders",         "payments",          "a",    "支付",       "", ""),
    ("orders",         "pickup_codes",      "both", "一单一码",   "", ""),
    ("employees",      "pickup_codes",      "a",    "核销",       "", ""),
    ("coupons",        "coupon_claims",     "a",    "发放",       "", ""),
    ("users",          "coupon_claims",     "a",    "领取",       "", ""),
    ("orders",         "reviews",           "both", "一单一评",   "", ""),
    ("users",          "reviews",           "a",    "评价",       "", ""),
    ("users",          "point_transactions","a",    "积分流水",   "", ""),
    ("orders",         "point_transactions","a",    "关联订单",   "", ""),
    ("users",          "operation_logs",    "a",    "操作",       "", ""),
]

# ---------------- 样式 ----------------
DPI = 160
TITLE_FS = 11       # 实体名
ATTR_FS = 9         # 属性行
LABEL_FS = 10       # 关系标签
TITLE_LH = TITLE_FS * 1.5
ATTR_LH = ATTR_FS * 1.6
PADX, PADY = 9, 7
MONO = "DejaVu Sans Mono"

FILL = "#EEF3F8"        # 普通实体填充
JOIN_FILL = "#FDF0E2"   # 关联实体填充
BORDER = "#33475B"
TITLE_C = "#1F2A36"
ATTR_C = "#24323E"
EDGE_C = "#5A6B7B"
LABEL_C = "#35424E"
GAP = 28                # 实体间最小间距(pt)


def measure(s, fs, weight="normal", family=MONO):
    t = ax.text(0, 0, s, fontsize=fs, family=family, weight=weight)
    bb = t.get_window_extent(renderer=renderer)
    w = bb.width * 72.0 / DPI
    t.remove()
    return w


def entity_size(name, attrs):
    w = max([measure(name, TITLE_FS, "bold")] + [measure(a, ATTR_FS) for a in attrs])
    w += 2 * PADX
    h = 2 * PADY + TITLE_LH + len(attrs) * ATTR_LH
    return w, h


def boundary(cx, cy, w, h, tx, ty):
    """矩形(中心cx,cy 半宽w/2 半高h/2)边界上朝向(tx,ty)的点"""
    dx, dy = tx - cx, ty - cy
    hw, hh = w / 2.0, h / 2.0
    if abs(dx) < 1e-9:
        return (cx, cy + np.sign(dy) * hh) if dy != 0 else (cx, cy)
    slope = dy / dx
    if abs(slope) < hh / hw:
        sx = np.sign(dx) * hw
        return (cx + sx, cy + slope * sx)
    sy = np.sign(dy) * hh
    return (cx + sy / slope, cy + sy)


# ---------------- 布局 ----------------
names = [n for n, _ in ENTITIES]
attrs_of = {n: a for n, a in ENTITIES}

# 先建一个临时 fig 用于量文本尺寸
fig = plt.figure(dpi=DPI)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_aspect("equal")
renderer = fig.canvas.get_renderer()

sizes = {n: entity_size(n, attrs_of[n]) for n in names}

G = nx.Graph()
G.add_nodes_from(names)
for a, b, _, _, _, _ in RELATIONS:
    G.add_edge(a, b)

pos = nx.spring_layout(G, seed=42, k=2.2, iterations=400, scale=640)

# 简单 AABB 重叠消除（考虑实体框大小）
pos = {n: np.array(p, dtype=float) for n, p in pos.items()}
for _ in range(400):
    moved = False
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            a, b = names[i], names[j]
            d = pos[b] - pos[a]
            hw = (sizes[a][0] + sizes[b][0]) / 2.0 + GAP
            hh = (sizes[a][1] + sizes[b][1]) / 2.0 + GAP
            ovx = hw - abs(d[0])
            ovy = hh - abs(d[1])
            if ovx > 0 and ovy > 0:
                if ovx < ovy:
                    sgn = 1.0 if d[0] >= 0 else -1.0
                    sh = ovx / 2.0
                    pos[a][0] -= sgn * sh
                    pos[b][0] += sgn * sh
                else:
                    sgn = 1.0 if d[1] >= 0 else -1.0
                    sh = ovy / 2.0
                    pos[a][1] -= sgn * sh
                    pos[b][1] += sgn * sh
                moved = True
    if not moved:
        break

# ---------------- 计算画布 ----------------
minx = min(p[0] - sizes[n][0] / 2 for n, p in pos.items())
maxx = max(p[0] + sizes[n][0] / 2 for n, p in pos.items())
miny = min(p[1] - sizes[n][1] / 2 for n, p in pos.items())
maxy = max(p[1] + sizes[n][1] / 2 for n, p in pos.items())
M = 70
W, H = (maxx - minx) + 2 * M, (maxy - miny) + 2 * M
fig.set_size_inches(W / 72.0, H / 72.0)
ax.set_xlim(minx - M, maxx + M)
ax.set_ylim(miny - M, maxy + M)
ax.axis("off")

# ---------------- 画关系 ----------------
for a, b, arrow, label, ca, cb in RELATIONS:
    if a == b:  # 自引用（categories 父子分类）
        cx, cy = pos[a]
        w, h = sizes[a]
        x0, x1 = cx - w * 0.18, cx + w * 0.18
        top = cy + h / 2
        ax.add_patch(FancyArrowPatch((x0, top), (x1, top),
                                     connectionstyle="arc3,rad=-0.55", arrowstyle="-|>",
                                     color=EDGE_C, lw=1.1, mutation_scale=16, shrinkA=0, shrinkB=0))
        ax.text(cx, top + 30, label, ha="center", va="center", fontsize=LABEL_FS, color=LABEL_C,
                bbox=dict(boxstyle="round,pad=0.25", fc="white", ec="none", alpha=0.85))
        continue

    pa = boundary(pos[a][0], pos[a][1], *sizes[a], pos[b][0], pos[b][1])
    pb = boundary(pos[b][0], pos[b][1], *sizes[b], pos[a][0], pos[a][1])

    if arrow == "both":
        style, A, B = "<|-|>", pa, pb
    elif arrow == "a":
        style, A, B = "-|>", pb, pa   # 箭头在 A 端
    elif arrow == "b":
        style, A, B = "-|>", pa, pb   # 箭头在 B 端
    else:
        style, A, B = "-", pa, pb

    ax.add_patch(FancyArrowPatch(A, B, arrowstyle=style, color=EDGE_C, lw=1.1,
                                 mutation_scale=16, shrinkA=0, shrinkB=0))

    mx, my = (A[0] + B[0]) / 2, (A[1] + B[1]) / 2
    ax.text(mx, my, label, ha="center", va="center", fontsize=LABEL_FS, color=LABEL_C,
            bbox=dict(boxstyle="round,pad=0.25", fc="white", ec="none", alpha=0.85))

    # 严格非一数量（如 3:2）：在对应实体接口旁写数字
    if ca:
        ax.text(pa[0], pa[1], ca, ha="center", va="center", fontsize=LABEL_FS,
                color="#B03A2E", fontweight="bold",
                bbox=dict(boxstyle="circle,pad=0.15", fc="white", ec="#B03A2E", lw=0.8))
    if cb:
        ax.text(pb[0], pb[1], cb, ha="center", va="center", fontsize=LABEL_FS,
                color="#B03A2E", fontweight="bold",
                bbox=dict(boxstyle="circle,pad=0.15", fc="white", ec="#B03A2E", lw=0.8))

# ---------------- 画实体 ----------------
for name, attrs in ENTITIES:
    cx, cy = pos[name]
    w, h = sizes[name]
    fill = JOIN_FILL if name in JOIN else FILL
    ax.add_patch(FancyBboxPatch((cx - w / 2, cy - h / 2), w, h,
                                boxstyle="round,pad=0,rounding_size=6",
                                linewidth=1.2, edgecolor=BORDER, facecolor=fill))
    top = cy + h / 2
    ax.text(cx, top - PADY - TITLE_LH / 2, name, ha="center", va="center",
            fontsize=TITLE_FS, weight="bold", family=MONO, color=TITLE_C)
    sep_y = top - PADY - TITLE_LH
    ax.plot([cx - w / 2 + 6, cx + w / 2 - 6], [sep_y, sep_y], color=BORDER, lw=0.7)
    for i, a in enumerate(attrs):
        ay = sep_y - ATTR_LH / 2 - i * ATTR_LH
        ax.text(cx - w / 2 + PADX, ay, a, ha="left", va="center",
                fontsize=ATTR_FS, family=MONO, color=ATTR_C)

fig.savefig("ER图.png", dpi=DPI, facecolor="white")
print("已生成 ER图.png，尺寸 %.0f x %.0f pt (%.1f x %.1f in)" % (W, H, W / 72.0, H / 72.0))
