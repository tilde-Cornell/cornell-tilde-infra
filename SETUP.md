cat > SETUP.md <<'EOF'
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
ssh-keygen -t ed25519 -C "cornell-tilde-server" -f ~/.ssh/id_ed25519_github
```

## Copy the public key
```bash
cat ~/.ssh/id_ed25519_github.pub
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
cat > ~/.ssh/config <<'EOF-SSH'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
EOF-SSH

chmod 600 ~/.ssh/config
```

## Test GitHub access! If it doesnt work, oh well
```bash
ssh -T git@github.com
```



## Clone the repo

for main branch:
```bash
cd ~

git clone git@github.com:tilde-Cornell/cornell-tilde-infra.git

cd cornell-tilde-infra
```
for development branch:
```bash
cd ~

git clone -b development git@github.com:tilde-Cornell/cornell-tilde-infra.git

cd cornell-tilde-infra
```

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

## Make script executable (was needed in testing)
```bash
chmod +x deploy/setup.sh
```

## Run installer

```bash
sudo ./deploy/setup.sh
```
it will ask:
```
Admin Username: (input your current sudo account's username)
Join Password: (input password you wish to publicly share)
Domain: (ie. cornelltilde.com or dev.cornelltilde.com)
```

