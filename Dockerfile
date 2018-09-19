FROM alpine:3.8

LABEL maintainer="jbbodart"

ENV UID=991
ENV GID=991
ENV RTORRENT_LISTEN_PORT=49314
ENV RTORRENT_DHT_PORT=49313
ENV DNS_SERVER_IP='9.9.9.9'

# Add flood configuration before build
COPY config/flood_config.js /tmp/config.js

RUN NB_CORES=${BUILD_CORES-$(getconf _NPROCESSORS_CONF)} \
  && addgroup -g ${GID} rtorrent \
  && adduser -h /home/rtorrent -s /bin/sh -G rtorrent -D -u ${UID} rtorrent \
  && build_pkgs="build-base git libtool automake autoconf tar xz binutils" \
  && runtime_pkgs="supervisor shadow su-exec nginx ca-certificates php7 php7-fpm php7-json openvpn rtorrent mediainfo mktorrent curl python2 nodejs nodejs-npm ffmpeg sox unzip unrar" \
  && apk -U upgrade \
  && apk add --no-cache --virtual=build-dependencies ${build_pkgs} \
  && apk add --no-cache ${runtime_pkgs} \

# Install ruTorrent
  && cd /var/www \
  && curl -LOk https://github.com/Novik/ruTorrent/archive/master.zip \
  && unzip master.zip \
  && rm -f master.zip \
  && mv ruTorrent-master rutorrent \
  && chmod -R 777 /var/www/rutorrent/share/ \
  && mkdir -p /var/www/rutorrent/tmp \
# Add some extra stuff
  && git clone https://github.com/QuickBox/club-QuickBox /var/www/rutorrent/plugins/theme/themes/club-QuickBox \
  && git clone https://github.com/Phlooo/ruTorrent-MaterialDesign /var/www/webapps/rutorrent/plugins/theme/themes/MaterialDesign \
  && cd /var/www/webapps/rutorrent/plugins/ \
  && git clone https://github.com/xombiemp/rutorrentMobile \
  && git clone https://github.com/dioltas/AddZip \

# Install flood
  && mkdir -p /usr/local/flood \
  && cd /usr/local/flood \
  && git clone https://github.com/jfurrow/flood . \
  && mv /tmp/config.js config.js \
  && npm install -g node-gyp \
  && npm install \
  # workaround for "Illegal instruction" when using argon2 on some CPUs
  && sed -i -e "s/\"-march=native\", //g" /usr/local/flood/node_modules/argon2/binding.gyp \
  && npm rebuild argon2 \
  && npm cache clean --force \
  && npm run build \

# Set-up permissions
  && chown -R rtorrent:rtorrent /var/www/rutorrent /home/rtorrent/ /var/tmp/nginx  \

# cleanup
  && apk del --purge build-dependencies \
  && rm -rf /var/cache/apk/* /tmp/* \
  && rm -rf /usr/local/include /usr/local/share

# Copy startup shells
COPY sh/* /usr/local/bin/

# Copy configuration files

# Set-up php-fpm
COPY config/php-fpm7_www.conf /etc/php7/php-fpm.d/www.conf
# Set-up nginx
COPY config/nginx.conf /etc/nginx/nginx.conf
# Configure supervisor
RUN sed -i -e "s/loglevel=info/loglevel=error/g" /etc/supervisord.conf
COPY config/rtorrentvpn_supervisord.conf /etc/supervisor.d/rtorrentvpn.ini

# Set-up rTorrent
COPY config/rtorrent.rc /home/rtorrent/rtorrent.rc
# Set-up ruTorrent
COPY config/rutorrent_config.php /var/www/rutorrent/conf/config.php
RUN chown rtorrent:rtorrent /home/rtorrent/rtorrent.rc /var/www/rutorrent/conf/config.php
# COPY config/rutorrent_plugins.ini /var/www/rutorrent/conf/plugins.ini
# COPY config/rutorrent_autotools.dat /var/www/rutorrent/share/settings/autotools.dat
# RUN sed -i -e "s/\$autowatch_interval =.*/\$autowatch_interval = 10;/g" /var/www/rutorrent/plugins/autotools/conf.php

VOLUME /data /config

# WebUI
EXPOSE 8080

CMD ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
