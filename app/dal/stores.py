def list_stores(conn):
    cur = conn.cursor()
    cur.execute(
        "SELECT store_id, store_name, address, phone, status FROM dbo.stores ORDER BY store_id"
    )
    return [
        {
            "store_id": row[0],
            "store_name": row[1],
            "address": row[2],
            "phone": row[3],
            "status": row[4],
        }
        for row in cur.fetchall()
    ]


def get_store(conn, store_id):
    cur = conn.cursor()
    cur.execute(
        "SELECT store_id, store_name, address, phone, status FROM dbo.stores WHERE store_id = ?",
        store_id,
    )
    row = cur.fetchone()
    if not row:
        return None
    return {
        "store_id": row[0],
        "store_name": row[1],
        "address": row[2],
        "phone": row[3],
        "status": row[4],
    }
