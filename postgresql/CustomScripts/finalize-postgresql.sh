#!/usr/bin/bash

logger "Configuring prerequisites"
bash configure-prerequisites.sh

logger "Configuring RAID and DRBD. Wait for syncing to finish before proceeding."
bash configure-drbd.sh $1 $2 $3 $4 $5

# wait for /proc/drbd to have UpToDate/UpToDate
synced=$(grep -c UpToDate/UpToDate /proc/drbd)
until [ $synced -ge  1 ]; do
  logger "DRBD still syncing"
  synced=$(grep -c UpToDate/UpToDate /proc/drbd)
  sleep 15s
done

logger "DRBD syncing done"

logger "Configuring File System"
bash configure-filesystem.sh $1 $2 $3 $4 $5

logger "Configuring PostgreSQL"
bash configure-postgresql.sh $1 $2 $3 $4 $5

logger "Configuring Pacemaker and corosync"
#bash configure-pacemaker.sh $1 $2 $3 $4 $5
