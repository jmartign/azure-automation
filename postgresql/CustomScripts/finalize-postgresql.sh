#!/usr/bin/bash

logger "Configuring prerequisites"
bash ./configure-prerequisites.sh $1 $2 $3 $4 $5

logger "Configuring Pacemaker and corosync"
bash ./configure-pacemaker.sh $1 $2 $3 $4 $5

logger "Setting up MOTD with relevant information"
echo "
= + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +  =
| Welcome to the 2-node highly available PostgreSQL system on Azure.       |
= + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +  =
| Useful information about the cluster:                                    |
| - Node 1 ($1 - $3)                                                       |
| - Node 2 ($2 - $4)                                                       |
| - Load Balancer IP ($6). You would use this to connect to PostgreSQL.    |
= + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +  =
| Useful commands:                                                         |
| - Find information about the cluster: crm_mon -1 and pcs status          |
| - Verify cluster setup: crm_verify -LV                                   |
| - Connect to PostgreSQL: psql -h $6 -u posrgres                          |
| - Test failover on $1 (run crm_mon to observe): pcs cluster standby $1   |
| - Revert failover on $1: pcs cluster unstandby $1                        |
= + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +  =
" > /etc/motd
