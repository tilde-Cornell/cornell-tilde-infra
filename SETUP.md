# tilde@Cornell Server Setup

Debian 13 server (static IP)

point DNS A record at server ip

TCP inbound allowed on ports:
- 22
- 80
- 443

ICMP inbound allowed on all ports

no outbound firewall restrictions

## Add initial administrator

```bash
adduser (username)
usermod -aG sudo (username)
  ```


## Copy root SSH key to admin

```bash
rsync --archive --chown=(username):(username) ~/.ssh /home/(Username)
```

## SSH back in as user:
first run:

`exit`

then run:

`ssh (username)@(server-ip)`

## Setup server SSH key
```bash
sudo mkdir -p /root/.ssh
sudo ssh-keygen -t ed25519 -C "cornell-tilde-prod-deploy" -f /root/.ssh/id_ed25519_github
```

## Copy the public key
```bash
sudo cat /root/.ssh/id_ed25519_github.pub
```

## Add key to GitHub repo
```
Repo
-> Settings
-> Deploy keys
-> Add deploy key``
```

`Allow write access: OFF`

## Set SSH to use the key
```bash
sudo tee /root/.ssh/config > /dev/null <<'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile /root/.ssh/id_ed25519_github
    IdentitiesOnly yes
EOF

sudo chmod 700 /root/.ssh
sudo chmod 600 /root/.ssh/config
```

## Test GitHub access! If it doesnt work, oh well
```bash
sudo ssh -T git@github.com
```

## Install Git
```bash
sudo apt update && sudo apt install git -y
```

## Setup Git root worktree
for prod:
```bash
sudo git --git-dir=/root/cornell-tilde-prod.git init --bare

sudo git --git-dir=/root/cornell-tilde-prod.git remote add origin \
  git@github.com:tilde-Cornell/cornell-tilde-infra.git

sudo git --git-dir=/root/cornell-tilde-prod.git --work-tree=/ fetch origin main

sudo git --git-dir=/root/cornell-tilde-prod.git --work-tree=/ checkout -f main

sudo git --git-dir=/root/cornell-tilde-prod.git --work-tree=/ config status.showUntrackedFiles no
```
for dev:
```bash
sudo git --git-dir=/root/cornell-tilde-prod.git init --bare

sudo git --git-dir=/root/cornell-tilde-prod.git remote add origin \
  git@github.com:tilde-Cornell/cornell-tilde-infra.git

sudo git --git-dir=/root/cornell-tilde-prod.git --work-tree=/ fetch origin development

sudo git --git-dir=/root/cornell-tilde-prod.git --work-tree=/ checkout -f development

sudo git --git-dir=/root/cornell-tilde-prod.git --work-tree=/ config status.showUntrackedFiles no
```

## Create `prodgit` alias
```bash
echo "alias prodgit='sudo git --git-dir=/root/cornell-tilde-prod.git --work-tree=/'" >> ~/.bashrc
source ~/.bashrc
```


## Run installer
```bash
sudo chmod +x /deploy/setup.sh
sudo /deploy/setup.sh
```

it will ask:
```
Join Password: (input password you wish to publicly share)
Domain: (ie. cornelltilde.com or dev.cornelltilde.com)
```

