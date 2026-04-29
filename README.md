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
