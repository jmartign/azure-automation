#!/bin/bash

echo "Opening required firewall ports"
firewalld
firewall-cmd --zone=public --add-port=5432/tcp --permanent
firewall-cmd --zone=public --add-port=5405/tcp --permanent
firewall-cmd --zone=public --add-port=7789/tcp --permanent
firewall-cmd --reload

echo "Setting SELinux as Permissive"
sed -i.bak 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
setenforce 0

echo "Enabling EPEL (Extra Packages for Enterprise Linux) repository"
rpm -import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm

echo "Installing RAID and DRBD support"
yum install -y mdadm drbd84-utils kmod-drbd84

echo "Creating RAID device"
mdadm --create --verbose /dev/md0 --level=stripe --raid-devices=2 /dev/sdc /dev/sdd
mdadm --detail --scan >> /etc/mdadm.conf

echo "Configuring DRBD"
echo 'resource r0 {
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
    }'  > /etc/drbd.d/r0.res

echo "Initializing the DRBD resource"
drbdadm create-md r0
drbdadm up r0

echo "Creating data directory mount point for PostgreSQL"
mkdir -p -m 0700 /var/lib/pgsql/data
echo "Creating ext4 filesystem and on the DRBD resource on Primary Node only"
if [ $(hostname) == $1 ]; then
    drbdadm --force --overwrite-data-of-peer primary r0
    mkfs -t ext4 /dev/drbd0
    mount /dev/drbd0 /var/lib/pgsql/data
    chmod 0700 /var/lib/pgsql/data
fi
