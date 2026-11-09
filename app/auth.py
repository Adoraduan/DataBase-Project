from functools import wraps

from flask import redirect, request, session, url_for

from .errors import forbidden, is_api_request, unauthorized

# 数据库里的业务角色 → 应用里的角色。系统管理员在本应用按店长视图处理。
APP_ROLE_BY_DB_ROLE = {
    "顾客": "customer",
    "店员": "staff",
    "店长": "manager",
    "系统管理员": "manager",
}
ROLE_PRIORITY = ("manager", "staff", "customer")


def current_user():
    return session.get("user")


def map_app_role(db_roles):
    mapped = {APP_ROLE_BY_DB_ROLE.get(name) for name in db_roles}
    for role in ROLE_PRIORITY:
        if role in mapped:
            return role
    return None


def login_required(view):
    @wraps(view)
    def wrapper(*args, **kwargs):
        if not current_user():
            if is_api_request():
                raise unauthorized()
            return redirect(url_for("pages.login", next=request.path))
        return view(*args, **kwargs)

    return wrapper


def role_required(*roles):
    def decorator(view):
        @wraps(view)
        def wrapper(*args, **kwargs):
            user = current_user()
            if not user:
                if is_api_request():
                    raise unauthorized()
                return redirect(url_for("pages.login", next=request.path))
            if user.get("role") not in roles:
                raise forbidden()
            return view(*args, **kwargs)

        return wrapper

    return decorator
