#!/usr/bin/bash

# we should now wait until watch cat /proc/drbd says UpToDate/UpToDate
logger "Creating data directory mount point for PostgreSQL"
mkdir -p -m 0700 /var/lib/pgsql
if [ $(hostname) == $1 ]; then
    logger "Creating ext4 filesystem @ /dev/drbd0 on $1 Primary node only"
    mkfs -t ext4 /dev/drbd0
    logger "Mounting /dev/drbd0 as /var/lib/pgsql/ on $1 Primary node only and setting permissions"
    mount -t ext4 /dev/drbd0 /var/lib/pgsql
    chmod 0700 /var/lib/pgsql
fi
