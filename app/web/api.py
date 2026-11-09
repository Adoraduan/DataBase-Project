from flask import jsonify, request, session

from ..auth import login_required, role_required
from ..services import catalog, inventory, orders, products
from . import bp_api


def ok(data=None):
    return jsonify({"code": 0, "message": "ok", "data": data})


@bp_api.post("/api/auth/login")
def login():
    from ..services import auth as auth_service

    payload = request.get_json(silent=True) or {}
    user = auth_service.login(payload.get("username"), payload.get("password"))
    session.clear()
    session["user"] = user
    return ok(user)


@bp_api.post("/api/auth/logout")
def logout():
    session.clear()
    return ok()


@bp_api.get("/api/auth/me")
@login_required
def me():
    return ok(session["user"])


@bp_api.get("/api/categories")
@login_required
def categories():
    return ok(catalog.categories())


@bp_api.get("/api/stores")
@login_required
def stores():
    return ok(catalog.stores())


@bp_api.get("/api/skus")
@login_required
def store_skus():
    return ok(catalog.store_skus(request.args.get("store_id")))


@bp_api.get("/api/products")
@login_required
def list_products():
    return ok(products.list_products(request.args.get("keyword"), request.args.get("status")))


@bp_api.get("/api/products/<int:product_id>")
@login_required
def get_product(product_id):
    return ok(products.get_product(product_id))


@bp_api.post("/api/products")
@role_required("manager")
def create_product():
    return ok(products.create_product(request.get_json(silent=True) or {}))


@bp_api.put("/api/products/<int:product_id>")
@role_required("manager")
def update_product(product_id):
    return ok(products.update_product(product_id, request.get_json(silent=True) or {}))


@bp_api.delete("/api/products/<int:product_id>")
@role_required("manager")
def delete_product(product_id):
    products.delete_product(product_id)
    return ok()


@bp_api.post("/api/products/<int:product_id>/skus")
@role_required("manager")
def create_sku(product_id):
    return ok(products.create_sku(product_id, request.get_json(silent=True) or {}))


@bp_api.put("/api/skus/<int:sku_id>")
@role_required("manager")
def update_sku(sku_id):
    return ok(products.update_sku(sku_id, request.get_json(silent=True) or {}))


@bp_api.get("/api/inventory")
@role_required("staff", "manager")
def list_inventory():
    return ok(inventory.list_inventory(request.args.get("store_id")))


@bp_api.put("/api/inventory")
@role_required("staff", "manager")
def adjust_inventory():
    return ok(inventory.adjust(request.get_json(silent=True) or {}))


@bp_api.get("/api/orders")
@login_required
def list_orders():
    return ok(orders.list_orders(session["user"]))


@bp_api.get("/api/orders/<int:order_id>")
@login_required
def get_order(order_id):
    return ok(orders.get_order(session["user"], order_id))


@bp_api.post("/api/orders")
@role_required("customer")
def create_order():
    return ok(orders.create_order(session["user"], request.get_json(silent=True) or {}))


@bp_api.post("/api/orders/<int:order_id>/items")
@role_required("customer")
def add_item(order_id):
    return ok(orders.add_item(session["user"], order_id, request.get_json(silent=True) or {}))


@bp_api.put("/api/orders/<int:order_id>/items/<int:item_id>")
@role_required("customer")
def update_item(order_id, item_id):
    return ok(orders.update_item(session["user"], order_id, item_id, request.get_json(silent=True) or {}))


@bp_api.delete("/api/orders/<int:order_id>/items/<int:item_id>")
@role_required("customer")
def delete_item(order_id, item_id):
    return ok(orders.delete_item(session["user"], order_id, item_id))


@bp_api.post("/api/orders/<int:order_id>/pay")
@role_required("customer")
def pay(order_id):
    return ok(orders.pay(session["user"], order_id))


@bp_api.post("/api/orders/<int:order_id>/cancel")
@role_required("customer")
def cancel(order_id):
    return ok(orders.cancel(session["user"], order_id))


@bp_api.post("/api/orders/<int:order_id>/status")
@role_required("staff")
def advance_status(order_id):
    return ok(orders.advance_status(session["user"], order_id, request.get_json(silent=True) or {}))
