#!/usr/bin/env python3
import os
import pwd
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, "/opt/cornell-tilde/lib")

from cornell_tilde.config import (
    USER_HOMEPAGE_TEMPLATE,
)
from cornell_tilde.db import (
    add_user_to_directory,
    delete_user,
    get_all_users,
    get_pending_applications,
    set_application_status,
)

TEMPLATE_FILE = USER_HOMEPAGE_TEMPLATE

USERNAME_RE = re.compile(r"^[a-z][a-z0-9_]{1,31}$")

def run(cmd):
    subprocess.run(cmd, check=True)

def enter_screen():
    if sys.stdout.isatty():
        print("\033[?1049h", end="")
        print("\033[H\033[2J", end="")

def leave_screen():
    if sys.stdout.isatty():
        print("\033[?1049l", end="")

def clear_screen():
    if sys.stdout.isatty():
        print("\033[H\033[2J", end="")

def warn_active_user_duplicates(app):
    checks = {
        "email": app.get("email", "").strip().lower(),
        "username": app.get("preferred_username", "").strip().lower(),
    }

    duplicates = []

    try:
        users = get_all_users()
    except Exception:
        print("\nWarning: could not read user database for duplicate checks.")
        return

    for user in users:
        existing_username = str(user.get("username", "(unknown)")).strip().lower()
        existing_email = str(user.get("email", "")).strip().lower()

        if checks["email"] and checks["email"] == existing_email:
            duplicates.append((
                "email",
                existing_username,
                user.get("email", "")
            ))

        if checks["username"] and checks["username"] == existing_username:
            duplicates.append((
                "username",
                existing_username,
                user.get("username", "")
            ))

    if duplicates:
        print("\n" + "!" * 70)
        print("DUPLICATE WARNING AGAINST ACTIVE USERS")
        print("!" * 70)

        for field, username, value in duplicates:
            print(f"- {field} matches active user '{username}': {value}")

        print("!" * 70)

def user_exists(username):
    try:
        pwd.getpwnam(username)
        return True
    except KeyError:
        return False

def validate_username(username):
    return bool(USERNAME_RE.fullmatch(username))

def prompt(prompt_text):
    return input(prompt_text).strip()

def confirm(prompt_text):
    answer = input(prompt_text + " (yes/no): ").strip().lower()
    return answer in ("y", "yes")

def display_app(app):
    print("\n" + "=" * 70)
    print(f"Application ID: {app.get('application_id', 'missing')}")
    print(f"Submitted:      {app.get('submitted_at', 'missing')}")
    print("-" * 70)
    print(f"Name:           {app.get('name', '')}")
    print(f"Email:          {app.get('email', '')}")
    print(f"Username:       {app.get('preferred_username', '')}")
    print(f"College:        {app.get('college', '')}")
    print(f"Grad Year:      {app.get('graduation_year', '')}")
    print(f"Additional:     {app.get('additional_info', '')}")
    print("-" * 70)
    print("SSH Key:")
    print(app.get("ssh_key", ""))
    print("=" * 70)

def choose_username(requested):
    username = requested.strip().lower()

    while True:
        print(f"\nRequested username: {username}")

        if not validate_username(username):
            print("Problem: username is invalid.")
        elif user_exists(username):
            print("Problem: username already exists.")
        else:
            print("Username is available.")

        print("\nOptions:")
        print("  use     - use this username")
        print("  change  - enter a different username")
        print("  reject  - reject the application")
        print("  cancel  - cancel approval and return to review")

        action = prompt("Choose an option [use/change/reject/cancel]: ").lower()

        if action in ("use", "u"):
            if not validate_username(username):
                print("Cannot use this username because it is invalid.")
                continue
            if user_exists(username):
                print("Cannot use this username because it already exists.")
                continue

            if confirm(f"Confirm final username '{username}'?"):
                return username

        elif action in ("change", "c"):
            username = prompt("Enter the new username: ").strip().lower()

        elif action in ("reject", "r"):
            return None

        elif action in ("cancel", "x"):
            return "CANCEL"

        else:
            print("Please choose use, change, reject, or cancel.")

def create_user(app, username, ssh_key):
    home = Path(f"/home/{username}")
    ssh_dir = home / ".ssh"
    auth_keys = ssh_dir / "authorized_keys"
    public_html = home / "public_html"
    index_html = public_html / "index.html"

    run(["adduser", "--disabled-password", "--gecos", "", username])

    ssh_dir.mkdir(parents=True, exist_ok=True)
    auth_keys.write_text(ssh_key.strip() + "\n", encoding="utf-8")

    public_html.mkdir(parents=True, exist_ok=True)

    display_name = app.get("name", username)

    template = TEMPLATE_FILE.read_text(encoding="utf-8")
    homepage = template.format(
        username=username,
        display_name=display_name,
    )

    index_html.write_text(homepage, encoding="utf-8")

    run(["chown", "-R", f"{username}:{username}", str(home)])
    run(["chmod", "711", str(home)])
    run(["chmod", "700", str(ssh_dir)])
    run(["chmod", "600", str(auth_keys)])
    run(["chmod", "755", str(public_html)])
    run(["chmod", "644", str(index_html)])

def rollback_user_creation(username):
    try:
        delete_user(username)
    except Exception:
        pass

    if user_exists(username):
        run(["deluser", "--remove-home", username])

def update_directory(app, username):
    username = username.strip().lower()
    email = app.get("email", "").strip().lower()

    existing_users = get_all_users()

    for user in existing_users:
        existing_username = str(user.get("username", "")).strip().lower()
        existing_email = str(user.get("email", "")).strip().lower()

        if existing_username == username:
            raise ValueError(f"Directory already contains username: {username}")

        if email and existing_email == email:
            raise ValueError(f"Directory already contains email: {email}")

    add_user_to_directory(
        username=username,
        name=app.get("name", "") or username,
        email=email,
        college=app.get("college", ""),
        grad_year=app.get("graduation_year", ""),
        bio="",
        public=True,
        permissions={},
        tilde_compute={},
    )

def mark_handled(app, decision, final_username=None):
    set_application_status(
        application_id=app.get("application_id"),
        status=decision,
        final_username=final_username,
    )

def print_rejection(app):
    message = f"""Hi {app.get("name", "")},

Thanks for applying to tilde@Cornell.

We reviewed your application, but we are not able to approve it at this time.

If you think this was a mistake, you can reply with more context.

Application ID: {app.get("application_id", "")}"""

    print("\n" + "=" * 70)
    print("COPY/PASTE REJECTION MESSAGE:")
    print("=" * 70)
    print(message)
    print("=" * 70 + "\n")

def print_welcome(username, email):
    message = f"""You’ve been approved for tilde@Cornell.

You can log in with:

ssh {username}@cornelltilde.com

Your personal webpage is available at:

https://cornelltilde.com/~{username}

Your website files live in:

~/public_html

You can edit your homepage by changing:

~/public_html/index.html

Welcome to tilde@Cornell!"""
    print("\n" + "=" * 70)
    print(f"COPY/PASTE WELCOME MESSAGE (send to: {email})")
    print("Subject Line: Welcome to tilde@Cornell!")
    print("=" * 70)
    print(message)
    print("=" * 70 + "\n")

def main():
    if os.geteuid() != 0:
        print("Run this with sudo:")
        print("sudo approve_user.py")
        return 1

    enter_screen()

    try:
        while True:
            pending = get_pending_applications()

            if not pending:
                clear_screen()
                print("No pending applications.")
                input("\nPress Enter to quit.")
                return 0

            index = 0

            while pending:
                if index >= len(pending):
                    index = 0
                if index < 0:
                    index = len(pending) - 1

                app = pending[index]
                clear_screen()

                print("=" * 70)
                print(f"Application {index + 1} of {len(pending)}")
                print("=" * 70)

                display_app(app)
                warn_active_user_duplicates(app)

                print("\nOptions:")
                print("  approve  - approve this application")
                print("  reject   - reject this application")
                print("  next     - go to next application")
                print("  prev     - go to previous application")
                print("  refresh  - reload pending applications")
                print("  quit     - quit approval tool")

                action = prompt("\nChoose an option [a/r/n/p/f/q]: ").lower()

                if action in ("q", "quit"):
                    return 0

                if action in ("f", "refresh"):
                    break

                if action in ("n", "next"):
                    index += 1
                    continue

                if action in ("p", "prev", "previous"):
                    index -= 1
                    continue

                if action in ("r", "reject"):
                    if confirm("Reject this application?"):
                        mark_handled(app, "rejected")
                        clear_screen()
                        print("Application rejected and hidden from future review.")
                        print_rejection(app)
                        input("\nPress Enter to continue.")
                        pending.pop(index)
                    continue

                if action in ("a", "approve"):
                    username = choose_username(app.get("preferred_username", ""))

                    if username == "CANCEL":
                        input("\nApproval canceled. Press Enter to return to review.")
                        continue

                    if username is None:
                        if confirm("Reject this application instead?"):
                            mark_handled(app, "rejected")
                            clear_screen()
                            print("Application rejected and hidden from future review.")
                            print_rejection(app)
                            input("\nPress Enter to continue.")
                            pending.pop(index)
                        continue

                    clear_screen()
                    print("Final approval summary:")
                    print("=" * 70)
                    print(f"Name:     {app.get('name')}")
                    print(f"Email:    {app.get('email')}")
                    print(f"Username: {username}")
                    print(f"College:  {app.get('college')}")
                    print(f"Year:     {app.get('graduation_year')}")
                    print("=" * 70)

                    if not confirm("Create this user account now?"):
                        input("\nApproval canceled. Press Enter to return to review.")
                        continue

                    created_user = False
                    try:
                        create_user(app, username, app.get("ssh_key", ""))
                        created_user = True
                        update_directory(app, username)
                        mark_handled(app, "approved", username)
                    except subprocess.CalledProcessError as e:
                        if created_user:
                            try:
                                rollback_user_creation(username)
                            except subprocess.CalledProcessError:
                                pass
                        clear_screen()
                        print(f"Command failed: {e}")
                        print("Application was NOT marked handled.")
                        if created_user:
                            print("Partial user creation was rolled back.")
                        input("\nPress Enter to continue.")
                        continue
                    except Exception as e:
                        if created_user:
                            try:
                                rollback_user_creation(username)
                            except subprocess.CalledProcessError:
                                pass
                        clear_screen()
                        print(f"Error: {e}")
                        print("Application was NOT marked handled.")
                        if created_user:
                            print("Partial user creation was rolled back.")
                        input("\nPress Enter to continue.")
                        continue

                    clear_screen()
                    print("User approved successfully.")
                    print_welcome(username, app.get('email'))
                    input("\nPress Enter to continue.")

                    pending.pop(index)
                    continue

                input("Unknown option. Press Enter to continue.")

    finally:
        leave_screen()

if __name__ == "__main__":
    sys.exit(main())
