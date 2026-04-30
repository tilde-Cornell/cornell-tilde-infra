# the stuff and things of tilde@Cornell!!



- `/opt/cornell-tilde/bin` - admin tools, current join flow, snazzy maintenance script
- `/opt/cornell-tilde/lib/cornell_tilde` - shared python config and database helpers
- `/opt/cornell-tilde/templates` - HTML templated for directory page and user default page
- `/opt/cornell-tilde/var/cornell_tilde.sqlite3` the live database (not in repo lol)
- `/var/www/html` public static website files served by Apache

pls don't commit databases or user data

documentation:
- [`documentation/SETUP.md`](documentation/SETUP.md) - fresh server setup checklist
- [`documentation/SYSTEM_OVERVIEW.md`](documentation/SYSTEM_OVERVIEW.md) - high-level architecture and runtime paths
- [`documentation/APPLICATION_AND_ACCOUNT_FLOW.md`](documentation/APPLICATION_AND_ACCOUNT_FLOW.md) - join, application, approval, and account creation flow
- [`documentation/DATABASE_AND_DIRECTORY.md`](documentation/DATABASE_AND_DIRECTORY.md) - database schema, db.py helpers, and generated directory behavior
- [`documentation/OPERATIONS.md`](documentation/OPERATIONS.md) - post-deploy, admin commands, permissions, and troubleshooting

local python/IDE setup:

```sh
./tools/setup-python-env.sh
```

Point your IDE at `.venv/bin/python`. The setup script adds `opt/cornell-tilde/lib` to that environment with a `.pth` file, so imports like `from cornell_tilde.config import SITE_DOMAIN` work without installing any pip packages. To pick a specific interpreter, run `PYTHON_BIN=/usr/bin/python3 ./tools/setup-python-env.sh`. For local runs, set `BASE_DIR` to the checkout's `opt/cornell-tilde` directory and `WEB_ROOT` to the checkout's `var/www/html` directory so config, templates, migrations, the SQLite database, and generated web files resolve inside the repo.

create prodgit alias
```bash
echo "alias prodgit='sudo git --git-dir=/root/cornell-tilde-prod.git --work-tree=/'" >> ~/.bashrc
source ~/.bashrc
```

pull changes from main branch with:
```bash
prodgit pull origin main
sudo post-deploy
```

pull changes from development branch with:
```bash
prodgit pull origin development
sudo post-deploy
```

check status of server to main with `prodgit status`
