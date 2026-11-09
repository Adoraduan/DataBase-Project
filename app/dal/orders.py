_ORDER_SELECT = (
    "SELECT o.order_id, o.order_no, o.user_id, u.username, o.store_id, s.store_name, "
    "o.pickup_time, o.remark, o.total_amount, o.status, o.created_at, o.paid_at, o.completed_at, "
    "(SELECT COUNT(*) FROM dbo.order_items oi WHERE oi.order_id = o.order_id) AS item_count "
    "FROM dbo.orders o "
    "JOIN dbo.users u ON u.user_id = o.user_id "
    "JOIN dbo.stores s ON s.store_id = o.store_id"
)


def _order_row(row):
    return {
        "order_id": row[0],
        "order_no": row[1],
        "user_id": row[2],
        "username": row[3],
        "store_id": row[4],
        "store_name": row[5],
        "pickup_time": row[6],
        "remark": row[7],
        "total_amount": row[8],
        "status": row[9],
        "created_at": row[10],
        "paid_at": row[11],
        "completed_at": row[12],
        "item_count": row[13],
    }


def list_orders(conn, user_id=None, status=None):
    sql = _ORDER_SELECT
    conditions, params = [], []
    if user_id is not None:
        conditions.append("o.user_id = ?")
        params.append(user_id)
    if status:
        conditions.append("o.status = ?")
        params.append(status)
    if conditions:
        sql += " WHERE " + " AND ".join(conditions)
    sql += " ORDER BY o.order_id DESC"

    cur = conn.cursor()
    if params:
        cur.execute(sql, params)
    else:
        cur.execute(sql)
    return [_order_row(row) for row in cur.fetchall()]


def get_order(conn, order_id):
    cur = conn.cursor()
    cur.execute(_ORDER_SELECT + " WHERE o.order_id = ?", order_id)
    row = cur.fetchone()
    return _order_row(row) if row else None


def list_items(conn, order_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT order_item_id, order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal "
        "FROM dbo.order_items WHERE order_id = ? ORDER BY order_item_id",
        order_id,
    )
    return [
        {
            "order_item_id": row[0],
            "order_id": row[1],
            "sku_id": row[2],
            "product_name": row[3],
            "sku_name": row[4],
            "unit_price": row[5],
            "quantity": row[6],
            "subtotal": row[7],
        }
        for row in cur.fetchall()
    ]


def get_item(conn, item_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT order_item_id, order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal "
        "FROM dbo.order_items WHERE order_item_id = ?",
        item_id,
    )
    row = cur.fetchone()
    if not row:
        return None
    return {
        "order_item_id": row[0],
        "order_id": row[1],
        "sku_id": row[2],
        "product_name": row[3],
        "sku_name": row[4],
        "unit_price": row[5],
        "quantity": row[6],
        "subtotal": row[7],
    }


def find_item_by_sku(conn, order_id, sku_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT order_item_id, order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal "
        "FROM dbo.order_items WHERE order_id = ? AND sku_id = ?",
        order_id,
        sku_id,
    )
    row = cur.fetchone()
    if not row:
        return None
    return {
        "order_item_id": row[0],
        "order_id": row[1],
        "sku_id": row[2],
        "product_name": row[3],
        "sku_name": row[4],
        "unit_price": row[5],
        "quantity": row[6],
        "subtotal": row[7],
    }


def create_order(conn, data):
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO dbo.orders (order_no, user_id, store_id, pickup_time, remark, total_amount, status) "
        "OUTPUT INSERTED.order_id VALUES (?, ?, ?, ?, ?, ?, ?)",
        data["order_no"],
        data["user_id"],
        data["store_id"],
        data["pickup_time"],
        data["remark"],
        data["total_amount"],
        data["status"],
    )
    return cur.fetchone()[0]


def insert_item(conn, order_id, item):
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO dbo.order_items (order_id, sku_id, product_name, sku_name, unit_price, quantity, subtotal) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        order_id,
        item["sku_id"],
        item["product_name"],
        item["sku_name"],
        item["unit_price"],
        item["quantity"],
        item["subtotal"],
    )
    return cur.rowcount


def update_item(conn, item_id, quantity, subtotal):
    cur = conn.cursor()
    cur.execute(
        "UPDATE dbo.order_items SET quantity = ?, subtotal = ? WHERE order_item_id = ?",
        quantity,
        subtotal,
        item_id,
    )
    return cur.rowcount


def delete_item(conn, item_id):
    cur = conn.cursor()
    cur.execute("DELETE FROM dbo.order_items WHERE order_item_id = ?", item_id)
    return cur.rowcount


def update_total(conn, order_id, total):
    cur = conn.cursor()
    cur.execute("UPDATE dbo.orders SET total_amount = ? WHERE order_id = ?", total, order_id)
    return cur.rowcount


def sum_items(conn, order_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT ISNULL(SUM(subtotal), 0) FROM dbo.order_items WHERE order_id = ?",
        order_id,
    )
    return cur.fetchone()[0]


def update_status(conn, order_id, status, mark_paid=False, mark_completed=False):
    sets = ["status = ?"]
    params = [status]
    if mark_paid:
        sets.append("paid_at = GETDATE()")
    if mark_completed:
        sets.append("completed_at = GETDATE()")
    params.append(order_id)
    cur = conn.cursor()
    cur.execute(f"UPDATE dbo.orders SET {', '.join(sets)} WHERE order_id = ?", params)
    return cur.rowcount
