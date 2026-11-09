import logging
from pathlib import Path
from uuid import uuid4

from flask import Flask, g, request, session

from .config import Config
from .errors import register_error_handlers
from .web import bp_api, bp_pages

ROLE_LABELS = {"customer": "顾客", "staff": "店员", "manager": "店长"}


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    app.json.ensure_ascii = False

    _configure_logging(app)
    app.register_blueprint(bp_pages)
    app.register_blueprint(bp_api)
    register_error_handlers(app)

    app.jinja_env.globals["role_label"] = lambda role: ROLE_LABELS.get(role, role or "-")

    @app.before_request
    def _before_request():
        g.request_id = uuid4().hex[:12]

    @app.after_request
    def _after_request(response):
        response.headers["X-Request-ID"] = g.get("request_id", "")
        user = session.get("user") or {}
        app.logger.info(
            "request_id=%s method=%s path=%s status=%s role=%s account=%s",
            g.get("request_id"),
            request.method,
            request.path,
            response.status_code,
            user.get("role", "-"),
            user.get("username", "-"),
        )
        return response

    @app.context_processor
    def _inject_current_user():
        return {"current_user": session.get("user")}

    return app


def _configure_logging(app):
    log_path = Path(app.config["LOG_FILE"])
    log_path.parent.mkdir(parents=True, exist_ok=True)
    if any(getattr(handler, "baseFilename", None) == str(log_path) for handler in app.logger.handlers):
        return
    handler = logging.FileHandler(log_path, encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    app.logger.addHandler(handler)
    app.logger.setLevel(logging.INFO)
