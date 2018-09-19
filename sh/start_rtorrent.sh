#!/bin/sh

function echo_log {
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] $*"
}

echo_log "[info] starting rtorrent..."

# remove lock files
rm -f /data/session/rtorrent.lock
rm -f /tmp/rtorrent_scgi.socket

# run rtorrent
su-exec rtorrent /usr/bin/rtorrent -n -o import=/home/rtorrent/rtorrent.rc > /dev/null
