def list_inventory(conn, store_id=None):
    sql = (
        "SELECT i.sku_id, i.store_id, s.store_name, k.sku_name, k.price, p.product_id, "
        "p.product_name, i.quantity FROM dbo.inventory i "
        "JOIN dbo.skus k ON k.sku_id = i.sku_id "
        "JOIN dbo.products p ON p.product_id = k.product_id "
        "JOIN dbo.stores s ON s.store_id = i.store_id"
    )
    params = []
    if store_id is not None:
        sql += " WHERE i.store_id = ?"
        params.append(store_id)
    sql += " ORDER BY i.store_id, p.product_id, i.sku_id"

    cur = conn.cursor()
    if params:
        cur.execute(sql, params)
    else:
        cur.execute(sql)
    return [
        {
            "sku_id": row[0],
            "store_id": row[1],
            "store_name": row[2],
            "sku_name": row[3],
            "price": row[4],
            "product_id": row[5],
            "product_name": row[6],
            "quantity": row[7],
        }
        for row in cur.fetchall()
    ]


def get_inventory(conn, sku_id, store_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT quantity FROM dbo.inventory WHERE sku_id = ? AND store_id = ?",
        sku_id,
        store_id,
    )
    row = cur.fetchone()
    return row[0] if row else None


def update_quantity(conn, sku_id, store_id, quantity):
    cur = conn.cursor()
    cur.execute(
        "UPDATE dbo.inventory SET quantity = ? WHERE sku_id = ? AND store_id = ?",
        quantity,
        sku_id,
        store_id,
    )
    return cur.rowcount


def insert_row(conn, sku_id, store_id, quantity):
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO dbo.inventory (sku_id, store_id, quantity) VALUES (?, ?, ?)",
        sku_id,
        store_id,
        quantity,
    )
    return cur.rowcount


def deduct(conn, sku_id, store_id, quantity):
    cur = conn.cursor()
    cur.execute(
        "UPDATE dbo.inventory SET quantity = quantity - ? "
        "WHERE sku_id = ? AND store_id = ? AND quantity >= ?",
        quantity,
        sku_id,
        store_id,
        quantity,
    )
    return cur.rowcount


def restore(conn, sku_id, store_id, quantity):
    cur = conn.cursor()
    cur.execute(
        "UPDATE dbo.inventory SET quantity = quantity + ? WHERE sku_id = ? AND store_id = ?",
        quantity,
        sku_id,
        store_id,
    )
    return cur.rowcount
