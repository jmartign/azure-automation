#!/usr/bin/bash

logger "Installing PostgreSQL on both nodes"
yum install -y postgresql*-server

logger "Setting ownership"
chown postgres:postgres /var/lib/pgsql

if [ $(hostname) == $1 ]; then
  logger "Initializing PostgreSQL on Primary node $1"
  postgresql-setup initdb
  logger "Enabling listening on all IPs"
  sed -i.bak "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf
fi

#logger "Unmount file system from Primary Node and revert it to be Secondary"
#if [ $(hostname) == $1 ]; then
#    umount /var/lib/pgsql
#    drbdadm secondary r0
#fi
