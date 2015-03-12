#!/usr/bin/bash

logger "Opening required firewall ports"
systemctl enable firewalld.service
systemctl start firewalld.service

firewall-cmd --zone=public --add-port=5432/tcp --permanent #pgsql
firewall-cmd --zone=public --permanent --add-service=high-availability #corosync,pcs
firewall-cmd --zone=public --add-port=7788/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7789/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7790/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7791/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7792/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7793/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7794/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7795/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7796/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7797/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7798/tcp --permanent #drbd
firewall-cmd --zone=public --add-port=7799/tcp --permanent #drbd
firewall-cmd --reload

systemctl disable firewalld.service
systemctl stop firewalld.service

logger "Setting SELinux as Permissive"
sed -i.bak 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
setenforce 0

logger "Enabling EPEL (Extra Packages for Enterprise Linux) repository"
rpm -import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm

logger "Installing mdadm, drbd, ntp, postgresql, corosync, pacemaker, pcs"
yum install -y mdadm drbd84-utils kmod-drbd84 ntp postgresql-server postgresql-contrib corosync pacemaker pcs

logger "Configuring NTP"
ntpdate pool.ntp.org

systemctl enable ntpd.service
systemctl start ntpd.service

logger "Creating low-level RAID device"
mdadm --create --verbose /dev/md0 --level=stripe --raid-devices=2 /dev/sdc /dev/sdd
mdadm --detail --scan >> /etc/mdadm.conf

logger "Creating DRBD cluster configuration"
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

# wait for /proc/drbd to have UpToDate/UpToDate
synced=$(grep -c UpToDate/UpToDate /proc/drbd)
until [ $synced -ge  1 ]; do
  progress=$(grep "sync'ed:" /proc/drbd)
  logger "DRBD still syncing $progress"
  echo "DRBD still syncing $progress"
  synced=$(grep -c UpToDate/UpToDate /proc/drbd)
  sleep 30s
done

if [ $(hostname) == $1 ]; then
  logger "Preparing Postgres partition on primary node $1"
  mkfs -t ext4 /dev/drbd0
  mount /dev/drbd0 /var/lib/pgsql
  chown postgres:postgres /var/lib/pgsql
  chmod 700 /var/lib/pgsql

  logger "Runing postgresql-setup initdb"
  postgresql-setup initdb

  logger "Enabling listen_addresses = '*'"
  sed -i.bak "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf
else
  logger "Clearing Postgres partition on secondary node $2"
  rm -Rf /var/lib/pgsql/*
fi

logger "Postgres should be working by now"
logger "Stopping Postgres, unmounting /dev/drbd0, setting it as secondary and stopping drbd"
systemctl stop postgresql.service
umount /dev/drbd0
drbdadm secondary r0
systemctl stop drbd.service

logger "Preventing postgresql and drbd from starting on boot as this will be controlled by pacemaker"
systemctl disable drbd.service
systemctl disable postgresql.service

# Node 1: Create test database using pgbench
#service postgresql start
#su -c 'createdb pgbench' - postgres
#su -c 'pgbench -i -s 10 pgbench' - postgres
#psql> \c pgbench
#psql> select count(*) from pgbench_accounts;

# Verify it is working on the other node
# Node 1: Stop postgresql and unmount
#service postgresql stop
#umount /dev/drbd0
#drbdadm secondary r0

# Node 2: Make drbd primary and mount filesystem then start postgresql
#drbdadm primary r0
#mount /dev/drbd0 /var/lib/pgsql/
#service postgresql start
# Validate data is there
#su postgres
#psql> \c pgbench
#psql> select count(*) from pgbench_accounts;
