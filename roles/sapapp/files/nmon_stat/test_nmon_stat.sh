#!/bin/bash

#
# Restart NMON if nmon_stat.sh not running
#

sleep 30

LOG=/usr/sap/scripts/nmon_stat
cd $LOG
SS=$(expr 86400 - $(date +%H) \* 3600 - $(date +%M) \* 60 - $(date +%S))
COUNT=$(expr $SS / 180)

if [ $(ps -ef | egrep 'nmon.*-fTdVPMLA' | grep -v grep | wc -l | sed 's/ //g') -eq "0" ] ; then
        nmon -fTdVPMLA^ -s 180 -c $COUNT
fi

