#!/bin/bash

mkdir /etc/apache2/ssl 2> /dev/null

# Change laradock.test to the URL to be used
if [ ${APACHE_HTTP2} = true ]; then
  if [ ! -f /etc/apache2/ssl/ssl_site.crt ]; then
    openssl genrsa -out "/etc/apache2/ssl/ssl_site.key" 2048
    openssl rand -out /root/.rnd -hex 256
    openssl req -new -key "/etc/apache2/ssl/ssl_site.key" -out "/etc/apache2/ssl/ssl_site.csr" -subj "/CN=${HOSTNAME}/O=Laradock/C=BR"
    openssl x509 -req -days 365 -extfile <(printf "subjectAltName=DNS:${HOSTNAME},DNS:${WEB_ALIAS_DOMAIN}") -in "/etc/apache2/ssl/ssl_site.csr" -signkey "/etc/apache2/ssl/ssl_site.key" -out "/etc/apache2/ssl/ssl_site.crt"
  fi

  a2enmod rewrite
  a2enmod headers
  a2enmod proxy proxy_html proxy_http xml2enc ssl http2
  service apache2 restart
fi

# Change user and group id for www-data
usermod -u $PUID www-data
groupmod -g $PGID www-data

# Added by Lanti
# UID=$(id -u www-data)
# chown -R $UID:$UID $APP_CODE_PATH_CONTAINER

# Added by Lanti
# go-replace \
#   -s "<DOCUMENT_ROOT>" -r "${WEB_DOCUMENT_ROOT}" \
#   -s "<ALIAS_DOMAIN>" -r "${WEB_ALIAS_DOMAIN}" \
#   -s "<SERVERNAME>" -r "${HOSTNAME}" \
#   --path=/etc/apache2/sites-available \
#   --path-pattern='*.conf' \
#   --ignore-empty \
#   --output=/etc/apache2/sites-available/$(date +%s).conf

# Start apache in foreground
/usr/sbin/apache2ctl -D FOREGROUND
