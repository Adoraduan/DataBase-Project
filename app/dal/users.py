def get_by_username(conn, username):
    cur = conn.cursor()
    cur.execute(
        "SELECT user_id, username, password_hash, status FROM dbo.users WHERE username = ?",
        username,
    )
    row = cur.fetchone()
    if not row:
        return None
    return {
        "user_id": row[0],
        "username": row[1],
        "password_hash": row[2],
        "status": row[3],
    }


def get_role_names(conn, user_id):
    cur = conn.cursor()
    cur.execute(
        """
        SELECT r.role_name
        FROM dbo.user_roles ur
        JOIN dbo.roles r ON r.role_id = ur.role_id
        WHERE ur.user_id = ?
        """,
        user_id,
    )
    return [row[0] for row in cur.fetchall()]
