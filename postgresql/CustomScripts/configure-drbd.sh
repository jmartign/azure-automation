#!/usr/bin/bash

logger "Creating RAID device"
mdadm --create --verbose /dev/md0 --level=stripe --raid-devices=2 /dev/sdc /dev/sdd
mdadm --detail --scan >> /etc/mdadm.conf

logger "Configuring DRBD"
echo "resource r0 {
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

logger "Initializing the DRBD resource"
drbdadm create-md r0
drbdadm up r0

service drbd start
chkconfig drbd off # pacemaker will manage this

if [ $(hostname) == $1 ]; then
    logger "Setting $1 as DRBD Primary and forcing sync"
    drbdadm primary --force r0
  else
    logger "Setting $2 as DRBD Secondary and waiting for sync"
    drbdadm secondary r0
fi
