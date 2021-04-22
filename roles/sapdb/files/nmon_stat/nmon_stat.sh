#!/bin/sh
#
# Collect NMON statistics (every 3 minutes)
#

LOG=/usr/sap/scripts/nmon_stat
cd $LOG
nmon -fTdVPMLA^ -s 180 -c 480
find $LOG/*.nmon -mtime +1 -exec /usr/bin/gzip {} \;
#find $LOG/*.gz -mtime +330 -exec rm -rf {} \;

