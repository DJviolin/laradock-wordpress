#!/bin/sh

set -e

# We should only set this here in php-fpm, webservers are inheriting this
# Best practice is to match this with host user's uid:gid, which is 1000
UID=$(id -u www-data)
chown -R $UID:$UID $APP_CODE_PATH_CONTAINER

# Start in foreground
php-fpm
