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


logger "Setting up Pacemaker"
systemctl start pacemaker.service
systemctl enable pacemaker.service

systemctl start corosync.service
systemctl enable corosync.service

systemctl start corosync-notifyd.service
systemctl enable corosync-notifyd.service


if [ $(hostname) == $1 ]; then
logger "Configuring Pacemaker resources on Primary Node only"
logger "Disabling STONITH, setting resource stickiness and quorum policy to 'ignore' for a 2-node cluster"
pcs property set stonith-enabled=false
pcs property set default-resource-stickiness=100
pcs property set no-quorum-policy=ignore

logger "Adding DRBD resource on cluster"
pcs cluster cib drbd_cfg
pcs resource create drbd_postgres ocf:linbit:drbd drbd_resource=r0 op monitor interval=15s

logger "Configure the DRBD primary and secondary node"
pcs -f drbd_cfg resource master ms_drbd_postgres drbd_postgres master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true

logger "Configure the DRBD mounting filesystem (and mountpoint)"
pcs -f drbd_cfg resource create postgres_fs ocf:heartbeat:Filesystem params device="/dev/drbd0" directory="/var/lib/pgsql" fstype="ext4"

logger "Adding the postgresql resource on cluster"
pcs -f drbd_cfg resource create postgresql ocf:heartbeat:pgsql op monitor timeout="30" interval="30"

logger "Grouping postgresql and DRBD mounted filesystem. The name of the group will be 'postgres'"
pcs -f drbd_cfg resource group add postgres postgres_fs postgresql

logger "Fixing group postgres to run together with DRBD Primary node"
pcs -f drbd_cfg constraint colocation add postgresql with Master ms_drbd_postgres INFINITY

logger "Configuring postgres to run after DRBD"
pcs -f drbd_cfg constraint order promote ms_drbd_postgres then start postgresql

logger "Applying changes"
pcs cluster cib-push drbd_cfg

logger "Setting PCS password for hacluster user"
echo hacluster:p@ssw0rd.123 | chpasswd
pcs cluster auth -u hacluster -p p@ssw0rd.123
systemctl start pcsd.service
systemctl enable pcsd.service

logger "Cleaning up"
pcs resource cleanup postgres_fs
pcs resource cleanup ms_drbd_postgres
pcs resource cleanup postgresql

logger "Starting resources"
pcs resource enable postgres_fs
fi

logger "Setting up MOTD with relevant information"
echo "
= + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + =
| Welcome to the 2-node highly available PostgreSQL system on Azure.                  |
= + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + =
| Useful information about the cluster:                                               |
| - Node 1 ($1 - $3)                                                                  |
| - Node 2 ($2 - $4)                                                                  |
| - Load Balancer IP ($6). You would use this to connect to PostgreSQL.               |
= + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + =
| Useful commands:                                                                    |
| - Find information about the cluster: crm_mon -1 and pcs status                     |
| - Verify cluster setup: crm_verify -LV                                              |
| - Verify nodes on the clusteR: corosync-cmapctl  | grep members                     |
| - Connect to PostgreSQL: psql -h $6 -u posrgres                                     |
| - Test failover on $1 (run crm_mon to observe): pcs cluster standby $1              |
| - Revert failover on $1: pcs cluster unstandby $1                                   |
= + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + =
" > /etc/motd
