#!/usr/bin/env python3
import sys
import html
import math
import shutil

sys.path.insert(0, "/opt/cornell-tilde/lib")

from cornell_tilde.config import DIRECTORY_TEMPLATE, DIRECTORY_OUTPUT, SITE_DOMAIN, SITE_URL
from cornell_tilde.db import get_public_users

USERS_PER_PAGE = 10

def page_output_path(page_number: int):
    if page_number == 1:
        return DIRECTORY_OUTPUT

    return DIRECTORY_OUTPUT.parent / "page" / str(page_number) / "index.html"

def page_url(page_number: int) -> str:
    if page_number == 1:
        return "/directory/"

    return f"/directory/page/{page_number}/"

def render_cards(users):
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
  <p><strong>Website:</strong> <a href="/~{username}">{SITE_DOMAIN}/~{username}</a></p>
  <p><strong>Bio:</strong> {bio}</p>
</div>
"""
        cards.append(card)

    return "".join(cards)

def render_pagination(page_number: int, page_count: int) -> str:
    if page_count <= 1:
        return ""

    prev_link = (
        f'<a href="{page_url(page_number - 1)}">Previous</a>'
        if page_number > 1
        else '<span>Previous</span>'
    )
    next_link = (
        f'<a href="{page_url(page_number + 1)}">Next</a>'
        if page_number < page_count
        else '<span>Next</span>'
    )

    page_links = []

    for number in range(1, page_count + 1):
        if number == page_number:
            page_links.append(f'<strong>{number}</strong>')
        else:
            page_links.append(f'<a href="{page_url(number)}">{number}</a>')

    return f"""
<nav class="pagination" aria-label="Directory pages">
  {prev_link}
  <span class="pagination-pages">{" ".join(page_links)}</span>
  {next_link}
</nav>
"""

def main():
    users = get_public_users()
    member_count = len(users)
    member_label = "member" if member_count == 1 else "members"
    page_count = max(1, math.ceil(member_count / USERS_PER_PAGE))

    template = DIRECTORY_TEMPLATE.read_text(encoding="utf-8")

    old_page_dir = DIRECTORY_OUTPUT.parent / "page"
    if old_page_dir.exists():
        shutil.rmtree(old_page_dir)

    DIRECTORY_OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    for page_number in range(1, page_count + 1):
        start = (page_number - 1) * USERS_PER_PAGE
        end = start + USERS_PER_PAGE
        page_users = users[start:end]

        page = template.format(
            member_count=member_count,
            member_label=member_label,
            page_number=page_number,
            page_count=page_count,
            site_domain=SITE_DOMAIN,
            site_url=SITE_URL,
            cards=render_cards(page_users),
            pagination=render_pagination(page_number, page_count),
        )

        output_path = page_output_path(page_number)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(page, encoding="utf-8")

if __name__ == "__main__":
    main()
