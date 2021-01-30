#!/bin/bash
# ----------------------------------------------------------------------------
#
# Script: Script to take Heap dump of AEM Java. No argument required
# Save dump file to Java tmp location.
# Script must run as root
# Author:       Denny Vettom
#
# Usage:
# ----------------------------------------------------------------------------
PATH=$PATH:/usr/bin:/usr/sbin:/usr/local/bin:/bin:/opt/csw/bin:/usr/ccs/bin
HOSTNAME=`hostname`
DATE=`date +%Y%m%d`
TIMESTAMP=`date +%H%M.%Y%m%d`
N_ARG=$#
SCR_HOME=`dirname $0`
SCR_NAME=`basename $0`
USER=crx



#Ensure script is run as root user
 CURRENT_USER_ID=`id | awk -F\( '{ print $2 }' | awk -F\) '{ print $1 }'`
 if [ $CURRENT_USER_ID != root ]
 then
    echo -e "  \e[1;32m INFO : Please execute command as Root \e[0m "
    exit
 fi 



# if [ ! -d /mnt/crx/publish ] || [ ! -d /mnt/crx/author ]
# then
#     echo -e " \e[0;41m Author/Publish directory not found, is this AMS AEM instance? \e[0m "
#     exit 
# fi

# Get Java tmp or set java tmp to store Heap file
if [ -f /etc/sysconfig/cq5 ]
then
     source /etc/sysconfig/cq5
else
    echo -e " \e[0;41m ERROR: /etc/sysconfig/cq5 not found, is this AMS AEM instance? \e[0m "
    exit
fi

#ensure single Java process run by CRX
PIDCOUNT=`pgrep -a -u crx  | grep -E 'cq-publish-4503.jar|cq-author-4502.jar' | grep -v grep | awk '{ print $1}' | wc -l`
if [ $PIDCOUNT -ne 1 ]
then
    echo -e " \e[0;41m ERROR: Java process not found or more than 1 Java process found \e[0m "
    pgrep -a -u crx  | grep -E 'cq-publish-4503.jar|cq-author-4502.jar'
    exit
else
   PID=`pgrep -a -u crx  | grep -E 'cq-publish-4503.jar|cq-author-4502.jar' | grep -v grep | awk '{ print $1}'`
fi


#Ready to take thread dump
echo -e "  \e[1;32m INFO : Taking Heap dump of PID=$PID "
    Dumpfile="$HOSTNAME-heapdump-`date  +%H%M.%Y%m%d`.hprof"
    sudo -u $USER /usr/java/latest/bin/jmap -dump:format=b,file=$JAVA_IO_TMP_DIR/$Dumpfile  $PID


echo -e "  \e[1;32m \n INFO : Dumpfile=$Dumpfile "

