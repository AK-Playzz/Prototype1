"""
app.py = Backend (Flask routes).
- Receives browser requests
- Validates
- Calls db.py
- Renders HTML templates
"""

from __future__ import annotations

import os
from flask import Flask, render_template, request, redirect, url_for, flash

import db
from validators import validate_customer, validate_invoice


app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key")

# Init DB at startup (works in local + Docker + cloud)
db.init_db()


@app.get("/")
def index():
    invoices = db.list_invoices()
    return render_template("index.html", invoices=invoices)


@app.get("/customers")
def customers_page():
    customers = db.list_customers()
    return render_template("customer_form.html", customers=customers)


@app.post("/customers")
def create_customer():
    full_name = request.form.get("full_name", "")
    email = request.form.get("email", "")
    phone = request.form.get("phone", "")

    v = validate_customer(full_name, email, phone)
    if not v.ok:
        flash(v.error, "error")
        return redirect(url_for("customers_page"))

    db.create_customer(full_name.strip(), email.strip(), phone.strip())
    flash("Customer created.", "success")
    return redirect(url_for("customers_page"))


@app.get("/invoices/new")
def invoice_new_form():
    customers = db.list_customers()
    if not customers:
        flash("Create a customer first.", "error")
        return redirect(url_for("customers_page"))
    return render_template("invoice_form.html", mode="create", customers=customers, invoice=None)


@app.post("/invoices")
def invoice_create():
    customer_id = request.form.get("customer_id", "")
    billing_address = request.form.get("billing_address", "")
    description = request.form.get("description", "")
    amount = request.form.get("amount", "")
    status = request.form.get("status", "draft")

    v = validate_invoice(customer_id, billing_address, description, amount, status)
    if not v.ok:
        flash(v.error, "error")
        return redirect(url_for("invoice_new_form"))

    db.create_invoice(int(customer_id), billing_address.strip(), description.strip(), float(amount), status)
    flash("Invoice created.", "success")
    return redirect(url_for("index"))


@app.get("/invoices/<int:invoice_id>")
def invoice_view(invoice_id: int):
    invoice = db.get_invoice(invoice_id)
    if not invoice:
        flash("Invoice not found.", "error")
        return redirect(url_for("index"))
    return render_template("invoice_view.html", invoice=invoice)


@app.get("/invoices/<int:invoice_id>/edit")
def invoice_edit_form(invoice_id: int):
    invoice = db.get_invoice(invoice_id)
    if not invoice:
        flash("Invoice not found.", "error")
        return redirect(url_for("index"))
    customers = db.list_customers()
    return render_template("invoice_form.html", mode="edit", customers=customers, invoice=invoice)


@app.post("/invoices/<int:invoice_id>/edit")
def invoice_update(invoice_id: int):
    customer_id = request.form.get("customer_id", "")
    billing_address = request.form.get("billing_address", "")
    description = request.form.get("description", "")
    amount = request.form.get("amount", "")
    status = request.form.get("status", "draft")

    v = validate_invoice(customer_id, billing_address, description, amount, status)
    if not v.ok:
        flash(v.error, "error")
        return redirect(url_for("invoice_edit_form", invoice_id=invoice_id))

    ok = db.update_invoice(invoice_id, int(customer_id), billing_address.strip(), description.strip(), float(amount), status)
    flash("Invoice updated." if ok else "Invoice not found.", "success" if ok else "error")
    return redirect(url_for("invoice_view", invoice_id=invoice_id))


@app.post("/invoices/<int:invoice_id>/delete")
def invoice_delete(invoice_id: int):
    ok = db.delete_invoice(invoice_id)
    flash("Invoice deleted." if ok else "Invoice not found.", "success" if ok else "error")
    return redirect(url_for("index"))


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=True)
