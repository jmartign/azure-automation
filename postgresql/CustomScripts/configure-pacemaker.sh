#!/usr/bin/bash

logger "Setting up corosync"
echo "totem {
  version: 2
  crypto_cipher: none
  crypto_hash: none
  interface {
    ringnumber: 0
    bindnetaddr: $5
    mcastport: 5405
    ttl: 1
  }
  transport: udpu
}

logging {
  fileline: off
  to_logfile: yes
  to_syslog: yes
  logfile: /var/log/cluster/corosync.log
  debug: off
  timestamp: on
  logger_subsys {
    subsys: QUORUM
    debug: off
    }
  }

nodelist {
  node {
    ring0_addr: $3
    nodeid: 1
  }

  node {
    ring0_addr: $4
    nodeid: 2
  }
}

service {
   # Load the Pacemaker Cluster Resource Manager
   name: pacemaker
   ver: 0
}

quorum {
  provider: corosync_votequorum
}" > /etc/corosync/corosync.conf

service corosync start
chkconfig corosync on

logger "Setting up Pacemaker"
service pacemaker start
chkconfig pacemaker on

#logger "Setting PCS password for hacluster user"
#echo hacluster:p@ssw0rd.123 | chpasswd

if [ $(hostname) == $1 ]; then
logger "Configuring Pacemaker resources on Primary Node only"
logger "Disabling STONITH, setting resource stickiness and quorum policy to 'ignore' for a 2-node cluster"
pcs property set stonith-enabled=false
pcs property set default-resource-stickiness=100
pcs property set no-quorum-policy=ignore

logger "Adding DRBD resource on cluster"
pcs resource create drbd_postgres ocf:linbit:drbd drbd_resource=r0 op monitor interval=15s

logger "Configure the DRBD primary and secondary node"
pcs resource master ms_drbd_postgres drbd_postgres master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true

logger "Configure the DRBD mounting filesystem (and mountpoint)"
pcs resource create postgres_fs ocf:heartbeat:Filesystem params device="/dev/drbd0" directory="/var/lib/pgsql" fstype="ext4"

logger "Adding the postgresql resource on cluster"
pcs resource create postgresql ocf:heartbeat:pgsql op monitor timeout="30" interval="30"

logger "Grouping postgresql and DRBD mounted filesystem. The name of the group will be 'postgres'"
pcs resource group add postgres postgres_fs postgresql

logger "Fixing group postgres to run together with DRBD Primary node"
pcs constraint colocation add postgresql with Master ms_drbd_postgres INFINITY

logger "Configuring postgres to run after DRBD"
pcs constraint order promote ms_drbd_postgres then start postgresql

logger "Cleaning up"
pcs resource cleanup postgres_fs
pcs resource cleanup postgresql

logger "Starting resources"
pcs resource enable postgres_fs

#echo "To test, try the below commands while observing 'crm_mon'"
#echo "pcs cluster standby pgsql01"
#echo "pcs cluster unstandby pgsql01"
fi

#logger "Enabling cluster-components to start up at boot"
#chkconfig pcsd on
#service pcsd start

chkconfig corosync-notifyd on
service corosync-notifyd start
