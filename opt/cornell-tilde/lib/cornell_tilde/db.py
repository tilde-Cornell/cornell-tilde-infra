import json
import sqlite3
from typing import Any, Optional

from cornell_tilde.config import DATABASE_PATH

DEFAULT_JSON = "{}"

def get_connection() -> sqlite3.Connection:
    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

def init_db() -> None:
    with get_connection() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT,
                college TEXT,
                grad_year TEXT,
                bio TEXT,
                public INTEGER NOT NULL DEFAULT 1,
                permissions_json TEXT NOT NULL DEFAULT '{}',
                tilde_compute_json TEXT NOT NULL DEFAULT '{}',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """)

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

        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_users_public
            ON users(public)
        """)

        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_users_username_nocase
            ON users(username COLLATE NOCASE)
        """)

        conn.execute("""
CREATE TABLE IF NOT EXISTS applications (
application_id TEXT PRIMARY KEY,
submitted_at TEXT,
email TEXT,
name TEXT,
preferred_username TEXT,
final_username TEXT,
college TEXT,
graduation_year TEXT,
additional_info TEXT,
ssh_key TEXT,
status TEXT NOT NULL DEFAULT 'pending'
CHECK (status IN ('pending', 'approved', 'rejected')),
updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)
        """)

        conn.execute("""
CREATE INDEX IF NOT EXISTS idx_applications_status
ON applications(status)
        """)

        conn.execute("""
CREATE INDEX IF NOT EXISTS idx_applications_email
ON applications(email)
        """)

        conn.execute("""
CREATE INDEX IF NOT EXISTS idx_applications_preferred_username
ON applications(preferred_username)
        """)

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
                permissions_json,
                tilde_compute_json,
                created_at,
                updated_at
            FROM users
            WHERE username = ?
        """, (username,)).fetchone()

    if row is None:
        return None

    return dict(row)

def get_public_users() -> list[dict]:
    with get_connection() as conn:
        rows = conn.execute("""
            SELECT
                username,
                name,
                email,
                college,
                grad_year,
                bio
            FROM users
            WHERE public = 1
            ORDER BY username COLLATE NOCASE
        """).fetchall()

    return [dict(row) for row in rows]

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
                permissions_json,
                tilde_compute_json,
                created_at,
                updated_at
            FROM users
            ORDER BY username COLLATE NOCASE
        """).fetchall()

    return [dict(row) for row in rows]

def add_user_to_directory(
    username: str,
    name: str,
    email: Optional[str] = None,
    college: Optional[str] = None,
    grad_year: Optional[str] = None,
    bio: Optional[str] = None,
    public: bool = True,
    permissions: Optional[dict[str, Any]] = None,
    tilde_compute: Optional[dict[str, Any]] = None,
) -> None:
    permissions_json = _json_dumps(permissions)
    tilde_compute_json = _json_dumps(tilde_compute)

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
                permissions_json,
                tilde_compute_json
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(username) DO UPDATE SET
                name = excluded.name,
                email = excluded.email,
                college = excluded.college,
                grad_year = excluded.grad_year,
                bio = excluded.bio,
                public = excluded.public,
                permissions_json = COALESCE(users.permissions_json, '{}'),
                tilde_compute_json = COALESCE(users.tilde_compute_json, '{}'),
                updated_at = CURRENT_TIMESTAMP
        """, (
            username,
            name,
            email,
            college,
            grad_year,
            bio or "",
            1 if public else 0,
            permissions_json,
            tilde_compute_json,
        ))

def update_user_profile(
    username: str,
    name: Optional[str] = None,
    email: Optional[str] = None,
    college: Optional[str] = None,
    grad_year: Optional[str] = None,
    bio: Optional[str] = None,
    public: Optional[bool] = None,
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

    return _json_loads_or_empty(user.get("permissions_json"))

def set_user_permissions(username: str, permissions: dict[str, Any]) -> None:
    with get_connection() as conn:
        conn.execute("""
            UPDATE users
            SET permissions_json = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE username = ?
        """, (_json_dumps(permissions), username))

def get_user_tilde_compute(username: str) -> dict[str, Any]:
    user = get_user(username)

    if user is None:
        return {}

    return _json_loads_or_empty(user.get("tilde_compute_json"))

def set_user_tilde_compute(username: str, tilde_compute: dict[str, Any]) -> None:
    with get_connection() as conn:
        conn.execute("""
            UPDATE users
            SET tilde_compute_json = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE username = ?
        """, (_json_dumps(tilde_compute), username))

def set_user_public(username: str, public: bool) -> None:
    update_user_profile(username=username, public=public)

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

def update_application_status(
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