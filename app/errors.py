import pyodbc
from flask import current_app, g, jsonify, redirect, render_template, request, session, url_for


class ApiError(Exception):
    def __init__(self, code, message, http_status=400):
        super().__init__(message)
        self.code = code
        self.message = message
        self.http_status = http_status


def bad_request(message="请求参数不合法"):
    return ApiError(4001, message, 400)


def unauthorized(message="请先登录"):
    return ApiError(4010, message, 401)


def forbidden(message="没有执行该操作的权限"):
    return ApiError(4030, message, 403)


def not_found(message="资源不存在"):
    return ApiError(4040, message, 404)


def rule_violated(message="操作不满足业务规则"):
    return ApiError(4090, message, 409)


def conflict(message="数据与现有约束冲突，操作未完成"):
    return ApiError(4099, message, 409)


def db_unavailable(message="系统暂时无法连接数据库，请稍后再试"):
    return ApiError(5001, message, 503)


def internal(message="操作失败，请稍后再试"):
    return ApiError(5000, message, 500)


def is_api_request():
    return request.path.startswith("/api/")


def from_db_error(exc):
    """把 pyodbc 的底层错误换成统一错误码，原始信息只进日志。"""
    args = getattr(exc, "args", ())
    state = str(args[0]) if args else ""
    text = str(exc)
    if state.startswith("23") or any(code in text for code in ("2627", "2601", "547")):
        return conflict()
    if state.startswith("08"):
        return db_unavailable()
    return internal()


def error_body(error):
    return {"code": error.code, "message": error.message, "request_id": g.get("request_id")}


def _render(error):
    if is_api_request():
        return jsonify(error_body(error)), error.http_status
    if error.http_status == 401:
        return redirect(url_for("pages.login", next=request.path))
    return render_template("error.html", error=error, request_id=g.get("request_id")), error.http_status


def _log(error, exc=None):
    user = session.get("user") or {}
    line = (
        f"request_id={g.get('request_id', '-')} method={request.method} path={request.path} "
        f"role={user.get('role', '-')} account={user.get('username', '-')} "
        f"code={error.code} result=error message={error.message}"
    )
    if error.http_status >= 500:
        current_app.logger.error(line, exc_info=exc)
    else:
        current_app.logger.warning(line)


def register_error_handlers(app):
    @app.errorhandler(ApiError)
    def handle_api_error(error):
        _log(error)
        return _render(error)

    @app.errorhandler(404)
    def handle_404(_exc):
        error = not_found("页面或接口不存在")
        _log(error)
        return _render(error)

    @app.errorhandler(405)
    def handle_405(_exc):
        error = ApiError(4050, "请求方法不允许", 405)
        _log(error)
        return _render(error)

    @app.errorhandler(pyodbc.Error)
    def handle_db_error(exc):
        error = from_db_error(exc)
        _log(error, exc)
        return _render(error)

    @app.errorhandler(Exception)
    def handle_unexpected(exc):
        error = internal()
        _log(error, exc)
        return _render(error)
