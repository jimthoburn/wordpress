#!/usr/bin/env bash

set -o errexit -o pipefail -o nounset

# Enter the major and minor version of your MySQL database.
# For example, 8.0
# You can find the version in the `Dockerfile` at the root of this project.
MYSQL_VERSION="8.0"

# https://dev.mysql.com/doc/mysql-installation-excerpt/8.0/en/linux-installation-yum-repo.html
#
# ${MYSQL_VERSION//./} removes dots from the version number.
# For example:
#
# 8.0 => 80
# mysql80-community
#
# 5.7 => 57
# mysql57-community
#
cat <<EOF > /etc/yum.repos.d/mysql-community.repo
[mysql${MYSQL_VERSION//./}-community]
name=MySQL $MYSQL_VERSION Community Server
baseurl=http://repo.mysql.com/yum/mysql-$MYSQL_VERSION-community/el/7/x86_64
enabled=1
gpgcheck=0
EOF

yum install mysql-community-server -y
