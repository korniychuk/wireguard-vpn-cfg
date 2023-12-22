# WireGuard VPN for VPS

A simple Docker Compose config and scripts to create a personal VPN on any VPS

### Usage
```sh
git clone https://github.com/korniychuk/wireguard-vpn-cfg.git wireguard-vpn
cd wireguard-vpn

docker-compose up # check that it doesn't have errors and press Ctrl+C to exit
docker-compose up -d

./init.sh
./add-client.sh
```

### If you want to clone by SSH
```sh
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
```

Add to [Deploy keys](./settings/keys/new) of **this repo**, **without** write access.

```sh
git clone git@github.com:korniychuk/wireguard-vpn-cfg.git wireguard-vpn
```

