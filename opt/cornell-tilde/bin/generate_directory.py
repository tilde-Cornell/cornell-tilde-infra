#!/usr/bin/env python3
import sys
import html

sys.path.insert(0, "/opt/cornell-tilde/lib")

from cornell_tilde.config import DIRECTORY_TEMPLATE, DIRECTORY_OUTPUT
from cornell_tilde.db import get_public_users

def main():
    users = get_public_users()

    cards = []
    for user in users:
        username = html.escape(user.get("username", ""))
        name = html.escape(user.get("name", ""))
        college = html.escape(user.get("college", ""))
        grad_year = html.escape(user.get("grad_year", ""))
        bio = html.escape(user.get("bio", "")) or "—"
        card = f"""
<div class="card">
  <h2>{username}</h2>
  <p><strong>Name:</strong> {name}</p>
  <p><strong>College:</strong> {college}</p>
  <p><strong>Graduation Year:</strong> {grad_year}</p>
  <p><strong>Website:</strong> <a href="/~{username}">cornelltilde.com/~{username}</a></p>
  <p><strong>Bio:</strong> {bio}</p>
</div>
"""
        cards.append(card)

    member_count = len(users)
    member_label = "member" if member_count == 1 else "members"

    template = DIRECTORY_TEMPLATE.read_text(encoding="utf-8")
    page = template.format(
        member_count=member_count,
        member_label=member_label,
        cards="".join(cards)
    )

    DIRECTORY_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    DIRECTORY_OUTPUT.write_text(page, encoding="utf-8")

if __name__ == "__main__":
    main()
