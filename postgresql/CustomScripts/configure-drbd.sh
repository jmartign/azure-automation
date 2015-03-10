#!/usr/bin/bash

logger "Creating low-level RAID device"
mdadm --create --verbose /dev/md0 --level=stripe --raid-devices=2 /dev/sdc /dev/sdd
mdadm --detail --scan >> /etc/mdadm.conf

logger "Configuring DRBD"
echo "common {
    syncer { rate 100M; }
    protocol      C;
    }
    resource r0 {
    on $1 {
        device /dev/drbd0;
        disk /dev/md0;
        address $3:7789;
        meta-disk internal;
    }
    on $2 {
        device /dev/drbd0;
        disk /dev/md0;
        address $4:7789;
        meta-disk internal;
    }"  > /etc/drbd.d/r0.res

logger "Create device metadata"
drbdadm create-md r0

logger "Enabling resource"
drbdadm up r0

if [ $(hostname) == $1 ]; then
    logger "Setting $1 as DRBD Primary and starting the initial full synchronization"
    drbdadm primary --force r0
  else
    logger "Setting $2 as DRBD Secondary and waiting for sync"
    drbdadm secondary r0
fi

chkconfig drbd off # pacemaker will manage this
