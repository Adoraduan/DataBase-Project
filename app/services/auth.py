from werkzeug.security import check_password_hash

from ..auth import map_app_role
from ..dal import users
from ..db import read_connection
from ..errors import bad_request, forbidden, unauthorized


def _password_matches(stored, password):
    # 样例库里可能是占位串，格式不对时按“密码错误”处理，不让它冒成 500
    try:
        return check_password_hash(stored or "", password)
    except Exception:
        return False


def login(username, password):
    username = (username or "").strip()
    password = password or ""
    if not username or not password:
        raise bad_request("请输入用户名和密码")

    with read_connection() as conn:
        user = users.get_by_username(conn, username)
        if not user or not _password_matches(user["password_hash"], password):
            raise unauthorized("用户名或密码错误")
        if user["status"] != "正常":
            raise forbidden("账号已停用，请联系管理员")
        db_roles = users.get_role_names(conn, user["user_id"])

    role = map_app_role(db_roles)
    if not role:
        raise forbidden("该账号尚未开通业务角色")
    return {
        "user_id": user["user_id"],
        "username": user["username"],
        "role": role,
        "db_roles": db_roles,
    }
