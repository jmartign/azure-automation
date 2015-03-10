#!/usr/bin/bash

logger "Installing PostgreSQL on both nodes"
yum install -y postgresql*-server

logger "Setting ownership"
chown postgres:postgres /var/lib/pgsql

if [ $(hostname) == $1 ]; then
logger "Initializing PostgreSQL on Primary node $1"
postgresql-setup initdb
fi

logger "Enabling listening on all IPs"
sed -i.bak "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

logger "Unmount file system from Primary Node and revert it to be Secondary"
if [ $(hostname) == $1 ]; then
    umount /var/lib/pgsql/data
    drbdadm secondary r0
fi

logger "Deleting any content data directory from Secondary Node as this will be synced via DRBD"
if [ $(hostname) == $2 ]; then
    rm -Rf /var/lib/pgsql/data/*
fi

logger "Disabling automatic startup of PostgreSQL as it will be controlled by Pacemaker"
chkconfig postgresql off
