#!/bin/sh

LOG () {
  echo "$(date -Iseconds) ${0##*/}: $*" >&2
}

network=10.200.200.0
prefix=28

case $HOSTNAME in
  vm1)
    myaddr=10.200.200.1
    peeraddr=10.200.200.2
    peername=vm2
    ;;
  vm2)
    myaddr=10.200.200.2
    peeraddr=10.200.200.1
    peername=vm1
    ;;
  *)
    LOG "Unknown hostname"
    exit 1
    ;;
esac

LOG "Installing packages"
apk add wireguard-tools tcpdump nftables iptables bash curl darkhttpd > /dev/null

# This service will be used to transfer the public key from one
# container to the other.
LOG "Starting pubkey discovery service"
darkhttpd /var/www/localhost/htdocs --daemon --port 8080 --log /var/log/darkhttpd/darkhttpd.log

LOG "Configuring wg0"
ip link add wg0 type wireguard
ip addr add "${myaddr}/${prefix}" dev wg0
ip link set wg0 up

cd /etc/wireguard/
wg genkey | tee pvt.key | wg pubkey > /var/www/localhost/htdocs/pub.key
wg set wg0 listen-port 2000 private-key pvt.key

if [ "${myaddr}" = 10.200.200.1 ]; then
  LOG "Configure NAT rules"
  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
  iptables -t nat -A PREROUTING -p tcp --dport 9735 -j DNAT --to-destination "${peeraddr}:9735"
else
  LOG "Starting target service on port 9735"
  mkdir -p /tmp/content
  echo "This is vm2" > /tmp/content/index.html
  darkhttpd /tmp/content --daemon --port 9735
fi

# get peer key
LOG "Waiting for peer public key"
while ! curl -o /etc/wireguard/peer.key -sf http://${peername}:8080/pub.key; do
  sleep 1
done

LOG "Configuring wireguard connection to peer"
peer_key=$(cat /etc/wireguard/peer.key)
wg set wg0 peer "${peer_key}" endpoint "${peername}:2000" allowed-ips "${network}/${prefix}"

LOG "Setup complete."
exec sleep inf
