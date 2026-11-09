from flask import Blueprint

bp_pages = Blueprint("pages", __name__)
bp_api = Blueprint("api", __name__)

from . import api, pages  # noqa: E402,F401
