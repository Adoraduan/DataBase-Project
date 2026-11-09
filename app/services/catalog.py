from ..dal import products as products_dal
from ..dal import stores as stores_dal
from ..db import read_connection
from .validation import require_int


def categories():
    with read_connection() as conn:
        return products_dal.list_categories(conn)


def stores():
    with read_connection() as conn:
        return stores_dal.list_stores(conn)


def store_skus(store_id):
    store_id = require_int(store_id, "门店", 1)
    with read_connection() as conn:
        rows = products_dal.list_store_skus(conn, store_id)
    return [
        {
            "sku_id": row["sku_id"],
            "sku_name": row["sku_name"],
            "price": float(row["price"]),
            "status": row["status"],
            "product_id": row["product_id"],
            "product_name": row["product_name"],
            "stock": row["stock"],
        }
        for row in rows
    ]
