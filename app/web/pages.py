from flask import redirect, render_template, session, url_for

from ..auth import login_required, role_required
from . import bp_pages


@bp_pages.get("/")
def index():
    return redirect(url_for("pages.dashboard"))


@bp_pages.get("/login")
def login():
    if session.get("user"):
        return redirect(url_for("pages.dashboard"))
    return render_template("login.html")


@bp_pages.get("/dashboard")
@login_required
def dashboard():
    return render_template("dashboard.html", user=session["user"])


@bp_pages.get("/products")
@login_required
def products():
    return render_template("products.html", user=session["user"])


@bp_pages.get("/products/<int:product_id>")
@login_required
def product_detail_page(product_id):
    return render_template("product_detail.html", user=session["user"], product_id=product_id)


@bp_pages.get("/inventory")
@role_required("staff", "manager")
def inventory():
    return render_template("inventory.html", user=session["user"])


@bp_pages.get("/orders")
@login_required
def orders():
    return render_template("orders.html", user=session["user"])


@bp_pages.get("/orders/new")
@role_required("customer")
def order_new():
    return render_template("order_new.html", user=session["user"])


@bp_pages.get("/orders/<int:order_id>")
@login_required
def order_detail_page(order_id):
    return render_template("order_detail.html", user=session["user"], order_id=order_id)
