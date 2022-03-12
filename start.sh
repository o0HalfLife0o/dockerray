#!/bin/sh

# configs
mkdir -p /etc/caddy/ /usr/share/caddy && echo -e "User-agent: *\nDisallow: /" >/usr/share/caddy/robots.txt
wget $CADDYIndexPage -O /usr/share/caddy/index.html && unzip -qo /usr/share/caddy/index.html -d /usr/share/caddy/ && mv /usr/share/caddy/*/* /usr/share/caddy/
wget -qO- $CONFIGCADDY | sed -e "1c :$PORT" -e "s/\$AUUID/$AUUID/g" -e "s/\$MYUUID-HASH/$(caddy hash-password --plaintext $AUUID)/g" >/etc/caddy/Caddyfile
wget -qO /rayrayray $PATHRAY
wget -qO- $CONFIGRAY | sed "s/\$AUUID/$AUUID/g" >/rayrayray.json
wget -qO- $CONFIGSMARTDNS | sed "s/\$AUUID/$AUUID/g" >/smartdns.conf
sed '/^nameserver/s#nameserver\ *#server #' /etc/resolv.conf|grep '^server ' >>/smartdns.conf

# storefiles
mkdir -p /usr/share/caddy/$AUUID && wget -O /usr/share/caddy/$AUUID/StoreFiles $StoreFiles
wget -P /usr/share/caddy/$AUUID -i /usr/share/caddy/$AUUID/StoreFiles
# cfst
dd if=/dev/zero of=/usr/share/caddy/$AUUID/cfst.png bs=1M count=0 seek=300

mkdir -p /usr/share/caddy/$AUUID/log

# start
chmod 755 /rayrayray
/rayrayray -config /rayrayray.json &

smartdns -c /smartdns.conf &

caddy run --config /etc/caddy/Caddyfile --adapter caddyfile