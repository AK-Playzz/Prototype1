"""
validators.py = input checks before saving to DB.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional


EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


@dataclass(frozen=True)
class ValidationResult:
    ok: bool
    error: Optional[str] = None


def validate_customer(full_name: str, email: str, phone: str) -> ValidationResult:
    if len(full_name.strip()) < 2:
        return ValidationResult(False, "Name must be at least 2 characters.")
    if not EMAIL_RE.match(email.strip()):
        return ValidationResult(False, "Email looks invalid.")
    if len(phone.strip()) < 7:
        return ValidationResult(False, "Phone must be at least 7 characters.")
    return ValidationResult(True)


def validate_invoice(customer_id: str, billing_address: str, description: str, amount: str, status: str) -> ValidationResult:
    if not customer_id.isdigit():
        return ValidationResult(False, "Pick a customer.")
    if len(billing_address.strip()) < 5:
        return ValidationResult(False, "Billing address too short.")
    if len(description.strip()) < 3:
        return ValidationResult(False, "Description too short.")
    try:
        a = float(amount)
        if a < 0:
            return ValidationResult(False, "Amount cannot be negative.")
    except ValueError:
        return ValidationResult(False, "Amount must be a real number (e.g. 12.50).")

    if status not in {"draft", "sent", "paid", "cancelled"}:
        return ValidationResult(False, "Status must be draft/sent/paid/cancelled.")
    return ValidationResult(True)
