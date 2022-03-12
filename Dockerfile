FROM alpine:edge

RUN apk update && \
    apk add --no-cache ca-certificates caddy wget && \
    wget -O smartdns-linux.tar.gz https://github.com/pymumu/smartdns/releases/download/Release35/smartdns.1.2021.08.27-1923.x86_64-linux-all.tar.gz && \
    tar zxf smartdns-linux.tar.gz && \
    mv smartdns/usr/sbin/smartdns /usr/bin/ && \
    chmod 755 /usr/bin/smartdns && \
    rm -rf /var/cache/apk/* smartdns*

ADD start.sh /start.sh
RUN chmod +x /start.sh

CMD /start.sh
