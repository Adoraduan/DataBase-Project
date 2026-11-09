def list_categories(conn):
    cur = conn.cursor()
    cur.execute("SELECT category_id, category_name FROM dbo.categories ORDER BY category_id")
    return [{"category_id": row[0], "category_name": row[1]} for row in cur.fetchall()]


def get_category(conn, category_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT category_id, category_name FROM dbo.categories WHERE category_id = ?",
        category_id,
    )
    row = cur.fetchone()
    if not row:
        return None
    return {"category_id": row[0], "category_name": row[1]}


def list_products(conn, keyword=None, status=None):
    sql = (
        "SELECT p.product_id, p.category_id, c.category_name, p.product_name, p.description, "
        "p.image_url, p.status FROM dbo.products p "
        "JOIN dbo.categories c ON c.category_id = p.category_id"
    )
    conditions, params = [], []
    if keyword:
        conditions.append("p.product_name LIKE ?")
        params.append(f"%{keyword}%")
    if status:
        conditions.append("p.status = ?")
        params.append(status)
    if conditions:
        sql += " WHERE " + " AND ".join(conditions)
    sql += " ORDER BY p.product_id"

    cur = conn.cursor()
    if params:
        cur.execute(sql, params)
    else:
        cur.execute(sql)
    return [
        {
            "product_id": row[0],
            "category_id": row[1],
            "category_name": row[2],
            "product_name": row[3],
            "description": row[4],
            "image_url": row[5],
            "status": row[6],
        }
        for row in cur.fetchall()
    ]


def get_product(conn, product_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT p.product_id, p.category_id, c.category_name, p.product_name, p.description, "
        "p.image_url, p.status FROM dbo.products p "
        "JOIN dbo.categories c ON c.category_id = p.category_id "
        "WHERE p.product_id = ?",
        product_id,
    )
    row = cur.fetchone()
    if not row:
        return None
    return {
        "product_id": row[0],
        "category_id": row[1],
        "category_name": row[2],
        "product_name": row[3],
        "description": row[4],
        "image_url": row[5],
        "status": row[6],
    }


def list_skus_for_products(conn, product_ids):
    if not product_ids:
        return {}
    placeholders = ", ".join("?" for _ in product_ids)
    cur = conn.cursor()
    cur.execute(
        f"SELECT sku_id, product_id, sku_name, price, status FROM dbo.skus "
        f"WHERE product_id IN ({placeholders}) ORDER BY sku_id",
        list(product_ids),
    )
    grouped = {}
    for row in cur.fetchall():
        grouped.setdefault(row[1], []).append(
            {
                "sku_id": row[0],
                "product_id": row[1],
                "sku_name": row[2],
                "price": row[3],
                "status": row[4],
            }
        )
    return grouped


def create_product(conn, data):
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO dbo.products (category_id, product_name, description, image_url, status) "
        "OUTPUT INSERTED.product_id VALUES (?, ?, ?, ?, ?)",
        data["category_id"],
        data["product_name"],
        data["description"],
        data["image_url"],
        data["status"],
    )
    return cur.fetchone()[0]


def update_product(conn, product_id, data):
    cur = conn.cursor()
    cur.execute(
        "UPDATE dbo.products SET category_id = ?, product_name = ?, description = ?, "
        "image_url = ?, status = ? WHERE product_id = ?",
        data["category_id"],
        data["product_name"],
        data["description"],
        data["image_url"],
        data["status"],
        product_id,
    )
    return cur.rowcount


def delete_product(conn, product_id):
    cur = conn.cursor()
    cur.execute("DELETE FROM dbo.products WHERE product_id = ?", product_id)
    return cur.rowcount


def create_sku(conn, product_id, data):
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO dbo.skus (product_id, sku_name, price, status) "
        "OUTPUT INSERTED.sku_id VALUES (?, ?, ?, ?)",
        product_id,
        data["sku_name"],
        data["price"],
        data["status"],
    )
    return cur.fetchone()[0]


def update_sku(conn, sku_id, data):
    cur = conn.cursor()
    cur.execute(
        "UPDATE dbo.skus SET sku_name = ?, price = ?, status = ? WHERE sku_id = ?",
        data["sku_name"],
        data["price"],
        data["status"],
        sku_id,
    )
    return cur.rowcount


def get_sku(conn, sku_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT k.sku_id, k.product_id, k.sku_name, k.price, k.status, p.product_name, p.status "
        "FROM dbo.skus k JOIN dbo.products p ON p.product_id = k.product_id "
        "WHERE k.sku_id = ?",
        sku_id,
    )
    row = cur.fetchone()
    if not row:
        return None
    return {
        "sku_id": row[0],
        "product_id": row[1],
        "sku_name": row[2],
        "price": row[3],
        "status": row[4],
        "product_name": row[5],
        "product_status": row[6],
    }


def get_skus_for_order(conn, sku_ids):
    if not sku_ids:
        return []
    placeholders = ", ".join("?" for _ in sku_ids)
    cur = conn.cursor()
    cur.execute(
        f"SELECT k.sku_id, k.sku_name, k.price, k.status, p.product_id, p.product_name, p.status "
        f"FROM dbo.skus k JOIN dbo.products p ON p.product_id = k.product_id "
        f"WHERE k.sku_id IN ({placeholders})",
        list(sku_ids),
    )
    return [
        {
            "sku_id": row[0],
            "sku_name": row[1],
            "price": row[2],
            "status": row[3],
            "product_id": row[4],
            "product_name": row[5],
            "product_status": row[6],
        }
        for row in cur.fetchall()
    ]


def list_store_skus(conn, store_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT k.sku_id, k.sku_name, k.price, k.status, p.product_id, p.product_name, p.status, "
        "ISNULL(i.quantity, 0) FROM dbo.skus k "
        "JOIN dbo.products p ON p.product_id = k.product_id "
        "LEFT JOIN dbo.inventory i ON i.sku_id = k.sku_id AND i.store_id = ? "
        "WHERE k.status = N'上架' AND p.status = N'上架' "
        "ORDER BY p.product_id, k.sku_id",
        store_id,
    )
    return [
        {
            "sku_id": row[0],
            "sku_name": row[1],
            "price": row[2],
            "status": row[3],
            "product_id": row[4],
            "product_name": row[5],
            "product_status": row[6],
            "stock": row[7],
        }
        for row in cur.fetchall()
    ]
