from cornell_tilde.db import (
    get_all_users,
    get_connection,
)
def update_bio(username: str, new_bio: str):
    with get_connection() as conn:
        conn.execute("""
            UPDATE users
            SET bio = ?
            WHERE username = ?
        """, (new_bio, username))
        conn.commit()

if __name__ == "__main__":
    update_bio("minh", "This is the bio for user minh.")