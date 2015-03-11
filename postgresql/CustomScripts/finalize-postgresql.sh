#!/usr/bin/bash

logger "Configuring prerequisites"
bash ./configure-prerequisites.sh $1 $2 $3 $4 $5

logger "Configuring Pacemaker and corosync"
bash ./configure-pacemaker.sh $1 $2 $3 $4 $5
