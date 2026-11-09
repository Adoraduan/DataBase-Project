from ..dal import products as dal
from ..db import read_connection, transaction
from ..errors import bad_request, not_found
from .validation import optional_text, require_choice, require_decimal, require_int, require_text

PRODUCT_STATUS = ("上架", "下架")
SKU_STATUS = ("上架", "下架")


def _sku_dict(row):
    return {
        "sku_id": row["sku_id"],
        "product_id": row["product_id"],
        "sku_name": row["sku_name"],
        "price": float(row["price"]),
        "status": row["status"],
    }


def _product_dict(row):
    return {
        "product_id": row["product_id"],
        "category_id": row["category_id"],
        "category_name": row["category_name"],
        "product_name": row["product_name"],
        "description": row["description"],
        "image_url": row["image_url"],
        "status": row["status"],
    }


def _product_data(payload):
    return {
        "category_id": require_int(payload.get("category_id"), "分类", 1),
        "product_name": require_text(payload.get("product_name"), "商品名称", 100),
        "description": optional_text(payload.get("description"), "商品描述", 500),
        "image_url": optional_text(payload.get("image_url"), "图片地址", 255),
        "status": require_choice(payload.get("status") or "上架", "商品状态", PRODUCT_STATUS),
    }


def _sku_data(payload):
    return {
        "sku_name": require_text(payload.get("sku_name"), "规格名称", 50),
        "price": require_decimal(payload.get("price"), "规格价格", 0, 9999.99),
        "status": require_choice(payload.get("status") or "上架", "规格状态", SKU_STATUS),
    }


def list_products(keyword=None, status=None):
    with read_connection() as conn:
        rows = dal.list_products(conn, keyword, status)
        skus = dal.list_skus_for_products(conn, [row["product_id"] for row in rows])
    result = []
    for row in rows:
        product = _product_dict(row)
        product["skus"] = [_sku_dict(sku) for sku in skus.get(row["product_id"], [])]
        result.append(product)
    return result


def get_product(product_id):
    with read_connection() as conn:
        row = dal.get_product(conn, product_id)
        if not row:
            raise not_found("商品不存在")
        skus = dal.list_skus_for_products(conn, [product_id]).get(product_id, [])
    product = _product_dict(row)
    product["skus"] = [_sku_dict(sku) for sku in skus]
    return product


def create_product(payload):
    data = _product_data(payload)
    with transaction() as conn:
        if not dal.get_category(conn, data["category_id"]):
            raise bad_request("分类不存在")
        product_id = dal.create_product(conn, data)
    return get_product(product_id)


def update_product(product_id, payload):
    data = _product_data(payload)
    with transaction() as conn:
        if not dal.get_product(conn, product_id):
            raise not_found("商品不存在")
        if not dal.get_category(conn, data["category_id"]):
            raise bad_request("分类不存在")
        dal.update_product(conn, product_id, data)
    return get_product(product_id)


def delete_product(product_id):
    with transaction() as conn:
        if dal.delete_product(conn, product_id) == 0:
            raise not_found("商品不存在")
    return True


def create_sku(product_id, payload):
    data = _sku_data(payload)
    with transaction() as conn:
        if not dal.get_product(conn, product_id):
            raise not_found("商品不存在")
        dal.create_sku(conn, product_id, data)
    return get_product(product_id)


def update_sku(sku_id, payload):
    data = _sku_data(payload)
    with transaction() as conn:
        row = dal.get_sku(conn, sku_id)
        if not row:
            raise not_found("规格不存在")
        dal.update_sku(conn, sku_id, data)
        product_id = row["product_id"]
    return get_product(product_id)
