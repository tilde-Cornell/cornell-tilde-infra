#!/usr/bin/python3
import datetime as dt
import json
import re
import secrets
import sqlite3
import sys

from cornell_tilde.db import get_connection

MAX_PAYLOAD_BYTES = 16384

EMAIL_REGEX = re.compile(r"^[A-Za-z0-9]+@cornell\.edu$")
USERNAME_REGEX = re.compile(r"^[a-z][a-z0-9_-]{1,31}$")
YEAR_REGEX = re.compile(r"^\d{4}$")
SSH_KEY_PREFIXES = (
    "ssh-ed25519 ",
    "ssh-rsa ",
    "ecdsa-sha2-nistp256 ",
)

COLLEGES = {
    "Arts and Sciences (CAS)",
    "Engineering (COE)",
    "Agriculture and Life Sciences (CALS)",
    "Architecture, Art, and Planning (AAP)",
    "Human Ecology (CHE)",
    "Industrial and Labor Relations (ILR)",
    "Public Policy",
    "Business",
}

FIELD_LIMITS = {
    "email": 254,
    "name": 120,
    "preferred_username": 32,
    "college": 80,
    "graduation_year": 4,
    "additional_info": 4000,
    "ssh_key": 8192,
}

def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)

def clean_string(payload: dict, key: str) -> str:
    value = payload.get(key)

    if not isinstance(value, str):
        fail(f"invalid {key}")

    value = value.strip()

    if len(value) > FIELD_LIMITS[key]:
        fail(f"{key} is too long")

    return value

def validate_payload(payload: object) -> dict[str, str]:
    if not isinstance(payload, dict):
        fail("invalid application payload")

    email = clean_string(payload, "email").lower()
    name = clean_string(payload, "name")
    username = clean_string(payload, "preferred_username").lower()
    college = clean_string(payload, "college")
    graduation_year = clean_string(payload, "graduation_year")
    additional_info = clean_string(payload, "additional_info") or "none"
    ssh_key = clean_string(payload, "ssh_key")

    if not EMAIL_REGEX.fullmatch(email):
        fail("invalid email")

    if not name:
        fail("name is required")

    if not USERNAME_REGEX.fullmatch(username):
        fail("invalid username")

    if college not in COLLEGES:
        fail("invalid college")

    if not YEAR_REGEX.fullmatch(graduation_year):
        fail("invalid graduation year")

    if not ssh_key.startswith(SSH_KEY_PREFIXES):
        fail("invalid ssh public key")

    if "\n" in ssh_key or "\r" in ssh_key:
        fail("ssh public key must be one line")

    return {
        "email": email,
        "name": name,
        "preferred_username": username,
        "college": college,
        "graduation_year": graduation_year,
        "additional_info": additional_info,
        "ssh_key": ssh_key,
    }

def generate_application_id() -> str:
    year = dt.datetime.now(dt.timezone.utc).year % 100
    alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    suffix = "".join(secrets.choice(alphabet) for _ in range(6))
    return f"CT-{year}-{suffix}"

def insert_application(record: dict[str, str]) -> str:
    submitted_at = dt.datetime.now(dt.timezone.utc).isoformat()

    with get_connection() as conn:
        for _ in range(20):
            application_id = generate_application_id()

            try:
                conn.execute("""
                    INSERT INTO applications (
                        application_id,
                        submitted_at,
                        email,
                        name,
                        preferred_username,
                        final_username,
                        college,
                        graduation_year,
                        additional_info,
                        ssh_key,
                        status,
                        updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, 'pending', CURRENT_TIMESTAMP)
                """, (
                    application_id,
                    submitted_at,
                    record["email"],
                    record["name"],
                    record["preferred_username"],
                    record["college"],
                    record["graduation_year"],
                    record["additional_info"],
                    record["ssh_key"],
                ))
                return application_id
            except sqlite3.IntegrityError:
                continue

    fail("could not create a unique application id")

def main() -> int:
    raw = sys.stdin.buffer.read(MAX_PAYLOAD_BYTES + 1)

    if len(raw) > MAX_PAYLOAD_BYTES:
        fail("application payload is too large")

    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        fail("invalid application payload")

    record = validate_payload(payload)
    application_id = insert_application(record)
    print(application_id)
    return 0

if __name__ == "__main__":
    sys.exit(main())
