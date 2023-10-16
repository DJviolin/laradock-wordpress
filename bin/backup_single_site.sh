#!/bin/sh

set -e

# A POSIX variable
# Reset in case getopts has been used previously in the shell.
OPTIND=1

# Initialize our own variables
SITE=""

usage() {
	echo "Usage: $0 [ -s SITE NAME ]" 1>&2
}
exit_abnormal() {
	usage
	exit 1
}

while getopts "h:s:" opt; do
	case "$opt" in
		h)
			usage
			exit 0;
			;;
		s)
			SITE=$OPTARG
			;;
	esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

echo "site=$SITE, Leftovers: $@"

################################################################################

DIR=$( cd "$(dirname $0)" && pwd )
. $DIR/env_variables.sh

check_docker_fn() {
	if [ ! "$(docker ps -a | grep $ADM_DEFAULT_SERVER)" ]; then
		echo "ERROR: \"$ADM_DEFAULT_SERVER\" container does not exist..." >&2 # write error message to stderr
		exit 1
	fi
}

check_docker_fn

DATA=$BAK/$SITE/data
SQL=$BAK/$SITE/sql

rm -rf $BAK/$SITE
mkdir -p $DATA $SQL
(cd $ABS_PATH && rsync -avzP $APP_CODE_PATH_HOST/$SITE/ $DATA)
# docker exec $ADM_DEFAULT_SERVER sh -c "mysqldump -u$MARIADB_USER -p$MARIADB_PASSWORD --single-transaction --quick --lock-tables=false $SITE" > $SQL/$SITE.sql
docker exec $ADM_DEFAULT_SERVER sh -c "mariadb-dump -u$MARIADB_USER -p$MARIADB_PASSWORD --single-transaction --quick --lock-tables=false $SITE" > $SQL/$SITE.sql
(cd $BAK/$SITE && tar -czf $BAK/backup_${SITE}_${TIMESTAMP}.tar.gz data sql)
rm -rf $BAK/$SITE
