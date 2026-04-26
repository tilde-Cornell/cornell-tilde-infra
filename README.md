# the stuff and things of tilde@Cornell!!



- `/opt/cornell-tilde/bin` - admin tools, current join flow, snazzy maintenance script
- `/opt/cornell-tilde/lib/cornell_tilde` - shared python config and database helpers
- `/opt/cornell-tilde/templates` - HTML templated for directory page and user default page
- `/opt/cornell-tilde/var/cornell_tilde.sqlite3` the live database (not in repo lol)
- `/var/www/html` public static website files served by Apache

pls don't commit databases or user data

read SETUP.md for information on how to set up

create prodgit alias
```bash
echo "alias prodgit='sudo git --git-dir=/root/cornell-tilde-prod.git --work-tree=/'" >> ~/.bashrc
source ~/.bashrc
```

pull changes from main branch with `prodgit pull origin main`

pull changes from development branch with `prodgit pull origin development`

check status of server to main with `prodgit status`
