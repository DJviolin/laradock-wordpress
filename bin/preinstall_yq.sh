#!/bin/sh

# https://docs.docker.com/engine/install/ubuntu/
# https://docs.docker.com/engine/install/linux-postinstall/

set -e

apt update

# YAML dependencies
apt install -y jq
# "https://github.com/mikefarah/yq/releases/download/v4.27.2/yq_$(uname -s)_$(dpkg --print-architecture)"
wget "https://github.com/mikefarah/yq/releases/latest/download/yq_$(uname -s)_$(dpkg --print-architecture)" \
	--quiet \
	-O /usr/bin/yq \
	&& chmod +x /usr/bin/yq
