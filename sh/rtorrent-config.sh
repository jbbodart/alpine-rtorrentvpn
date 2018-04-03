#!/bin/sh

function echo_log {
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] $*"
}

# wait for rtorrent responding on the xmlrpc interface
until $(xmlrpc localhost:8080 network.bind_address > /dev/null 2>&1); do
	sleep 1
done

echo_log "[info] configuring rtorrent listen port..."
xmlrpc localhost:8080 network.port_random.set "I/0" "I/0"
xmlrpc localhost:8080 network.port_range.set "s/" "${RTORRENT_LISTEN_PORT}-${RTORRENT_LISTEN_PORT}"

echo_log "[info] configuring rtorrent dht port..."
xmlrpc localhost:8080 dht.port.set "I/${RTORRENT_DHT_PORT}" "I/${RTORRENT_DHT_PORT}"

while true ; do
  # query rtorrent for current listening interface
  LISTEN_IP=$(xmlrpc localhost:8080 network.bind_address | tail -1 | awk '{print $NF}' | tr -d \')
  # get current VPN IP
  LOCAL_IP=$(ip -f inet -o addr show tun0 | cut -d\  -f 7 | cut -d/ -f 1)

  # if current listen interface ip is different than VPN tunnel ip then re-configure rtorrent
  if [[ "${LISTEN_IP}" != "${LOCAL_IP}" ]]; then
    echo_log "[info] VPN IP changed. Re-configuring rtorrent..."
    # set listen interface to tunnel local ip
    xmlrpc localhost:8080 network.bind_address.set "s/" "${LOCAL_IP}"
    if [ $? -eq 0 ]; then
      echo_log "[info] Successfully bound rtorrent to ${LOCAL_IP}"
    fi
  fi
	sleep 1m
done
