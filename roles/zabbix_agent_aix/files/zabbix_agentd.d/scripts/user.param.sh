#!/bin/bash

VERSION='2020062900'

export PATH=$PATH:/usr/sbin:/usr/DynamicLinkManager/bin:/usr/es/sbin/cluster/utilities

version() {
        echo "$VERSION"
}

checkCmd() {
        which $1 > /dev/null 2>&1
        if [ $? -ne 0 ]; then
                echo "ZBX_NOTSUPPORTED"
                exit 99
        fi
}

zversion() {
        grep '^VERSION=' /opt/zabbix/zabbix-agent/configuration/user.param.sh | awk -F= '{print $2}' | sed "s/'//g"
}

zping() {
        echo "pong"
}

linux.update() {
        checkCmd rsync
        rsync rsync://${1}/agent/user.param.sh /etc/zabbix/zabbix_agentd.d/scripts/user.param.sh && chmod +x /etc/zabbix/zabbix_agentd.d/scripts/user.param.sh && echo "OK" || echo "ERROR"
}

aix.update() {
        checkCmd rsync
        rsync rsync://${1}/agent/user.param.sh /opt/freeware/etc/zabbix_agentd.conf.d/scripts/user.param.sh && chmod +x /opt/freeware/etc/zabbix_agentd.conf.d/scripts/user.param.sh && echo "OK" || echo "ERROR"
}

linux.hw.serial() {
        checkCmd dmidecode
        dmidecode -t 1 | grep 'Serial Number:' | awk -F\: '{print $2}' | sed 's/ //g'
}

linux.hw.product() {
        checkCmd dmidecode
        dmidecode -t 1 | grep 'Product Name:' | awk -F\: '{print $2}' | sed 's/.*-\[//;s/\]-.*//'
}

linux.hw.dmraid() {
        checkCmd dmraid
        if lspci | grep -q 'Intel Corporation C600/X79 series chipset SATA RAID'; then
                dmraid -s 2>/dev/null | grep status | awk -F\: '{print $2}' | sed 's/ //g'
        else
                echo "ZBX_NOTSUPPORTED"
        fi
}

linux.cksum() {
        checkCmd cksum
        cksum $1 | awk '{print $1}'
}

linux.vfs.fs.ro() {
        local filesystem=$1
        local status=0
        for i in $(cat /proc/mounts | awk -v filesystem="$filesystem" '{ if ($2==filesystem) print $4}' | sed 's/,/ /g'); do
                if [ "$i" == "ro" ]; then
                        status=1;
                fi;
        done
        echo $status
}

linux.vfs.read.io() {
        cat /proc/diskstats | awk '$3 ~ /^sd[a-z]*$/ {sum += $4} END {printf ("%0.0f\n", sum)}'
}

linux.vfs.write.io() {
        cat /proc/diskstats | awk '$3 ~ /^sd[a-z]*$/ {sum += $8} END {printf ("%0.0f\n", sum)}'
}

linux.vfs.read.dst() {
        cat /proc/diskstats | awk '$3 ~ /^sd[a-z]*$/ {sum += $7} END {printf ("%0.0f\n", sum)}'
}

linux.vfs.write.dst() {
        cat /proc/diskstats | awk '$3 ~ /^sd[a-z]*$/ {sum += $11} END {printf ("%0.0f\n", sum)}'
}

aix.vfs.read.io(){
        checkCmd iostat
        count=$(iostat -Dl | egrep '^hdisk' | wc -l | sed 's/ //g')
        iostat -Dl 1 2 | egrep '^hdisk' | tail -${count} | awk '{sum += $7} END {printf ("%0.0f\n", sum)}'
}

aix.vfs.write.io(){
        checkCmd iostat
        count=$(iostat -Dl | egrep '^hdisk' | wc -l | sed 's/ //g')
        iostat -Dl 1 2 | egrep '^hdisk' | tail -${count} | awk '{sum += $13} END {printf ("%0.0f\n", sum)}'
}

aix.vfs.read.dst(){
        checkCmd iostat
        count=$(iostat -Dl | egrep '^hdisk' | wc -l | sed 's/ //g')
        iostat -Dl 1 2 | egrep '^hdisk' | tail -${count} | awk '{sum += $8; n++ } END {if (n > 0) printf ("%f\n", sum/n);}'
}

aix.vfs.write.dst(){
        checkCmd iostat
        count=$(iostat -Dl | egrep '^hdisk' | wc -l | sed 's/ //g')
        iostat -Dl 1 2 | egrep '^hdisk' | tail -${count} | awk '{sum += $14; n++ } END {if (n > 0) printf ("%f\n", sum/n);}'
}

linux.mem.pswpin() {
        cat /proc/vmstat | grep pswpin | awk '{print $2}'
}

linux.mem.pswpout() {
        cat /proc/vmstat | grep pswpout | awk '{print $2}'
}

aix.mem.pi() {
        vmstat | tail -1 | awk '{print $6}'
}

aix.mem.po() {
        vmstat | tail -1 | awk '{print $7}'
}

linux.time.offset() {
        checkCmd ntpq
        ntpq -np | grep -E '^\*' | awk '{print $9}'
}

linux.time.ntpconf() {
        checkCmd ntpq
        ntpq -np | grep -E '^\*' | wc -l
}

linux.net.bond.check.slave() {
        local string=$(echo "$3" | sed 's/_/ /g')
        grep "$2" /proc/net/bonding/$1 -A6 | grep "$string" -m 1 | sed -n -e 's/^.*: //p'
}

linux.net.bond.check.bond() {
        local string=$(echo "$2" | sed 's/_/ /g')
        cat /proc/net/bonding/$1 | grep "$string" -m 1 | sed -n -e 's/^.*: //p'
}

linux.net.bond.discovery() {
        local bond_list=$(ls /proc/net/bonding/);
        echo -n '{"data":[';
        for b in ${bond_list}; do
                echo -n "{\"{#BOND_IF}\": \"$b\"},";
        done | sed -e 's:\},$:\}:';
        echo -n ']}';
}

linux.net.bond.slave.discovery() {
        local bond_list=$(ls /proc/net/bonding/);
        echo -n '{"data":[';
        for b in $bond_list; do
                if_list=$(grep 'Slave Interface' /proc/net/bonding/${b} | sed -n -e 's/^.*: //p');
                for i in $if_list; do
                        echo -n "{\"{#BOND_IF}\": \"$b\", ";
                        echo -n "\"{#SLAVE_IF}\": \"$i\"},";
                done;
        done | sed -e 's:\},$:\}:';
        echo -n ']}';
}

aix.dumpcheck() {
        STRING=$(/usr/lib/ras/dumpcheck -p)
        COUNT=$(echo "$STRING" | wc -l | sed 's/ //g')

        if [ "$COUNT" -gt "1" ]; then
                echo "$STRING"
        else
                echo "OK"
        fi
}

aix.hdlm() {
        checkCmd lsdev
        checkCmd lssrc
        checkCmd dlnkmgr
        hitachi=$(lsdev | grep 'Hitachi Disk Array' | wc -l | sed 's/ //g')
        if [ "$hitachi" -eq "0" ]; then
                echo "OK"
                exit 0
        fi

        DLMManager=$(lssrc -s DLMManager | grep -v '^Subsystem' | awk '{if ($3=="active") print "1"; else print "0"}')
        String=$(dlnkmgr view -sys | grep 'Load Balance' | grep 'on' | wc -l)

        if [ "$DLMManager" -eq "0" ]; then
                echo "DLMManager not running"
        elif [ "$String" -ne "1" ]; then
                echo "DLMManager Error"
        else
                echo "OK"
        fi
}

aix.sissas() {
        checkCmd lsdev
        checkCmd lsvg
        checkCmd sissasraidmgr
        sissas=$(lsdev | grep '^sissas' | wc -l | sed 's/ //g')
        if [ "$sissas" -eq "0" ]; then
                echo "OK"
                exit 0
        fi

        disk=$(lsvg -p rootvg | grep hdisk| awk '{ print $1}')
	String=$(sissasraidmgr -L -j1 -l sissas0 | egrep "$disk" | awk '{if ( $3!="Optimal" && $3!="Active" && $3!="Available" ) print $1" is "$3}')
	Count=$(echo "$String" | sed '/^$/d' | wc -l | sed 's/ //g')

        if [ "$Count" -ne "0" ]; then
                echo "$String"
        else
                echo "OK"
        fi
}

aix.ha.clrginfo() {
        checkCmd clRGinfo
        clRGinfo | awk '/ONLINE/ {print $NF}'
}

aix.fc.diskpath() {
        checkCmd lspath
        #Count=$(lspath | egrep -v 'Enabled|Available' | wc -l | sed 's/ //g')
	Count=$(lsdev -c disk | awk '!/DataDomain/ { system( "lspath  -l "$1) }' | egrep -c -v "Enabled|Available")
        if [ "$Count" -eq "0" ]; then
                echo "OK"
        else
                echo "$Count path not enabled"
        fi
}

aix.lparstatghz() {
	lparstat -E 1 1 | tail -1 | awk '{print $5}' | sed 's/[A-z].*//'
}

aix.ha.cldump() {
        checkCmd cldump
        String=$(cldump 2>/dev/null | egrep  'State:|Substate:' | sed 's/^.*Label: //g;s/^.*Name: //g;s/State: //g;s/Cluster Substate:/Substate/g' | egrep -v ' UP$| STABLE$' | awk '{print $1": "$2}')

        if [ -n "$String" ]; then
                echo "$String"
        else
                echo "OK"
        fi
}

aix.ha.clshowsrv() {
        checkCmd clshowsrv
        checkCmd halevel
        haversion=$(halevel -s | awk '{print $1}' | awk -F. '{print $1 $2}')
        if [ "$haversion" -ge "71" ]; then
                clcomd=$(clshowsrv clcomd | grep -v '^Subsystem' | awk '{if ($4=="active") print "1"; else print "0"}')
        else
                clcomd=$(clshowsrv clcomdES | grep -v '^Subsystem' | awk '{if ($4=="active") print "1"; else print "0"}')
        fi
        clstrmgrES=$(clshowsrv clstrmgrES | grep -v '^Subsystem' | awk '{if ($4=="active") print "1"; else print "0"}')

        if [ "$clcomd" -eq "0" ]; then
                echo "clcomd (clcomdES) not running"
        elif [ "$clstrmgrES" -eq "0" ]; then
                echo "clstrmgrES not running"
        else
                echo "OK"
        fi
}

aix.hw.product() {
        lsattr -El sys0 | grep modelname | awk '{print $2}' | awk -F, '{print $2}'
}

aix.hw.serial() {
        lsattr -El sys0 | grep systemid | awk '{print $2}' | awk -F, '{print $2}' | cut -c 3-9
}

aix.net.if.linkcount() {
    Count=$(entstat -d $1 2>/dev/null |  egrep "Number of adapters:" | awk -F\: '{sum += $2} END {print sum}' | sed 's/ //g')
        if [[ $Count =~ ^[0-9]+$ ]]; then
                echo $Count
        else
                echo 0
        fi
}

aix.net.if.linkstatus() {
        String=$(entstat -d $1 2>/dev/null | egrep 'Link Status:|Physical Port Link State:')
        Count=$(echo "$String" | wc -l)
        UpCount=$(echo "$String" | egrep ' Up' | wc -l)

        if [ "$UpCount" -eq "0" ]; then
                echo 2
                exit 0
        fi

        if [ "$Count" -gt "$UpCount" ]; then
                echo 1
                exit 0
        fi

        if [ "$Count" -eq "$UpCount" ]; then
                echo 0
                exit 0
        fi
}

tsm.dsmsta() {
       checkCmd dsmadmc
       if [ -f /opt/tivoli/tsm/StorageAgent/bin/dsmsta.opt ] ; then
               export DSM_LOG=/opt/tivoli/tsm/StorageAgent/bin/
               if [ $(ps -ef |grep dsmsta|egrep -v 'grep|tsm.dsmsta' |wc -l|awk '{print $1}') -eq 0 ] ; then
                       echo "NOT RUNNING"
               else
                       if [ -f /opt/tivoli/tsm/client/ba/bin/dsm.opt.localhost ] ; then
                               export DSM_CONFIG=/opt/tivoli/tsm/client/ba/bin/dsm.opt.localhost
                       fi
                       dsmadmc -id=admin -pa=admin -dataonly=yes -comma q sess > /tmp/.__dsmsta.q.sess.out__
                       if [ $? -gt 0 ] ; then
                               echo "ERROR"
                       else
                               echo "RUNNING"
                       fi
               fi
       else
               echo "NOT INSTALLED"
       fi
}

aix.errpt(){
    DATEFILE=/tmp/__last_errpt_date
    ERRPT_FILE=/tmp/__last_errpt_out
    if [ ! -f $DATEFILE ]
    then
        date +%m%d%H%M%y> $DATEFILE
    fi
    errpt -s `cat $DATEFILE` |egrep -v 'IDENTIFIER|078BA0EB|EAA3D429' > $ERRPT_FILE
    COUNT_LAST=`cat $ERRPT_FILE|wc -l`
    if [ $COUNT_LAST -gt 0 ] ; then
        exec 0<$ERRPT_FILE
        while read line
        do
            logger -p daemon.err -t errpt $line
        done
    fi
    date +%m%d%H%M%y> $DATEFILE
    if [ $COUNT_LAST = 0 ] ; then
        echo  "OK"
    else
        cat $ERRPT_FILE
    fi
}

aix.errpt-v(){
    DATEFILE=/tmp/__last_errpt_date
    if [ ! -f $DATEFILE ]
    then
        date +%m%d%H%M%y> $DATEFILE
    fi
    errpt -D -A -s `cat $DATEFILE` |egrep -v '^[0-F ]+$' || echo "OK"
}

aix.time.offset() {
        checkCmd ntpq
        ntpq -np | grep '^\*' | awk '{print $9}'
}

aix.time.ntpconf() {
        checkCmd ntpq
        ntpq -np | grep '^\*' | wc -l
}

aix.vg.discovery() {
        checkCmd lsvg
        String=$(lsvg -o)
        JSON='{"data":['

        for i in $String
        do
                JSON=${JSON}"{\"{#VGNAME}\":\"$i\"},"
        done
        JSON=$(echo $JSON | sed 's/,$//')
        JSON=${JSON}']}'

        echo $JSON
}

aix.vg.stale() {
        checkCmd lsvg
        String=$(lsvg $1 | egrep 'STALE PVs:' | awk '{print $3}')
        echo $String
}

aix.lsmcode.permanent() {
        checkCmd lsmcode
        String=$(lsmcode | grep 'permanent system firmware' | sed 's/.*image is //')
        echo $String
}

aix.lsmcode.temporary() {
        checkCmd lsmcode
        String=$(lsmcode | grep 'temporary system firmware' | sed 's/.*image is //')
        echo $String
}

aix.lsmcode.booted() {
        checkCmd lsmcode
        String=$(lsmcode | grep 'currently booted from' | sed 's/.*from the //' | sed 's/ firmware image.*//')
        echo $String
}

aix.dpddisk.stale() {
        checkCmd dpcli
        String=$(dpcli status|grep dpd|grep -v "(started/open)")
        Count=$(echo ${#String})
        if [ "$Count" -ne "0" ]; then
                echo "$String"
        else
                echo "OK"
        fi
}

aix.dpddisk.path() {
        checkCmd dpcli
        String=$(dpcli status|grep hdisk|grep -v dpd|grep -v available)
        Count=$(echo ${#String} )
        if [ "$Count" -ne "0" ]; then
                echo "$String"
        else
                echo "OK"
        fi
}

linux.multipath.discovery() {

        checkCmd multipath

        if [ ! -f /etc/multipath.conf ]; then
                echo "ZBX_NOTSUPPORTED"
                exit 0
        fi

        String=$(multipath -l -v1)
        JSON='{"data":['

        for i in $String
        do
                JSON=${JSON}"{\"{#PNAME}\":\"$i\"},"
        done
        JSON=$(echo $JSON | sed 's/,$//')
        JSON=${JSON}']}'

        echo $JSON
}

linux.multipath.status() {
        checkCmd multipath
        multipath -ll $1 | grep failed | wc -l
}

linux.ftp.anonymous() {
        grep '^anonymous_enable=' /etc/vsftpd/vsftpd.conf
}

getnmon() {
        checkCmd rsync
        RSYNC_PASSWORD=${3} rsync ${4}/*_${5}_*.nmo* rsync://nmon@${1}/nmon/${2}/queue/ > /dev/null 2>&1
        echo $?
}

aix.net.if.discovery() {
        String=$(ifconfig -a | grep -E '^en[0-9]{1,}|lo[0-9]{1,}: '| awk -F\: '{print $1}')
        JSON='{"data":['

        for i in $String
        do
                JSON=${JSON}"{\"{#IFNAME}\":\"$i\"},"
        done
        JSON=$(echo $JSON | sed 's/,$//')
        JSON=${JSON}']}'

        echo $JSON
}

aix.net.sif.discovery() {
        String=$(lsdev | grep 'Shared Ethernet Adapter' | awk '{print $1}')
        JSON='{"data":['

        for i in $String
        do
                JSON=${JSON}"{\"{#IFNAME}\":\"$i\"},"
        done
        JSON=$(echo $JSON | sed 's/,$//')
        JSON=${JSON}']}'

        echo $JSON
}

aix.net.sif.sync() {
	entstat -d ${1} 2>/dev/null | grep 'Synchronization:' | grep -v 'IN_SYNC' | wc -l | awk '{print $1}'
}

aix.net.sif.state() {
	entstat -d ${1} 2>/dev/null | grep -E 'State: (PRIMARY|BACKUP)' | awk -F\: '{print $2}' | sed 's/ //g'
}

aix.net.sif.ppls() {
	entstat -d ${1} 2>/dev/null | grep 'Physical Port Link Status' | grep -v 'Up' | wc -l | awk '{print $1}'
}

aix.net.sif.lpls() {
	entstat -d ${1} 2>/dev/null | grep 'Logical Port Link Status' | grep -v 'Up' | wc -l | awk '{print $1}'
}

aix.net.sif.pps() {
	entstat -d ${1} 2>/dev/null | grep 'Physical Port Speed' | awk -F\: '{print $2}' | sed 's/^ //g'
}

aix.net.if.in() {
        entstat -d ${1} 2>/dev/null | grep -E '^Bytes: ' | head -1 | awk '{print $4}'
}

aix.net.if.out() {
        entstat -d ${1} 2>/dev/null | grep -E '^Bytes: ' | head -1 | awk '{print $2}'
}

vios.vfcmap() {
        if [ -x /opt/freeware/etc/zabbix_agentd.conf.d/scripts/checkvmap.pl ]
        then /opt/freeware/etc/zabbix_agentd.conf.d/scripts/checkvmap.pl
        else echo FILE_NOT_FOUND
        fi
}

aix.ddpath() {
        if [ -x /opt/nsr/distr/ddpconnchk_aix_64 ]
	then /opt/nsr/distr/ddpconnchk_aix_64 -D scan_all 2>/dev/null |grep "DFC LUN devices" |awk '{print $1}'
        else echo FILE_NOT_FOUND
        fi
}

aix.lsattrhostname() {
        lsattr -El inet0 -a hostname -F value        
}

user_param() {
        local key="$1"
        shift 2>/dev/null
        case "$key" in
                version)                        version                                         ;;
                zversion)                       zversion                                        ;;
                zping)                          zping                                           ;;
                linux.update)                   linux.update "$1"                               ;;
                aix.update)                     aix.update "$1"                                 ;;
                echo)                           echo "$1" | sed 's/_/ /'                        ;;
                linux.hw.serial)                linux.hw.serial                                 ;;
                linux.hw.product)               linux.hw.product                                ;;
                linux.hw.dmraid)                linux.hw.dmraid                                 ;;
                linux.vfs.fs.ro)                linux.vfs.fs.ro "$1"                            ;;
                linux.vfs.read.io)              linux.vfs.read.io                               ;;
                linux.vfs.write.io)             linux.vfs.write.io                              ;;
                linux.vfs.read.dst)             linux.vfs.read.dst                              ;;
                linux.vfs.write.dst)            linux.vfs.write.dst                             ;;
                linux.cksum)                    linux.cksum "$1"                                ;;
                aix.vfs.read.io)                aix.vfs.read.io                                 ;;
                aix.vfs.write.io)               aix.vfs.write.io                                ;;
                aix.vfs.read.dst)               aix.vfs.read.dst                                ;;
                aix.vfs.write.dst)              aix.vfs.write.dst                               ;;
                linux.mem.pswpin)               linux.mem.pswpin                                ;;
                linux.mem.pswpout)              linux.mem.pswpout                               ;;
                aix.mem.pi)                     aix.mem.pi                                      ;;
                aix.mem.po)                     aix.mem.po                                      ;;
                linux.time.offset)              linux.time.offset                               ;;
                linux.time.ntpconf)             linux.time.ntpconf                              ;;
                linux.net.bond.check.slave)     linux.net.bond.check.slave "$1" "$2" "$3"       ;;
                linux.net.bond.check.bond)      linux.net.bond.check.bond "$1" "$2"             ;;
                linux.net.bond.discovery)       linux.net.bond.discovery                        ;;
                linux.net.bond.slave.discovery) linux.net.bond.slave.discovery                  ;;
                aix.dumpcheck)                  aix.dumpcheck                                   ;;
                aix.hdlm)                       aix.hdlm                                        ;;
                aix.sissas)                     aix.sissas                                      ;;
                aix.fc.diskpath)                aix.fc.diskpath                                 ;;
	        aix.ha.clrginfo)                aix.ha.clrginfo                                 ;;
                aix.ha.cldump)                  aix.ha.cldump                                   ;;
                aix.ha.clshowsrv)               aix.ha.clshowsrv                                ;;
                aix.hw.product)                 aix.hw.product                                  ;;
                aix.hw.serial)                  aix.hw.serial                                   ;;
                aix.net.if.linkcount)           aix.net.if.linkcount "$1"                       ;;
                aix.net.if.d_linkcount)         aix.net.if.linkcount "$1"                       ;;
                aix.net.if.linkstatus)          aix.net.if.linkstatus "$1"                      ;;
                aix.net.if.d_linkstatus)        aix.net.if.linkstatus "$1"                      ;;
                aix.time.offset)                aix.time.offset                                 ;;
                aix.time.ntpconf)               aix.time.ntpconf                                ;;
                aix.vg.discovery)               aix.vg.discovery                                ;;
                aix.vg.stale)                   aix.vg.stale "$1"                               ;;
                aix.lsmcode.permanent)          aix.lsmcode.permanent                           ;;
                aix.lsmcode.temporary)          aix.lsmcode.temporary                           ;;
                aix.lsmcode.booted)             aix.lsmcode.booted                              ;;
                aix.dpddisk.stale)              aix.dpddisk.stale                               ;;
                aix.dpddisk.path)               aix.dpddisk.path                                ;;
                linux.multipath.discovery)      linux.multipath.discovery                       ;;
                linux.multipath.status)         linux.multipath.status  "$1"                    ;;
                linux.ftp.anonymous)            linux.ftp.anonymous                             ;;
                getnmon)                        getnmon "$1" "$2" "$3" "$4" "$5"                ;;
                aix.net.if.discovery)           aix.net.if.discovery                            ;;
                aix.net.sif.discovery)          aix.net.sif.discovery                           ;;
                aix.net.sif.sync)               aix.net.sif.sync "$1"                           ;;
                aix.net.sif.state)              aix.net.sif.state "$1"                          ;;
                aix.net.sif.ppls)               aix.net.sif.ppls "$1"                           ;;
                aix.net.sif.lpls)               aix.net.sif.lpls "$1"                           ;;
                aix.net.sif.pps)                aix.net.sif.pps "$1"                            ;;
                aix.net.if.in)                  aix.net.if.in "$1"                              ;;
                aix.net.if.out)                 aix.net.if.out "$1"                             ;;
	        tsm.dsmsta)                     tsm.dsmsta                                      ;;
        	aix.errpt)                      aix.errpt      				        ;;
		aix.errpt-v)			aix.errpt-v					;;
		vios.vfcmap)                    vios.vfcmap                                     ;;
		aix.ddpath)                     aix.ddpath                                      ;;
		aix.lparstatghz)                aix.lparstatghz                                 ;;
                aix.lsattrhostname)             aix.lsattrhostname                              ;;
                *)                              false                                           ;;
        esac
}

LC_ALL="C" user_param "$@" || echo "ZBX_NOTSUPPORTED"

