#!/usr/bin/bash

logger "Installing corosync and pacemaker"
yum install -y corosync pacemaker pcs

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

quorum {
  provider: corosync_votequorum
}" > /etc/corosync/corosync.conf

service corosync start
chkconfig corosync on

echo "Setting up Pacemaker"
service pacemaker start
chkconfig pacemaker on

if [ $(hostname) == $1 ]; then
echo "Configuring Pacemaker resources on Primary Node only"
pcs cluster cib drbd_cfg

pcs -f drbd_cfg  property set stonith-enabled=false
pcs -f drbd_cfg  property set default-resource-stickiness=100
pcs -f drbd_cfg  property set no-quorum-policy=ignore
pcs -f drbd_cfg resource create drbd_pgsql ocf:linbit:drbd drbd_resource=r0 op monitor interval=29s role="Master" interval=31s role="Slave"
pcs -f drbd_cfg resource master drbd_pgsqlclone drbd_pgsql master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true
pcs -f drbd_cfg resource create fs_pgsql ocf:heartbeat:Filesystem params device="/dev/drbd/by-res/r0" directory="/var/lib/pgsql/data" fstype="ext4"
pcs -f drbd_cfg resource create pg systemd:postgresql op monitor interval="30" opstart interval="0" timeout="60" op stop interval="0" timeout="60"

echo "Gluing parts together"
pcs -f drbd_cfg resource group add postgresql fs_pgsql pg
pcs -f drbd_cfg  constraint colocation add postgresql with Master drbd_pgsqlclone INFINITY
pcs -f drbd_cfg  constraint order promote drbd_pgsqlclone then start postgresql

pcs cluster cib-push drbd_cfg
fi
