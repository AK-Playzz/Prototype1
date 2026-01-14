"""
db.py = Database layer (SQLite).
All SQL lives here so app.py stays clean.
"""

from __future__ import annotations

import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Optional, Iterable


def get_db_path() -> str:
    """Where SQLite file is stored (env var lets Docker/cloud override)."""
    return os.environ.get("INVOICE_APP_DB", "invoice_app.sqlite3")


@contextmanager
def db_conn() -> Iterable[sqlite3.Connection]:
    """Open/close DB connection safely."""
    conn = sqlite3.connect(get_db_path())
    try:
        conn.row_factory = sqlite3.Row
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    """Create tables if missing."""
    with db_conn() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS customers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              full_name TEXT NOT NULL,
              email TEXT NOT NULL,
              phone TEXT NOT NULL
            );
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS invoices (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customer_id INTEGER NOT NULL,
              billing_address TEXT NOT NULL,
              description TEXT NOT NULL,
              amount REAL NOT NULL,
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY(customer_id) REFERENCES customers(id)
            );
            """
        )


# ---- Customers ----

def create_customer(full_name: str, email: str, phone: str) -> int:
    with db_conn() as conn:
        cur = conn.execute(
            "INSERT INTO customers(full_name,email,phone) VALUES (?,?,?);",
            (full_name, email, phone),
        )
        return int(cur.lastrowid)


def list_customers() -> list[sqlite3.Row]:
    with db_conn() as conn:
        return conn.execute(
            "SELECT id, full_name, email, phone FROM customers ORDER BY id DESC;"
        ).fetchall()


# ---- Invoices (CRUD) ----

def create_invoice(customer_id: int, billing_address: str, description: str, amount: float, status: str) -> int:
    now = datetime.utcnow().isoformat(timespec="seconds")
    with db_conn() as conn:
        cur = conn.execute(
            """
            INSERT INTO invoices(customer_id,billing_address,description,amount,status,created_at,updated_at)
            VALUES (?,?,?,?,?,?,?);
            """,
            (customer_id, billing_address, description, amount, status, now, now),
        )
        return int(cur.lastrowid)


def list_invoices() -> list[sqlite3.Row]:
    with db_conn() as conn:
        return conn.execute(
            """
            SELECT i.id, i.customer_id, c.full_name AS customer_name,
                   i.billing_address, i.description, i.amount, i.status,
                   i.created_at, i.updated_at
            FROM invoices i
            JOIN customers c ON c.id = i.customer_id
            ORDER BY i.id DESC;
            """
        ).fetchall()


def get_invoice(invoice_id: int) -> Optional[sqlite3.Row]:
    with db_conn() as conn:
        return conn.execute(
            """
            SELECT i.id, i.customer_id, c.full_name AS customer_name,
                   i.billing_address, i.description, i.amount, i.status,
                   i.created_at, i.updated_at
            FROM invoices i
            JOIN customers c ON c.id = i.customer_id
            WHERE i.id = ?;
            """,
            (invoice_id,),
        ).fetchone()


def update_invoice(
    invoice_id: int,
    customer_id: int,
    billing_address: str,
    description: str,
    amount: float,
    status: str,
) -> bool:
    now = datetime.utcnow().isoformat(timespec="seconds")
    with db_conn() as conn:
        cur = conn.execute(
            """
            UPDATE invoices
            SET customer_id=?, billing_address=?, description=?, amount=?, status=?, updated_at=?
            WHERE id=?;
            """,
            (customer_id, billing_address, description, amount, status, now, invoice_id),
        )
        return cur.rowcount > 0


def delete_invoice(invoice_id: int) -> bool:
    with db_conn() as conn:
        cur = conn.execute("DELETE FROM invoices WHERE id=?;", (invoice_id,))
        return cur.rowcount > 0
