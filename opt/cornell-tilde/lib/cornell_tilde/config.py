import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(".env")
BASE_DIR = Path(os.getenv("BASE_DIR", "/opt/cornell-tilde"))

BIN_DIR = BASE_DIR / "bin"
LIB_DIR = BASE_DIR / "lib"
VAR_DIR = BASE_DIR / "var"
TEMPLATE_DIR = BASE_DIR / "templates"

DATABASE_PATH = VAR_DIR / "cornell_tilde.sqlite3"

DIRECTORY_TEMPLATE = TEMPLATE_DIR / "directory.html"
USER_HOMEPAGE_TEMPLATE = TEMPLATE_DIR / "user_homepage.html"

WEB_ROOT = Path("/var/www/html")
DIRECTORY_OUTPUT = WEB_ROOT / "directory" / "index.html"

GENERATE_DIRECTORY = BIN_DIR / "generate_directory.py"

USER_HOME_BASE = Path("/home")
PUBLIC_HTML_NAME = "public_html"
