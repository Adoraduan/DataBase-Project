from datetime import datetime
from decimal import Decimal
from uuid import uuid4

from ..dal import inventory as inventory_dal
from ..dal import orders as orders_dal
from ..dal import products as products_dal
from ..dal import stores as stores_dal
from ..db import read_connection, transaction
from ..errors import bad_request, forbidden, not_found, rule_violated
from .validation import optional_datetime, optional_text, require_int

NEXT_STATUS = {"已支付": "制作中", "制作中": "待取餐", "待取餐": "已完成"}


def _money(value):
    return float(Decimal(value).quantize(Decimal("0.01")))


def _time(value):
    return value.strftime("%Y-%m-%d %H:%M") if value else None


def _order_dict(row, items=None):
    data = {
        "order_id": row["order_id"],
        "order_no": row["order_no"],
        "user_id": row["user_id"],
        "username": row["username"],
        "store_id": row["store_id"],
        "store_name": row["store_name"],
        "pickup_time": _time(row["pickup_time"]),
        "remark": row["remark"],
        "total_amount": _money(row["total_amount"]),
        "status": row["status"],
        "created_at": _time(row["created_at"]),
        "paid_at": _time(row["paid_at"]),
        "completed_at": _time(row["completed_at"]),
        "item_count": row["item_count"],
    }
    if items is not None:
        data["items"] = items
    return data


def _item_dict(row):
    return {
        "order_item_id": row["order_item_id"],
        "order_id": row["order_id"],
        "sku_id": row["sku_id"],
        "product_name": row["product_name"],
        "sku_name": row["sku_name"],
        "unit_price": _money(row["unit_price"]),
        "quantity": row["quantity"],
        "subtotal": _money(row["subtotal"]),
    }


def _order_no():
    return "CO" + datetime.now().strftime("%Y%m%d%H%M%S") + uuid4().hex[:4]


def list_orders(user):
    user_filter = user["user_id"] if user["role"] == "customer" else None
    with read_connection() as conn:
        rows = orders_dal.list_orders(conn, user_id=user_filter)
    return [_order_dict(row) for row in rows]


def get_order(user, order_id):
    with read_connection() as conn:
        row = orders_dal.get_order(conn, order_id)
        if not row:
            raise not_found("订单不存在")
        if user["role"] == "customer" and row["user_id"] != user["user_id"]:
            raise forbidden("只能查看自己的订单")
        items = [_item_dict(item) for item in orders_dal.list_items(conn, order_id)]
    return _order_dict(row, items)


def _owned_order(conn, user, order_id, unpaid_only=False):
    row = orders_dal.get_order(conn, order_id)
    if not row:
        raise not_found("订单不存在")
    if row["user_id"] != user["user_id"]:
        raise forbidden("只能操作自己的订单")
    if unpaid_only and row["status"] != "待支付":
        raise rule_violated("只有待支付订单可以修改")
    return row


def _require_on_sale_sku(conn, sku_id):
    sku = products_dal.get_sku(conn, sku_id)
    if not sku:
        raise not_found("商品规格不存在")
    if sku["status"] != "上架" or sku["product_status"] != "上架":
        raise rule_violated("商品已下架")
    return sku


def _refresh_total(conn, order_id):
    orders_dal.update_total(conn, order_id, orders_dal.sum_items(conn, order_id))


def _change_quantity(conn, order, item, new_quantity):
    if item["sku_id"] is not None:
        delta = new_quantity - item["quantity"]
        if delta > 0:
            if inventory_dal.deduct(conn, item["sku_id"], order["store_id"], delta) == 0:
                raise rule_violated("库存不足，无法增加数量")
        elif delta < 0:
            inventory_dal.restore(conn, item["sku_id"], order["store_id"], -delta)
    subtotal = (item["unit_price"] * new_quantity).quantize(Decimal("0.01"))
    orders_dal.update_item(conn, item["order_item_id"], new_quantity, subtotal)


def create_order(user, payload):
    if user["role"] != "customer":
        raise forbidden("只有顾客可以下单")

    store_id = require_int(payload.get("store_id"), "门店", 1)
    raw_items = payload.get("items") or []
    if not isinstance(raw_items, list) or not raw_items:
        raise bad_request("请至少选择一件商品")
    if len(raw_items) > 20:
        raise bad_request("一次最多 20 个明细")

    merged = {}
    for entry in raw_items:
        if not isinstance(entry, dict):
            raise bad_request("明细格式不正确")
        sku_id = require_int(entry.get("sku_id"), "商品规格", 1)
        quantity = require_int(entry.get("quantity"), "数量", 1, 99)
        merged[sku_id] = merged.get(sku_id, 0) + quantity
    if any(quantity > 99 for quantity in merged.values()):
        raise bad_request("同一规格数量不能超过 99")

    pickup_time = optional_datetime(payload.get("pickup_time"), "取餐时间")
    remark = optional_text(payload.get("remark"), "备注", 200)

    with transaction() as conn:
        store = stores_dal.get_store(conn, store_id)
        if not store:
            raise not_found("门店不存在")
        if store["status"] != "营业":
            raise rule_violated("该门店暂停营业")

        sku_map = {sku["sku_id"]: sku for sku in products_dal.get_skus_for_order(conn, list(merged))}
        lines = []
        total = Decimal("0")
        for sku_id, quantity in merged.items():
            sku = sku_map.get(sku_id)
            if not sku:
                raise not_found("商品规格不存在")
            if sku["status"] != "上架" or sku["product_status"] != "上架":
                raise rule_violated("商品已下架")
            subtotal = (sku["price"] * quantity).quantize(Decimal("0.01"))
            total += subtotal
            lines.append(
                {
                    "sku_id": sku_id,
                    "product_name": sku["product_name"],
                    "sku_name": sku["sku_name"],
                    "unit_price": sku["price"],
                    "quantity": quantity,
                    "subtotal": subtotal,
                }
            )

        order_id = orders_dal.create_order(
            conn,
            {
                "order_no": _order_no(),
                "user_id": user["user_id"],
                "store_id": store_id,
                "pickup_time": pickup_time,
                "remark": remark,
                "total_amount": total,
                "status": "待支付",
            },
        )
        for line in lines:
            if inventory_dal.deduct(conn, line["sku_id"], store_id, line["quantity"]) == 0:
                raise rule_violated(f"库存不足：{line['product_name']} {line['sku_name']}")
            orders_dal.insert_item(conn, order_id, line)

    return get_order(user, order_id)


def add_item(user, order_id, payload):
    sku_id = require_int(payload.get("sku_id"), "商品规格", 1)
    quantity = require_int(payload.get("quantity"), "数量", 1, 99)

    with transaction() as conn:
        order = _owned_order(conn, user, order_id, unpaid_only=True)
        sku = _require_on_sale_sku(conn, sku_id)
        existing = orders_dal.find_item_by_sku(conn, order_id, sku_id)
        if existing:
            new_quantity = existing["quantity"] + quantity
            if new_quantity > 99:
                raise bad_request("同一规格数量不能超过 99")
            _change_quantity(conn, order, existing, new_quantity)
        else:
            if inventory_dal.deduct(conn, sku_id, order["store_id"], quantity) == 0:
                raise rule_violated("库存不足")
            orders_dal.insert_item(
                conn,
                order_id,
                {
                    "sku_id": sku_id,
                    "product_name": sku["product_name"],
                    "sku_name": sku["sku_name"],
                    "unit_price": sku["price"],
                    "quantity": quantity,
                    "subtotal": (sku["price"] * quantity).quantize(Decimal("0.01")),
                },
            )
        _refresh_total(conn, order_id)

    return get_order(user, order_id)


def update_item(user, order_id, item_id, payload):
    quantity = require_int(payload.get("quantity"), "数量", 1, 99)

    with transaction() as conn:
        order = _owned_order(conn, user, order_id, unpaid_only=True)
        item = orders_dal.get_item(conn, item_id)
        if not item or item["order_id"] != order_id:
            raise not_found("订单明细不存在")
        _change_quantity(conn, order, item, quantity)
        _refresh_total(conn, order_id)

    return get_order(user, order_id)


def delete_item(user, order_id, item_id):
    with transaction() as conn:
        order = _owned_order(conn, user, order_id, unpaid_only=True)
        item = orders_dal.get_item(conn, item_id)
        if not item or item["order_id"] != order_id:
            raise not_found("订单明细不存在")
        if item["sku_id"] is not None:
            inventory_dal.restore(conn, item["sku_id"], order["store_id"], item["quantity"])
        orders_dal.delete_item(conn, item_id)
        _refresh_total(conn, order_id)

    return get_order(user, order_id)


def pay(user, order_id):
    with transaction() as conn:
        order = _owned_order(conn, user, order_id)
        if order["status"] != "待支付":
            raise rule_violated("只有待支付订单可以支付")
        orders_dal.update_status(conn, order_id, "已支付", mark_paid=True)
    return get_order(user, order_id)


def cancel(user, order_id):
    with transaction() as conn:
        order = _owned_order(conn, user, order_id)
        if order["status"] != "待支付":
            raise rule_violated("只有待支付订单可以取消")
        for item in orders_dal.list_items(conn, order_id):
            if item["sku_id"] is not None:
                inventory_dal.restore(conn, item["sku_id"], order["store_id"], item["quantity"])
        orders_dal.update_status(conn, order_id, "已取消")
    return get_order(user, order_id)


def advance_status(user, order_id, payload):
    if user["role"] != "staff":
        raise forbidden("只有店员可以推进订单状态")

    with transaction() as conn:
        order = orders_dal.get_order(conn, order_id)
        if not order:
            raise not_found("订单不存在")
        expected = NEXT_STATUS.get(order["status"])
        if not expected:
            raise rule_violated("当前状态不能继续推进")
        target = payload.get("status")
        if target != expected:
            raise rule_violated(f"下一步只能是「{expected}」")
        orders_dal.update_status(conn, order_id, target, mark_completed=(target == "已完成"))

    return get_order(user, order_id)
