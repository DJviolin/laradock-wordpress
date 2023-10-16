#!/bin/sh

set -e

# Change user and group id for www-data from 82 to 1000
# TODO: Alpine has addgroup & adduser commands
# usermod -u $PUID www-data
# groupmod -g $PGID www-data

# Default uid:gid for www-data in nginx-alpine: 82 
# UID=$(id -u www-data)
# chown -R $UID:$UID $APP_CODE_PATH_CONTAINER

/docker-entrypoint.d/20-envsubst-on-templates.sh

# Start in foreground
/opt/startup.sh
