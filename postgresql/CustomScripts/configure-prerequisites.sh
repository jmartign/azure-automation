#!/usr/bin/bash

logger "Opening required firewall ports"
chkconfig firewalld on
service firewalld start
firewall-cmd --zone=public --add-port=5432/tcp --permanent
firewall-cmd --zone=public --add-port=5405/tcp --permanent
firewall-cmd --zone=public --add-port=7789/tcp --permanent
firewall-cmd --reload

logger "Setting SELinux as Permissive"
sed -i.bak 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
setenforce 0

logger "Enabling EPEL (Extra Packages for Enterprise Linux) repository"
rpm -import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm

logger "Installing RAID and DRBD support"
yum install -y mdadm drbd84-utils kmod-drbd84
