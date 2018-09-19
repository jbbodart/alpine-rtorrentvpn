FROM alpine:3.8

LABEL maintainer="jbbodart"

ENV UID=991
ENV GID=991
ENV RTORRENT_LISTEN_PORT=49314
ENV RTORRENT_DHT_PORT=49313
ENV DNS_SERVER_IP='9.9.9.9'

ARG MEDIAINFO_VER="18.08.1"

# Add flood configuration before build
COPY config/flood_config.js /tmp/config.js

RUN NB_CORES=${BUILD_CORES-$(getconf _NPROCESSORS_CONF)} \
  && addgroup -g ${GID} rtorrent \
  && adduser -h /home/rtorrent -s /bin/sh -G rtorrent -D -u ${UID} rtorrent \
  && build_pkgs="build-base git libtool automake autoconf tar xz binutils curl-dev cppunit-dev libressl-dev zlib-dev linux-headers ncurses-dev libxml2-dev" \
  && runtime_pkgs="supervisor shadow su-exec nginx ca-certificates php7 php7-fpm php7-json openvpn curl python2 nodejs nodejs-npm ffmpeg sox unzip unrar" \
  && apk -U upgrade \
  && apk add --no-cache --virtual=build-dependencies ${build_pkgs} \
  && apk add --no-cache ${runtime_pkgs} \

# compile mktorrent
  && cd /tmp \
  && git clone https://github.com/esmil/mktorrent \
  && cd /tmp/mktorrent \
  && make -j ${NB_CORES} \
  && make install \

# compile xmlrpc-c
  && cd /tmp \
  && curl -O https://netix.dl.sourceforge.net/project/xmlrpc-c/Xmlrpc-c%20Super%20Stable/1.39.13/xmlrpc-c-1.39.13.tgz \
  && tar zxvf xmlrpc-c-1.39.13.tgz \
  && cd xmlrpc-c-1.39.13 \
  && ./configure --enable-libxml2-backend --disable-cgi-server --disable-libwww-client --disable-wininet-client --disable-abyss-server \
  && make -j ${NB_CORES} \
  && make install \
  && make -C tools -j ${NB_CORES} \
  && make -C tools install \

# compile libtorrent
  && cd /tmp \
  && git clone https://github.com/rakshasa/libtorrent.git \
  && cd /tmp/libtorrent \
  && ./autogen.sh \
  && ./configure \
  && make -j ${NB_CORES} \
  && make install \

# compile rtorrent
  && cd /tmp \
  && git clone https://github.com/rakshasa/rtorrent.git \
  && cd /tmp/rtorrent \
  && ./autogen.sh \
  && ./configure --with-xmlrpc-c \
  && make -j ${NB_CORES} \
  && make install \

# compile mediainfo
  && cd /tmp \
  && curl -Lk -o /tmp/libmediainfo.tar.xz "https://mediaarea.net/download/binary/libmediainfo0/${MEDIAINFO_VER}/MediaInfo_DLL_${MEDIAINFO_VER}_GNU_FromSource.tar.xz" \
  && curl -Lk -o /tmp/mediainfo.tar.xz "https://mediaarea.net/download/binary/mediainfo/${MEDIAINFO_VER}/MediaInfo_CLI_${MEDIAINFO_VER}_GNU_FromSource.tar.xz" \
  && mkdir -p /tmp/libmediainfo /tmp/mediainfo \
  && tar Jxf /tmp/libmediainfo.tar.xz -C /tmp/libmediainfo --strip-components=1 \
  && tar Jxf /tmp/mediainfo.tar.xz -C /tmp/mediainfo --strip-components=1 \
  && cd /tmp/libmediainfo \
  && ./SO_Compile.sh \
  && cd /tmp/libmediainfo/ZenLib/Project/GNU/Library \
  && make install \
  && cd /tmp/libmediainfo/MediaInfoLib/Project/GNU/Library \
  && make install \
  && cd /tmp/mediainfo \
  && ./CLI_Compile.sh \
  && cd /tmp/mediainfo/MediaInfo/Project/GNU/CLI \
  && make install \

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
  && strip -s /usr/local/bin/mediainfo \
  && strip -s /usr/local/bin/mktorrent \
  && strip -s /usr/local/bin/rtorrent \
  && strip -s /usr/local/bin/xmlrpc \
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
