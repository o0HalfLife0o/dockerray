#!/bin/sh
#config
num=0
for user in `echo $AUUID |sed 's#;# #g'`; do
  num=$(( num+1 ))
  id="$(echo $user |cut -d, -f1)"
  if [ $num -eq 1 ]; then
    AUUID="$id"
  fi
  if echo $user |grep -q ','; then
    email="$(echo $user |cut -d, -f2)"
  else
    email="love@rayrayray.com"
  fi
  users="$users,\n\ \ \ \ \ \ \ \ \ \ {\"id\": \"$id\",\"email\": \"$email\"}"
done
users="$(echo $users |sed 's#^,\\n##')"
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
dd if=/dev/zero of=${DIR_CONFIG}/cfst.png bs=1M count=0 seek=200
#smartdns
wget -O /smartdns $PATHSMARTDNS
chmod 755 /smartdns
wget -qO- $CONFIGSMARTDNS | sed "s/\$AUUID/$AUUID/g" >${DIR_CONFIG}/smartdns.conf
if ping6 2001:4860:4860::8888 -c 4 |grep -q ' ms';then
  sed -i '2,$s/^#//' ${DIR_CONFIG}/smartdns.conf
  IPV6_ON=1
fi
sed '/^nameserver/s#nameserver\ *#server #' /etc/resolv.conf|grep '^server ' >>${DIR_CONFIG}/smartdns.conf
/smartdns -f -c ${DIR_CONFIG}/smartdns.conf -p /var/run/smartdns.pid &
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
RAY_DIR="${DIR_CONFIG}/ray"
mkdir -p ${RAY_DIR}
wget -qP ${RAY_DIR} $PATHRAY
chmod 755 ${RAY_DIR}/rayrayray
wget -qO- $CONFIGRAY | sed -e "/id.*AUUID/c $users" -e "s/\$AUUID/$AUUID/g" >${RAY_DIR}/rayrayray.json
GEODATA='https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat \
https://raw.githubusercontent.com/Loyalsoldier/geoip/release/cn.dat \
https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-asn.dat'
for i in $GEODATA; do
  wget -qP ${RAY_DIR} $i
done
if [ -n "$IPV6_ON" ]; then
  sed -i 's#UseIPv4#UseIP#' ${RAY_DIR}/rayrayray.json
fi
if [ -n "$OUTBOUNDS" ]; then
  OUTBOUNDS="$(echo "$OUTBOUNDS" |sed 's#^#\\    #')"
  sed -i "/\"freedom\"/a $OUTBOUNDS" ${RAY_DIR}/rayrayray.json
fi
if [ -n "$ROUTING" ]; then
  ROUTING="$(echo "$ROUTING" |sed 's#^#\\      #')"
  sed -i "/\"rules\"/a $ROUTING" ${RAY_DIR}/rayrayray.json
fi
${RAY_DIR}/rayrayray -config ${RAY_DIR}/rayrayray.json
