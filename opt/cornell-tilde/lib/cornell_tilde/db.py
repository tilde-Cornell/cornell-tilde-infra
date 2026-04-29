import json
import sqlite3
from pathlib import Path
from typing import Any, Optional

from cornell_tilde.config import BASE_DIR, DATABASE_PATH

MIGRATIONS_DIR = BASE_DIR / "migrations"

DEFAULT_JSON = "{}"

def get_connection() -> sqlite3.Connection:
    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

def run_sql_file(conn: sqlite3.Connection, path: Path) -> None:
    conn.executescript(path.read_text(encoding="utf-8"))

def init_db() -> None:
    with get_connection() as conn:
        run_sql_file(conn, MIGRATIONS_DIR / "1_user-applications_initial-schema.sql")

        columns = {
            row["name"]
            for row in conn.execute("PRAGMA table_info(users)").fetchall()
        }

        if "graduation_year" in columns and "grad_year" not in columns:
            conn.execute("ALTER TABLE users RENAME COLUMN graduation_year TO grad_year")
            columns.remove("graduation_year")
            columns.add("grad_year")

        if "email" not in columns:
            conn.execute("ALTER TABLE users ADD COLUMN email TEXT")
            columns.add("email")

        if "permissions_json" not in columns:
            conn.execute("ALTER TABLE users ADD COLUMN permissions_json TEXT NOT NULL DEFAULT '{}'")
            columns.add("permissions_json")

        if "tilde_compute_json" not in columns:
            conn.execute("ALTER TABLE users ADD COLUMN tilde_compute_json TEXT NOT NULL DEFAULT '{}'")
            columns.add("tilde_compute_json")

        if "is_admin" not in columns:
            conn.execute("ALTER TABLE users ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0")
            columns.add("is_admin")

        conn.execute("""
UPDATE users
SET permissions_json = '{}'
WHERE permissions_json IS NULL OR permissions_json = ''
        """)

        conn.execute("""
UPDATE users
SET tilde_compute_json = '{}'
WHERE tilde_compute_json IS NULL OR tilde_compute_json = ''
        """)

        run_sql_file(conn, MIGRATIONS_DIR / "2_directory_modified_hooks.sql")
def _json_loads_or_empty(value: Optional[str]) -> dict[str, Any]:
    if not value:
        return {}

    try:
        loaded = json.loads(value)
    except json.JSONDecodeError:
        return {}

    if isinstance(loaded, dict):
        return loaded

    return {}

def _json_dumps(value: Optional[dict[str, Any]]) -> str:
    if value is None:
        return DEFAULT_JSON

    return json.dumps(value, sort_keys=True, separators=(",", ":"))

def _permissions_from_json(value: Optional[str]) -> dict[str, Any]:
    return _json_loads_or_empty(value)

def _permissions_to_json(permissions: Optional[dict[str, Any]]) -> str:
    return _json_dumps(permissions)

def _tilde_compute_from_json(value: Optional[str]) -> dict[str, Any]:
    return _json_loads_or_empty(value)

def _tilde_compute_to_json(tilde_compute: Optional[dict[str, Any]]) -> str:
    return _json_dumps(tilde_compute)

def _user_from_row(row: sqlite3.Row) -> dict[str, Any]:
    user = dict(row)
    user["permissions"] = _permissions_from_json(user.pop("permissions_json", DEFAULT_JSON))
    user["tilde_compute"] = _tilde_compute_from_json(user.pop("tilde_compute_json", DEFAULT_JSON))
    return user

def get_user(username: str) -> Optional[dict]:
    with get_connection() as conn:
        row = conn.execute("""
            SELECT
                username,
                name,
                email,
                college,
                grad_year,
                bio,
                public,
                is_admin,
                permissions_json,
                tilde_compute_json,
                created_at,
                updated_at
            FROM users
            WHERE username = ?
        """, (username,)).fetchone()

    if row is None:
        return None

    return _user_from_row(row)

def get_public_users() -> list[dict]:
    with get_connection() as conn:
        rows = conn.execute("""
            SELECT
                username,
                name,
                email,
                college,
                grad_year,
                bio,
                is_admin,
                permissions_json,
                tilde_compute_json
            FROM users
            WHERE public = 1
            ORDER BY username COLLATE NOCASE
        """).fetchall()

    return [_user_from_row(row) for row in rows]

def get_all_users() -> list[dict]:
    with get_connection() as conn:
        rows = conn.execute("""
            SELECT
                username,
                name,
                email,
                college,
                grad_year,
                bio,
                public,
                is_admin,
                permissions_json,
                tilde_compute_json,
                created_at,
                updated_at
            FROM users
            ORDER BY username COLLATE NOCASE
        """).fetchall()

    return [_user_from_row(row) for row in rows]

def get_admin_users() -> list[dict]:
    with get_connection() as conn:
        rows = conn.execute("""
            SELECT
                username,
                name,
                email,
                college,
                grad_year,
                bio,
                public,
                is_admin,
                permissions_json,
                tilde_compute_json,
                created_at,
                updated_at
            FROM users
            WHERE is_admin = 1
            ORDER BY username COLLATE NOCASE
        """).fetchall()

    return [_user_from_row(row) for row in rows]

def add_user_to_directory(
    username: str,
    name: str,
    email: Optional[str] = None,
    college: Optional[str] = None,
    grad_year: Optional[str] = None,
    bio: Optional[str] = None,
    public: bool = True,
    is_admin: bool = False,
    permissions: Optional[dict[str, Any]] = None,
    tilde_compute: Optional[dict[str, Any]] = None,
) -> None:
    permissions_json = _permissions_to_json(permissions)
    tilde_compute_json = _tilde_compute_to_json(tilde_compute)

    try:
        with get_connection() as conn:
            conn.execute("""
                INSERT INTO users (
                    username,
                    name,
                    email,
                    college,
                    grad_year,
                    bio,
                    public,
                    is_admin,
                    permissions_json,
                    tilde_compute_json
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                username,
                name,
                email,
                college,
                grad_year,
                bio or "",
                1 if public else 0,
                1 if is_admin else 0,
                permissions_json,
                tilde_compute_json,
            ))
    except sqlite3.IntegrityError as exc:
        if "users.username" in str(exc):
            raise ValueError(f"user already exists: {username}") from exc
        raise

def update_user_profile(
    username: str,
    name: Optional[str] = None,
    email: Optional[str] = None,
    college: Optional[str] = None,
    grad_year: Optional[str] = None,
    bio: Optional[str] = None,
    public: Optional[bool] = None,
    is_admin: Optional[bool] = None,
) -> None:
    fields = []
    values = []

    if name is not None:
        fields.append("name = ?")
        values.append(name)

    if email is not None:
        fields.append("email = ?")
        values.append(email)

    if college is not None:
        fields.append("college = ?")
        values.append(college)

    if grad_year is not None:
        fields.append("grad_year = ?")
        values.append(grad_year)

    if bio is not None:
        fields.append("bio = ?")
        values.append(bio)

    if public is not None:
        fields.append("public = ?")
        values.append(1 if public else 0)

    if is_admin is not None:
        fields.append("is_admin = ?")
        values.append(1 if is_admin else 0)

    if not fields:
        return

    fields.append("updated_at = CURRENT_TIMESTAMP")
    values.append(username)

    with get_connection() as conn:
        conn.execute(
            f"UPDATE users SET {', '.join(fields)} WHERE username = ?",
            values,
        )

def get_user_permissions(username: str) -> dict[str, Any]:
    user = get_user(username)

    if user is None:
        return {}

    return user.get("permissions", {})

def set_user_permissions(username: str, permissions: dict[str, Any]) -> None:
    with get_connection() as conn:
        conn.execute("""
            UPDATE users
            SET permissions_json = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE username = ?
        """, (_permissions_to_json(permissions), username))

def get_user_tilde_compute(username: str) -> dict[str, Any]:
    user = get_user(username)

    if user is None:
        return {}

    return user.get("tilde_compute", {})

def set_user_tilde_compute(username: str, tilde_compute: dict[str, Any]) -> None:
    with get_connection() as conn:
        conn.execute("""
            UPDATE users
            SET tilde_compute_json = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE username = ?
        """, (_tilde_compute_to_json(tilde_compute), username))

def set_user_public(username: str, public: bool) -> None:
    update_user_profile(username=username, public=public)

def get_user_admin(username: str) -> bool:
    user = get_user(username)

    if user is None:
        return False

    return bool(user.get("is_admin"))

def set_user_admin(username: str, is_admin: bool) -> None:
    update_user_profile(username=username, is_admin=is_admin)

def promote_user_to_admin(username: str) -> None:
    set_user_admin(username, True)

def demote_user_from_admin(username: str) -> None:
    set_user_admin(username, False)

def set_user_bio(username: str, new_bio: str):
    with get_connection() as conn:
        conn.execute("""
            UPDATE users
            SET bio = ?
            WHERE username = ?
        """, (new_bio, username))
        conn.commit()

def hide_user(username: str) -> None:
    set_user_public(username, False)

def show_user(username: str) -> None:
    set_user_public(username, True)

def delete_user(username: str) -> None:
    with get_connection() as conn:
        conn.execute("""
            DELETE FROM users
            WHERE username = ?
        """, (username,))

def get_pending_applications() -> list[dict]:
    with get_connection() as conn:
        rows = conn.execute("""
            SELECT
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
            FROM applications
            WHERE status = 'pending'
            ORDER BY submitted_at
        """).fetchall()

    return [dict(row) for row in rows]

def set_application_status(
    application_id: str,
    status: str,
    final_username: Optional[str] = None,
) -> None:
    if status not in {"pending", "approved", "rejected"}:
        raise ValueError(f"Invalid application status: {status}")

    with get_connection() as conn:
        conn.execute("""
            UPDATE applications
            SET status = ?,
                final_username = COALESCE(?, final_username),
                updated_at = CURRENT_TIMESTAMP
            WHERE application_id = ?
        """, (
            status,
            final_username,
            application_id,
        ))
