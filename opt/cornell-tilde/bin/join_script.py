#!/usr/bin/env python3
import datetime as dt
import re
import secrets
import sys

sys.path.insert(0, "/opt/cornell-tilde/lib")

from cornell_tilde.config import ADMIN_EMAIL, SITE_DOMAIN, SITE_URL
from cornell_tilde.db import get_connection

EMAIL_REGEX = re.compile(r"^[A-Za-z0-9]+@cornell\.edu$")
USERNAME_REGEX = re.compile(r"^[a-z][a-z0-9_-]{1,31}$")
YEAR_REGEX = re.compile(r"^\d{4}$")

COLLEGES = [
    "Arts and Sciences (CAS)",
    "Engineering (COE)",
    "Agriculture and Life Sciences (CALS)",
    "Architecture, Art, and Planning (AAP)",
    "Human Ecology (CHE)",
    "Industrial and Labor Relations (ILR)",
    "Public Policy",
    "Business"
]

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

def pause(message="\nPress Enter to continue."):
    input(message)

def ask_email() -> str:
    while True:
        clear_screen()
        print("=" * 60)
        print("tilde@Cornell Application")
        print("=" * 60)
        print("Step 1: Cornell Email")
        print()
        print("Enter your Cornell email address.")
        print("Example: kl2339@cornell.edu")
        print()

        email = input("Cornell Email: ").strip().lower()

        if not EMAIL_REGEX.fullmatch(email):
            print("\nThat is not a valid @cornell.edu email address.")
            pause()
            continue

        confirm = input(f"\nIs this correct?\n{email}\n\n(yes/No): ").strip().lower()

        if confirm in ("y", "yes"):
            return email

        print("\nOkay, let's try again.")
        pause()

def ask_name() -> str:
    while True:
        clear_screen()
        print("=" * 60)
        print("tilde@Cornell Application")
        print("=" * 60)
        print("Step 2: Full Name")
        print()
        print("Enter your full name.")
        print()

        name = input("Full Name: ").strip()

        if not name:
            print("\nPlease enter your name.")
            pause()
            continue

        confirm = input(f"\nIs this correct?\n{name}\n\n(yes/No): ").strip().lower()

        if confirm in ("y", "yes"):
            return name

        print("\nOkay, let's try again.")
        pause()

def ask_username() -> str:
    while True:
        clear_screen()
        print("=" * 60)
        print("tilde@Cornell Application")
        print("=" * 60)
        print("Step 3: Requested Username")
        print()
        print("Choose the username you want on tilde@Cornell.")
        print("This will be used for SSH and your public page.")
        print()
        print("Example:")
        print(f"  ssh yourusername@{SITE_DOMAIN}")
        print(f"  {SITE_URL}/~yourusername")
        print()
        print("Rules: 2-32 characters, lowercase letters, numbers, or _")
        print("Must start with a lowercase letter.")
        print()

        username = input("Requested Username: ").strip().lower()

        if not USERNAME_REGEX.fullmatch(username):
            print("\nThat username is not valid.")
            pause()
            continue

        confirm = input(f"\nIs this correct?\n{username}\n\n(yes/No): ").strip().lower()

        if confirm in ("y", "yes"):
            return username

        print("\nOkay, let's try again.")
        pause()

def ask_college() -> str:
    while True:
        clear_screen()
        print("=" * 60)
        print("tilde@Cornell Application")
        print("=" * 60)
        print("Step 4: College / School")
        print()
        print("Choose your Cornell college or school.")
        print()

        for i, name in enumerate(COLLEGES, start=1):
            print(f"  {i}. {name}")

        print()
        choice = input(f"Choose a number (1-{len(COLLEGES)}): ").strip()

        if not choice.isdigit():
            print("\nPlease enter a number.")
            pause()
            continue

        index = int(choice)

        if not 1 <= index <= len(COLLEGES):
            print(f"\nPlease enter a number from 1 to {len(COLLEGES)}.")
            pause()
            continue

        college = COLLEGES[index - 1]

        confirm = input(f"\nIs this correct?\n{college}\n\n(yes/No): ").strip().lower()

        if confirm in ("y", "yes"):
            return college

        print("\nOkay, let's choose again.")
        pause()

def ask_grad_year() -> str:
    current_year = dt.datetime.now(dt.timezone.utc).year

    while True:
        clear_screen()
        print("=" * 60)
        print("tilde@Cornell Application")
        print("=" * 60)
        print("Step 5: Graduation Year")
        print()
        print("Enter your expected graduation year.")
        print("Example: 2030")
        print()

        grad_year = input("Graduation Year: ").strip()

        if not YEAR_REGEX.fullmatch(grad_year):
            print("\nPlease enter a valid 4-digit year.")
            pause()
            continue

        year_int = int(grad_year)

        if year_int < current_year or year_int > current_year + 10:
            print("\nPlease enter a realistic graduation year.")
            pause()
            continue

        confirm = input(f"\nIs this correct?\n{grad_year}\n\n(yes/No): ").strip().lower()

        if confirm in ("y", "yes"):
            return grad_year

        print("\nOkay, let's try again.")
        pause()

def ask_info() -> str:
    while True:
        clear_screen()
        print("=" * 60)
        print("tilde@Cornell Application")
        print("=" * 60)
        print("Step 6: Additional Information")
        print()
        print("Share anything else you want the admin to know.")
        print("You can leave this blank.")
        print()

        info = input("Additional Information: ").strip()

        if not info:
            confirm = input(
                "\nYou did not enter any additional information.\n"
                "Are you sure you want to leave this blank? (yes/No): "
            ).strip().lower()

            if confirm in ("y", "yes"):
                return "none"

            print("\nOkay, let's try again.")
            pause()
            continue

        confirm = input(
            f"\nIs this correct?\n\n{info}\n\n(yes/No): "
        ).strip().lower()

        if confirm in ("y", "yes"):
            return info

        print("\nOkay, let's try again.")
        pause()

def ask_ssh_key() -> str:
    while True:
        clear_screen()
        print("=" * 60)
        print("tilde@Cornell Application")
        print("=" * 60)
        print("Step 7: SSH Public Key")
        print()
        print("Paste your SSH public key, not your private key.")
        print("It usually starts with ssh-ed25519.")
        print()
        print("Example:")
        print("ssh-ed25519 AAAAC3... your_netid@cornell.edu")
        print()
        print("Need help?")
        print(f"{SITE_URL}/ssh/")
        print()

        key1 = input("SSH Public Key: ").strip()

        if not key1.startswith((
            "ssh-ed25519 ",
            "ssh-rsa ",
            "ecdsa-sha2-nistp256 "
        )):
            print("\nThat does not look like a valid SSH public key.")
            print("Make sure you did not paste your private key.")
            pause()
            continue

        clear_screen()
        print("=" * 60)
        print("tilde@Cornell Application")
        print("=" * 60)
        print("Confirm SSH Public Key")
        print()
        print("Please paste the same SSH public key again.")
        print()

        key2 = input("SSH Public Key Again: ").strip()

        if key1 != key2:
            print("\nThe two SSH keys did not match.")
            pause()
            continue

        return key1

def generate_application_id() -> str:
    year = dt.datetime.now(dt.timezone.utc).year % 100
    alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    suffix = ''.join(secrets.choice(alphabet) for _ in range(6))
    return f"CT-{year}-{suffix}"

def write_application(record: dict) -> None:
    with get_connection() as conn:
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
            record["application_id"],
            record["submitted_at"],
            record["email"],
            record["name"],
            record["preferred_username"],
            record["college"],
            record["graduation_year"],
            record["additional_info"],
            record["ssh_key"],
        ))

def show_intro():
    clear_screen()
    print("="*52)
    print(" "*17 + "Join tilde@Cornell"+ " "*17)
    print("=" * 52)
    print()
    print("This form is used to request access to tilde@Cornell.")
    print()
    print("For help, contact the admin at:")
    print(ADMIN_EMAIL)
    print()
    print("By using this service, you agree to follow:")
    print("- Cornell IT policies")
    print("- all applicable federal and state laws")
    print("- tilde@Cornell community rules and admin decisions")
    print()
    input("Press Enter to continue.")

def review_application(data: dict) -> bool:
    while True:
        clear_screen()
        print("Review Your Application")
        print("=" * 60)
        print(f"Application ID:         {data['application_id']}")
        print(f"Email:                  {data['email']}")
        print(f"Name:                   {data['name']}")
        print(f"Requested Username:     {data['preferred_username']}")
        print(f"College:                {data['college']}")
        print(f"Graduation Year:        {data['graduation_year']}")
        print(f"Additional Information: {data['additional_info']}")
        print()
        print("SSH Public Key:")
        print(data["ssh_key"])
        print("=" * 60)

        choice = input("\nSubmit this application? (yes/no): ").strip().lower()

        if choice in ("yes", "y"):
            return True

        if choice in ("no", "n"):
            return False

        print("\nPlease answer yes or no.")
        input("\nPress Enter to continue.")

def main() -> int:
    application_id = None

    try:
        enter_screen()
        show_intro()

        email = ask_email()
        name = ask_name()
        username = ask_username()
        college = ask_college()
        grad_year = ask_grad_year()
        add_info = ask_info()
        ssh_key = ask_ssh_key()

        application_id = generate_application_id()

        data = {
            "application_id": application_id,
            "submitted_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "email": email,
            "name": name,
            "preferred_username": username,
            "college": college,
            "graduation_year": grad_year,
            "additional_info": add_info,
            "ssh_key": ssh_key,
        }

        if not review_application(data):
            leave_screen()
            print("Application canceled. No request was submitted.")
            return 1

        write_application(data)

    except (EOFError, KeyboardInterrupt):
        leave_screen()
        print("Application canceled. No request was submitted.")
        return 1
    except Exception:
        leave_screen()
        print("There was an error submitting your application.")
        print(f"Please contact the site admin at {ADMIN_EMAIL}.")
        return 1
    finally:
        leave_screen()

    print()
    print("Application received successfully.")
    print(f"Application ID: {application_id}")
    print()
    print("Thanks! We will review your request and contact you by email.")
    print(f"For help, contact {ADMIN_EMAIL}.")
    print()
    return 0

if __name__ == "__main__":
    sys.exit(main())
