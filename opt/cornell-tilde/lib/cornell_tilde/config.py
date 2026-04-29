import os
from pathlib import Path


def load_env_file(path: Path) -> None:
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()

        if not key:
            continue

        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]

        os.environ.setdefault(key, value)
<<<<<<< HEAD

=======
>>>>>>> 68f227d (cleaned up dotenv requirement mismatch, pulls env manually as there were conflict issues with python dotenv libs)

RAW_BASE_DIR = os.getenv("BASE_DIR", "/opt/cornell-tilde")
BASE_DIR = Path(RAW_BASE_DIR)
load_env_file(BASE_DIR / ".env")

BIN_DIR = BASE_DIR / "bin"
LIB_DIR = BASE_DIR / "lib"
VAR_DIR = BASE_DIR / "var"
TEMPLATE_DIR = BASE_DIR / "templates"
SITE_DOMAIN = os.getenv("SITE_DOMAIN", "cornelltilde.com")
SITE_URL = f"https://{SITE_DOMAIN}"
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin@cornelltilde.com")

DATABASE_PATH = VAR_DIR / "cornell_tilde.sqlite3"

DIRECTORY_TEMPLATE = TEMPLATE_DIR / "directory.html"
USER_HOMEPAGE_TEMPLATE = TEMPLATE_DIR / "user_homepage.html"

WEB_ROOT = Path(os.getenv("WEB_ROOT", "/var/www/html"))
DIRECTORY_OUTPUT = WEB_ROOT / "directory" / "index.html"

GENERATE_DIRECTORY = BIN_DIR / "generate_directory.py"

USER_HOME_BASE = Path("/home")
PUBLIC_HTML_NAME = "public_html"
