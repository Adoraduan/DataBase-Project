from contextlib import contextmanager

import pyodbc


def _connection_string():
    from flask import current_app

    cfg = current_app.config
    parts = [
        f"DRIVER={{{cfg['DB_DRIVER']}}}",
        f"SERVER={cfg['DB_SERVER']}",
        f"DATABASE={cfg['DB_NAME']}",
    ]
    if cfg["DB_USER"]:
        parts.append(f"UID={cfg['DB_USER']}")
        parts.append(f"PWD={cfg['DB_PASSWORD']}")
    else:
        parts.append("Trusted_Connection=yes")
    parts.append(f"Encrypt={cfg['DB_ENCRYPT']}")
    parts.append(f"TrustServerCertificate={cfg['DB_TRUST_SERVER_CERTIFICATE']}")
    parts.append(f"Connection Timeout={cfg['DB_TIMEOUT']}")
    return ";".join(parts)


def connect():
    """新建一条连接；提交与回滚由调用方决定。"""
    return pyodbc.connect(_connection_string(), autocommit=False)


@contextmanager
def read_connection():
    conn = connect()
    try:
        yield conn
    finally:
        conn.close()


@contextmanager
def transaction():
    """把一次业务操作包成一个事务：正常提交，异常回滚，最后关闭连接。"""
    conn = connect()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def rows_to_dicts(cursor):
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]
