#!/bin/sh

VPN_CONFIG=$(find /config/ -name "*.ovpn" -print)
exec /usr/sbin/openvpn --cd /config/ --config "${VPN_CONFIG}" --mute-replay-warnings --keepalive 10 60 --writepid /var/run/openvpn.pid
