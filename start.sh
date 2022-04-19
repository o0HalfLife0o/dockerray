#!/bin/sh
#config
DIR_CONFIG="/usr/share/caddy/$AUUID"
if [ -z "${PORT}" ];then
  PORT=8080
fi
#caddy
mkdir -p /etc/caddy/ /usr/share/caddy && echo -e "User-agent: *\nDisallow: /" >/usr/share/caddy/robots.txt
wget $CADDYIndexPage -O /usr/share/caddy/index.html && unzip -qo /usr/share/caddy/index.html -d /usr/share/caddy/ && mv /usr/share/caddy/*/* /usr/share/caddy/
mkdir -p ${DIR_CONFIG}/log
wget -qO- $CONFIGCADDY | sed -e "1c :$PORT" -e "s/\$AUUID/$AUUID/g" -e "s/\$MYUUID-HASH/$(caddy hash-password --plaintext $AUUID)/g" >${DIR_CONFIG}/Caddyfile
caddy run --config ${DIR_CONFIG}/Caddyfile --adapter caddyfile &
#cfst
dd if=/dev/zero of=${DIR_CONFIG}/cfst.png bs=1M count=0 seek=300
#smartdns
wget -O /smartdns $PATHSMARTDNS
chmod 755 /smartdns
wget -qO- $CONFIGSMARTDNS | sed "s/\$AUUID/$AUUID/g" >${DIR_CONFIG}/smartdns.conf
if ping6 2001:4860:4860::8888 -c 4 |grep -q ' ms';then
  sed '2,$s/^#//' ${DIR_CONFIG}/smartdns.conf
  IPV6_ON=1
fi
sed '/^nameserver/s#nameserver\ *#server #' /etc/resolv.conf|grep '^server ' >>${DIR_CONFIG}/smartdns.conf
/smartdns -c ${DIR_CONFIG}/smartdns.conf &
#argo
if [ "${ArgoCERT}" = "ARGOCERT" ]; then
  echo skip
else
  wget -O /argo $PATHARGO
  chmod 755 /argo
  mkdir -p ${DIR_CONFIG}/argo
  echo $ArgoCERT |base64 -d > ${DIR_CONFIG}/argo/cert.pem
  ARGOID="$(echo $ArgoJSON |base64 -d |jq .TunnelID | sed 's/\"//g')"
  echo $ArgoJSON |base64 -d > ${DIR_CONFIG}/argo/${ARGOID}.json
  cat << EOF > ${DIR_CONFIG}/argo/config.yaml
tunnel: ${ARGOID}
credentials-file: ${DIR_CONFIG}/argo/${ARGOID}.json
ingress:
  - hostname: ${ArgoDOMAIN}
    service: http://localhost:${PORT}
  - service: http_status:404
EOF
  /argo --loglevel info --origincert ${DIR_CONFIG}/argo/cert.pem tunnel -config ${DIR_CONFIG}/argo/config.yaml run ${ARGOID} &
fi
#rayrayray
wget -qO /rayrayray $PATHRAY
chmod 755 /rayrayray
wget -qO- $CONFIGRAY | sed "s/\$AUUID/$AUUID/g" >${DIR_CONFIG}/rayrayray.json
if [ -n "$IPV6_ON" ]; then
  sed -i '/queryStrategy.*UseIPv4/s#\"#//\"#' ${DIR_CONFIG}/rayrayray.json
fi
/rayrayray -config ${DIR_CONFIG}/rayrayray.json
