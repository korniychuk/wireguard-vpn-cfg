# WireGuard VPN for VPS

A simple Docker Compose config and scripts to create a personal VPN on any VPS

### Install Docker & Docker Compose

- https://docs.docker.com/engine/install/ubuntu/
- https://docs.docker.com/compose/install/linux/

### Usage
```sh
git clone https://github.com/korniychuk/wireguard-vpn-cfg.git wireguard-vpn
cd wireguard-vpn

./init.sh

docker compose up # check that it doesn't have errors and press Ctrl+C to exit
docker compose up -d

./add-client.sh
```

### If you want to clone by SSH
```sh
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
```

Add to [Deploy keys](https://github.com/korniychuk/wireguard-vpn-cfg/settings/keys/new) of **this repo**, **without** write access.

```sh
git clone git@github.com:korniychuk/wireguard-vpn-cfg.git wireguard-vpn
```

### Generate custom SSH Keys
```sh
ssh-keygen -t ed25519 -C "some comment" -f ~/.ssh/xxxx_ed25519
```

### Fix Disconnect • Устранить разрыв соединений

- in `/etc/ssh/sshd_config`
```
ClientAliveInterval 120
ClientAliveCountMax 3
```

- Restart
    - `sudo systemctl restart sshd` _(Debian/Amazon Linux)_
    - `sudo systemctl restart ssh` _(Ubuntu)_

