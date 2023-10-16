#!/bin/sh

set -e

DIR=$( cd "$(dirname $0)" && pwd )
. $DIR/env_variables.sh

usage_fn() {
	cat <<- EOF
	####################################################
	Run Docker Compose project
	    Usage: $0 up|stop|down|prune|config|bootstrap|backup_all|restore_all
	####################################################
	EOF
}

up_fn() {
	echo "$0: Start Docker Compose project"
	docker compose \
		--env-file $LARADOCK_GIT/.env.example \
		--file $LARADOCK_GIT/docker-compose.yml \
		--file $ABS_PATH/docker-compose.override.yml \
		up --detach $SERVICES
}

stop_fn() {
	echo "$0: Stop services"
	docker compose \
		--env-file $LARADOCK_GIT/.env.example \
		--file $LARADOCK_GIT/docker-compose.yml \
		--file $ABS_PATH/docker-compose.override.yml \
		stop
}

down_fn() {
	echo "$0: Stop and remove containers, networks"
	docker compose \
		--env-file $LARADOCK_GIT/.env.example \
		-f $LARADOCK_GIT/docker-compose.yml \
		-f $ABS_PATH/docker-compose.override.yml \
		down
}

prune_fn() {
	echo "$0: Prune everything"
	echo "$0: Remove all containers"
		docker container stop $(docker container ls --all --quiet) 2>/dev/null || true
		docker container prune --force
	echo "$0: Remove all unused local volumes"
		docker volume prune --force
	echo "$0: Remove all unused networks"
		docker network prune --force
	echo "$0: Remove unused images"
		docker image prune --all --force
}

cleanup_fn() {
	echo "$0: Cleanup Docker leftovers"
	echo "$0: Remove all unused data"
		docker system prune --all --force
	echo "$0: Remove build cache"
		docker builder prune --all --force
}

config_fn() {
	echo "$0: Export Docker Compose configuration"
	docker compose \
		--env-file $LARADOCK_GIT/.env.example \
		--file $LARADOCK_GIT/docker-compose.yml \
		--file $ABS_PATH/docker-compose.override.yml \
		convert > $ABS_PATH/config.yml
	printenv > $ABS_PATH/config.ini
}

check_docker_fn() {
	if [ ! "$(docker ps -a | grep $ADM_DEFAULT_SERVER)" ]; then
		echo "ERROR: \"$ADM_DEFAULT_SERVER\" container does not exist..." >&2 # write error message to stderr
		exit 1
	fi
}

preinstall_fn() {
	echo "$0: Pull Laradock repository"

	rm -rf $LARADOCK_GIT
	mkdir -p $LARADOCK_GIT
	git clone https://github.com/laradock/laradock.git $LARADOCK_GIT
	# https://github.com/docker/compose/issues/9733
	touch $LARADOCK_GIT/.env
}

bootstrap_fn() {
	echo "$0: Bootstrap the environment"

	echo "$SITES" | tr ',' '\n' | while read site; do
		mkdir -p $APP_CODE_PATH_HOST/$site
		if [ -z "$(ls -A $APP_CODE_PATH_HOST/$site)" ]; then
			echo "\"$APP_CODE_PATH_HOST/$site\" directory is empty, downloading Wordpress!"
			curl -L https://wordpress.org/latest.tar.gz | tar -xzf - -C $APP_CODE_PATH_HOST/$site --strip-components=1
			# docker cp $DIR/createdb.sql $ADM_DEFAULT_SERVER:/usr/src
			# docker exec $ADM_DEFAULT_SERVER sh -c "mysql -uroot -p$MARIADB_ROOT_PASSWORD -e'CREATE DATABASE IF NOT EXISTS \`$site\` COLLATE '$COLLATION' ; GRANT ALL ON \`$site\`.* TO \"$MARIADB_USER\"@\"%\" ;' -v"
			docker exec $ADM_DEFAULT_SERVER sh -c "mariadb -uroot -p$MARIADB_ROOT_PASSWORD -e'CREATE DATABASE IF NOT EXISTS \`$site\` COLLATE '$COLLATION' ; GRANT ALL ON \`$site\`.* TO \"$MARIADB_USER\"@\"%\" ;' -v"
		fi
	done

	if [ -z "$(ls -A $APP_CODE_PATH_HOST/phpinfo.php)" ]; then
		echo "\"$APP_CODE_PATH_HOST/phpinfo.php\" file is not exists, creating one!"
		echo "<?php phpinfo(); ?>" > $APP_CODE_PATH_HOST/phpinfo.php
	fi
}

backup_all_fn() {
	echo "$0: Backup webserver files & databases"

	echo "$SITES" | tr ',' '\n' | while read site; do
		DATA=$BAK/$site/data
		SQL=$BAK/$site/sql

		rm -rf $BAK/$site
		mkdir -p $DATA $SQL
		(cd $ABS_PATH && rsync -avzP $APP_CODE_PATH_HOST/$site/ $DATA)
		# docker exec $ADM_DEFAULT_SERVER sh -c "mysqldump -u$MARIADB_USER -p$MARIADB_PASSWORD --single-transaction --quick --lock-tables=false $site" > $SQL/$site.sql
		docker exec $ADM_DEFAULT_SERVER sh -c "mariadb-dump -u$MARIADB_USER -p$MARIADB_PASSWORD --single-transaction --quick --lock-tables=false $site" > $SQL/$site.sql
		(cd $BAK/$site && tar -czf $BAK/backup_${site}_${TIMESTAMP}.tar.gz data sql)
		rm -rf $BAK/$site
	done
}

restore_all_fn() {
	echo "$0: Restore webserver files & databases"

	echo "$SITES" | tr ',' '\n' | while read site; do
		if [ -d "$APP_CODE_PATH_HOST/$site" ]; then
			echo "NOTICE: \"$APP_CODE_PATH_HOST/$site\" directory exist..." >&2 # write error message to stderr
			# exit 1
			echo "Replacing data files from archive..."
			rm -rf $APP_CODE_PATH_HOST/$site
		fi

		DATA=$BAK/$site/data
		SQL=$BAK/$site/sql
		ARCHIVE=$(find $BAK -type f -iname "backup_${site}_*.tar.gz" | sort -nr | head -1)
		echo "$0: Restoring $ARCHIVE"

		rm -rf $BAK/$site
		mkdir -p $BAK/$site $APP_CODE_PATH_HOST/$site
		tar -xf $ARCHIVE -C $BAK/$site
		# docker exec $ADM_DEFAULT_SERVER sh -c "mysql -uroot -p$MARIADB_ROOT_PASSWORD -e'DROP DATABASE IF EXISTS \`$site\` ; CREATE DATABASE \`$site\` COLLATE '$COLLATION' ; GRANT ALL ON \`$site\`.* TO \"$MARIADB_USER\"@\"%\" ;' -v"
		# docker exec -i $ADM_DEFAULT_SERVER sh -c "mysql -u$MARIADB_USER -p$MARIADB_PASSWORD -D$site" < $SQL/$site.sql
		# (cd $ABS_PATH && rsync -avzP $DATA/ $APP_CODE_PATH_HOST/$site)
		docker exec $ADM_DEFAULT_SERVER sh -c "mariadb -uroot -p$MARIADB_ROOT_PASSWORD -e'DROP DATABASE IF EXISTS \`$site\` ; CREATE DATABASE \`$site\` COLLATE '$COLLATION' ; GRANT ALL ON \`$site\`.* TO \"$MARIADB_USER\"@\"%\" ;' -v"
		docker exec -i $ADM_DEFAULT_SERVER sh -c "mariadb -u$MARIADB_USER -p$MARIADB_PASSWORD -D$site" < $SQL/$site.sql
		(cd $ABS_PATH && rsync -avzP $DATA/ $APP_CODE_PATH_HOST/$site)
		rm -rf $BAK/$site
	done
}

case "$1" in
	up)
		up_fn
		;;
	stop)
		stop_fn
		;;
	down)
		down_fn
		;;
	prune)
		down_fn
		prune_fn
		cleanup_fn
		;;
	config)
		config_fn
		;;
	preinstall)
		preinstall_fn
		;;
	bootstrap)
		check_docker_fn
		bootstrap_fn
		;;
	backup_all)
		check_docker_fn
		backup_all_fn
		;;
	restore_all)
		check_docker_fn
		restore_all_fn
		;;
	*)
		usage_fn
		echo "$0: unknown argument provided => $1\n"
		exit 1
		;;
esac
