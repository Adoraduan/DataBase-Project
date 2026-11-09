from ..dal import inventory as dal
from ..dal import products as products_dal
from ..dal import stores as stores_dal
from ..db import read_connection, transaction
from ..errors import not_found
from .validation import require_int


def _inventory_dict(row):
    return {
        "sku_id": row["sku_id"],
        "store_id": row["store_id"],
        "store_name": row["store_name"],
        "product_id": row["product_id"],
        "product_name": row["product_name"],
        "sku_name": row["sku_name"],
        "price": float(row["price"]),
        "quantity": row["quantity"],
    }


def list_inventory(store_id=None):
    store_id = require_int(store_id, "门店", 1) if store_id not in (None, "") else None
    with read_connection() as conn:
        rows = dal.list_inventory(conn, store_id)
    return [_inventory_dict(row) for row in rows]


def adjust(payload):
    sku_id = require_int(payload.get("sku_id"), "规格", 1)
    store_id = require_int(payload.get("store_id"), "门店", 1)
    quantity = require_int(payload.get("quantity"), "库存数量", 0, 9999)

    with transaction() as conn:
        if not products_dal.get_sku(conn, sku_id):
            raise not_found("规格不存在")
        if not stores_dal.get_store(conn, store_id):
            raise not_found("门店不存在")
        if dal.get_inventory(conn, sku_id, store_id) is None:
            dal.insert_row(conn, sku_id, store_id, quantity)
        else:
            dal.update_quantity(conn, sku_id, store_id, quantity)
    return {"sku_id": sku_id, "store_id": store_id, "quantity": quantity}
