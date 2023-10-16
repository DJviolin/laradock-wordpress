#!/bin/sh

set -e

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
# https://wiki.bash-hackers.org/howto/getopts_tutorial
# https://stackoverflow.com/questions/16483119/an-example-of-how-to-use-getopts-in-bash
# https://dustymabe.com/2013/05/17/easy-getopt-for-a-bash-script/
# https://www.computerhope.com/unix/bash/getopts.htm

# A POSIX variable
# Reset in case getopts has been used previously in the shell.
OPTIND=1

# Initialize our own variables
SITE=""
ARCHIVE=""

usage() {
	echo "Usage: $0 [ -s SITE NAME ] [ -L ARCHIVE ]" 1>&2
}
exit_abnormal() {
	usage
	exit 1
}

while getopts "h:s:l:" opt; do
	case "$opt" in
		h)
			usage
			exit 0;
			;;
		s)
			SITE=$OPTARG
			;;
		l)
			ARCHIVE=$OPTARG
			;;
	esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

echo "site=$SITE, archive=$ARCHIVE, Leftovers: $@"

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

if [ -d "$APP_CODE_PATH_HOST/$SITE" ]; then
	echo "NOTICE: \"$APP_CODE_PATH_HOST/$SITE\" directory exist..." >&2 # write error message to stderr
	# exit 1
	echo "Replacing data files from archive..."
	rm -rf $APP_CODE_PATH_HOST/$SITE
fi

DATA=$BAK/$SITE/data
SQL=$BAK/$SITE/sql

rm -rf $BAK/$SITE
mkdir -p $BAK/$SITE $APP_CODE_PATH_HOST/$SITE
tar -xf $ARCHIVE -C $BAK/$SITE
# docker exec $ADM_DEFAULT_SERVER sh -c "mysql -uroot -p$MARIADB_ROOT_PASSWORD -e'DROP DATABASE IF EXISTS \`$SITE\` ; CREATE DATABASE \`$SITE\` COLLATE '$COLLATION' ; GRANT ALL ON \`$SITE\`.* TO \"$MARIADB_USER\"@\"%\" ;' -v"
# docker exec -i $ADM_DEFAULT_SERVER sh -c "mysql -u$MARIADB_USER -p$MARIADB_PASSWORD -D$SITE" < $SQL/$SITE.sql
docker exec $ADM_DEFAULT_SERVER sh -c "mariadb -uroot -p$MARIADB_ROOT_PASSWORD -e'DROP DATABASE IF EXISTS \`$SITE\` ; CREATE DATABASE \`$SITE\` COLLATE '$COLLATION' ; GRANT ALL ON \`$SITE\`.* TO \"$MARIADB_USER\"@\"%\" ;' -v"
docker exec -i $ADM_DEFAULT_SERVER sh -c "mariadb -u$MARIADB_USER -p$MARIADB_PASSWORD -D$SITE" < $SQL/$SITE.sql
(cd $ABS_PATH && rsync -avzP $DATA/ $APP_CODE_PATH_HOST/$SITE)
rm -rf $BAK/$SITE
