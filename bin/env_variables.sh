#!/bin/sh

set -e

# These are only used in shell scripts, don't need to export
# DIR=$(realpath -s $PWD/$(dirname $0))
DIR=$( cd "$(dirname $0)" && pwd )

export ABS_PATH=$( cd "$DIR/.." && pwd )
export LARADOCK_ABS=$( cd "$DIR/.." && pwd )
LARADOCK_GIT=$LARADOCK_ABS/laradock
TMPFILE_ENV=$(mktemp)
LARADOCK=~/.laradock
BAK=$LARADOCK/backup
TIMESTAMP=$(date '+%s')_$(date '+%Y%m%d_%H%M%S')

set -a && . $ABS_PATH/.env && set +a

if [ "$WEBSERVER" = "nginx" ]; then
	echo "\"SERVICES\" environment variable set to nginx webserver!"
	# Default uid:gid for www-data in nginx-alpine: 82
	export PHP_FPM_PUID=82
	export PHP_FPM_PGID=82
fi
