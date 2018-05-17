#!/bin/sh
set -e

function echo_log {
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] $*"
}

# set up variables
##################

if [[ -z "${RTORRENT_LISTEN_PORT}" ]]; then
    RTORRENT_LISTEN_PORT=49314
fi

if [[ -z "${RTORRENT_DHT_PORT}" ]]; then
    RTORRENT_DHT_PORT=49313
fi

if [[ "${UID}" -lt 100 -o "${GID}" -lt 100 ]]; then
  echo_log "[crit] Wrong UID/GID value. Must be >= 100."
  exit 1
fi

echo_log "[info] Sanity checks..."
# check kernel module
if [[ $(lsmod | awk -v module="tun" '$1==module {print $1}' | wc -l) -eq 0 ]] ; then
    echo_log "[warn] $i kernel module not loaded. Please insmod and restart container if tun support is not built in the kernel."
fi

echo_log "[info] setting up DNS server..."
echo "nameserver ${DNS_SERVER_IP}" > /etc/resolv.conf
chmod -w /etc/resolv.conf

# check VPN configuration
VPN_CONFIG=$(find /config/ -name "*.ovpn" -print)
if [[ -z "${VPN_CONFIG}" ]]; then
  echo_log "[crit] Missing OpenVPN configuration file in /config/vpn/ (no .ovpn file)"
  echo_log "[crit] Please create and restart container"
  exit 1
fi

# create the tunnel device
[ -d /dev/net ] || mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200

echo_log "[info] Configuring iptables..."

NET_IF=$(ip link | grep eth0 | cut -d":" -f2 | tr -d ' ')

# allow already established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# VPN tunnel adapter
iptables -A INPUT -i tun0 -p tcp --dport ${RTORRENT_LISTEN_PORT} -j ACCEPT
iptables -A INPUT -i tun0 -p udp --dport ${RTORRENT_DHT_PORT} -j ACCEPT
iptables -A OUTPUT -o tun0 -j ACCEPT

# Network adapter
# allow trafic to OpenVPN remote server
VPN_PROTOCOL=$(/usr/bin/awk '$1=="proto"{print $2}' "${VPN_CONFIG}")
OLDIFS=${IFS}; IFS=$'\n';
for server in $(/usr/bin/awk '$1=="remote"' "${VPN_CONFIG}") ; do
  VPN_SERVER=$(echo ${server} | cut -d" " -f2);
  VPN_PORT=$(echo ${server} | cut -d" " -f3);
  if expr "${VPN_SERVER}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
    VPN_IP="${VPN_SERVER}"
  else
    VPN_IP=$(getent ahostsv4 "${VPN_SERVER}" | grep STREAM | head -n 1 | cut -d" " -f 1)
  fi
  iptables -A INPUT -i ${NET_IF} -s ${VPN_IP} -p ${VPN_PROTOCOL} --sport ${VPN_PORT} -j ACCEPT
  iptables -A OUTPUT -o ${NET_IF} -d ${VPN_IP} -p ${VPN_PROTOCOL} --dport ${VPN_PORT} -j ACCEPT
done ;
IFS=${OLDIFS}

# allow nginx for rutorrent/flood
iptables -A INPUT -i ${NET_IF} -p tcp --dport 8080 -j ACCEPT
iptables -A OUTPUT -o ${NET_IF} -p tcp --sport 8080 -j ACCEPT

# Loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# set default policy (in the end so that we can use DNS before VPN is up)
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

echo_log "[info] Done. iptables rules :"
iptables -S

echo_log "[info] creating data directories..."
mkdir -p /data/session /data/complete /data/incomplete /data/watch /data/flood/db

# set up permissions
####################

echo_log "[info] setting up permissions..."
# change rtorrent UID/GID if configured value differs from current
CUR_UID=$(getent passwd rtorrent | cut -f3 -d: || true)
CUR_GID=$(getent group rtorrent | cut -f3 -d: || true)

if [[ "${GID}" != "${CUR_GID}" ]]; then
  # if a group with this gid already exists
  if [[ $(getent group ${GID}) ]] ; then
    CUR_GROUP=$(getent group ${GID} | cut -f1 -d:)
    groupmod -g 99 ${CUR_GROUP}
    find / -group ${GID} -exec chgrp ${CUR_GROUP} {} \;
  fi
  groupmod -g ${GID} rtorrent
fi

if [ "${UID}" != "${CUR_UID}" ]; then
  if [[ $(getent passwd ${UID}) ]] ; then
    CUR_USER=$(getent group ${UID} | cut -f1 -d:)
    usermod -u 99 ${CUR_USER}
    find / -group ${UID} -exec chown ${CUR_USER} {} \;
  fi
  usermod -u ${UID} rtorrent
fi

chown -R rtorrent:rtorrent /data /var/www/rutorrent /home/rtorrent/ /var/tmp/nginx

# start everything
##################

echo_log "[info] Starting openvpn..."
supervisorctl start openvpn

echo_log "[info] Starting nginx..."
supervisorctl start nginx

echo_log "[info] Starting php-fpm..."
supervisorctl start php-fpm

echo_log "[info] Starting rtorrent..."
supervisorctl start rtorrent

echo_log "[info] Configuring rtorrent..."
supervisorctl start rtorrent-config

echo_log "[info] Starting flood..."
supervisorctl start flood
