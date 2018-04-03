Alpine rtorrent + OpenVPN + ruTorrent/Flood docker container
============================================================

Alpine Linux : https://alpinelinux.org/

rtorrent : https://github.com/rakshasa/rtorrent

rutorrent : https://github.com/Novik/ruTorrent

flood : https://github.com/jfurrow/flood

#### Main features
- Based on Alpine Linux.
- rTorrent and libtorrent are compiled from source.
- OpenVPN to tunnel torrent traffic securely (with iptables).

#### Environment variables
- **UID** : user id (default : 991)
- **GID** : group id (defaut : 991)
- **RTORRENT_LISTEN_PORT** : port used by rtorrent for torrent trafic (via VPN, default : 49314)
- **RTORRENT_DHT_PORT** : port used by rtorrent for DHT (via VPN, default : 49313)
- **DNS_SERVER_IP** : DNS server to use through the VPN (default : 9.9.9.9)

#### Usage
```
docker run -d \
  --cap-add=NET_ADMIN \
  -p 8080:8080 \
  --name=<container name> \
  -v <path for data files>:/data \
  -v <path for config files>:/config \
  -e UID=<uid> \
  -e GID=<gid> \
  -e RTORRENT_LISTEN_PORT=<port no> \
  -e RTORRENT_DHT_PORT=<port no> \
  jbbodart/alpine-rtorrentvpn
```

Please replace all user variables in the above command defined by <> with the correct values.

Once started, place a .torrent file in the /data/watch directory.
Completed downloads are stored in /data/downloads.

#### Volumes
- **/data** : downloaded torrents, watch directory, session files...
- **/config** : OpenVPN (.ovpn) configuration file

#### Ports
- **8080** : HTTP access for ruTorrent/flood

#### WEB UI
- ruTorrent : `http://<host ip>:8080`
- flood : `http://<host ip>:8080/flood/`
